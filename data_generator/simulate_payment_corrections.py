# simulate_payment_corrections.py
# Simulates payments that are CORRECTED after they were first posted.
# A correction is a new row with the same collection_id, sent later in a new file:
#   data/raw/collections/date=<arrival date>/collections_corrections.csv
#
# Run from the project root:
#   python data_generator/simulate_payment_corrections.py                 attribute fixes only
#   python data_generator/simulate_payment_corrections.py --with-amounts  also correct some amounts
#   python data_generator/simulate_payment_corrections.py --revert        delete the correction files
#
# Safe by design:
# - It never touches main.py or the original collection files, and it uses its
#   own random generator, so the seed-42 data stays identical.
# - Default mode only fixes payment_mode and field_officer_id. No money changes,
#   so DPD, GNPA and every metric stay the same.
# - --with-amounts adds a small upward amount change to about a third of the
#   corrections. This moves DPD slightly and shows up in the restatement report.
# - The correction keeps the ORIGINAL posted_date. The arrival date of the new
#   version is the folder date, and staging uses it to pick the latest version.
# - Running the script twice gives the same files.
# - Files already uploaded to S3 and loaded into Snowflake are not removed by
#   --revert. To undo a load, use snowflake/07_full_reload.sql after reverting.

import argparse
import random
from datetime import timedelta
from pathlib import Path

import pandas as pd

import config


SEED = 2027
CORRECTION_SHARE = 0.003          # about 0.3% of payments are corrected
AMOUNT_CHANGE_SHARE = 1 / 3       # only used with --with-amounts
AMOUNT_ADJUSTMENTS = [50, 100, 150]
MIN_DELAY_DAYS = 3                # correction arrives 3 to 30 days after posting
MAX_DELAY_DAYS = 30

ORIGINAL_FILE = "collections.csv"
CORRECTION_FILE = "collections_corrections.csv"
COLLECTIONS_DIR = Path(config.OUTPUT_FOLDER) / "collections"

COLUMNS = [
    "collection_id", "loan_id", "payment_date", "posted_date",
    "amount", "payment_mode", "field_officer_id",
]


def remove_old_corrections():
    removed = 0
    for path in COLLECTIONS_DIR.glob(f"date=*/{CORRECTION_FILE}"):
        path.unlink()
        removed += 1
        try:
            path.parent.rmdir()   # only works when the folder is now empty
        except OSError:
            pass
    return removed


def read_original_payments():
    files = sorted(COLLECTIONS_DIR.glob(f"date=*/{ORIGINAL_FILE}"))

    if not files:
        raise SystemExit(f"No collection files in {COLLECTIONS_DIR}. Run data_generator/main.py first.")

    frames = [pd.read_csv(f, dtype=str, keep_default_na=False) for f in files]
    payments = pd.concat(frames, ignore_index=True)

    # Exact duplicate rows exist on purpose. One row per payment is enough here.
    payments = payments.drop_duplicates("collection_id")
    return payments.sort_values("collection_id").reset_index(drop=True)


def other_officer(officer_id, rng):
    prefix, number = officer_id.rsplit("_", 1)
    choices = [n for n in range(1, config.OFFICERS_PER_BRANCH + 1) if str(n) != number]
    return f"{prefix}_{rng.choice(choices)}"


def build_corrections(with_amounts):
    rng = random.Random(SEED)   # own generator, no effect on the main data
    payments = read_original_payments()

    posted = pd.to_datetime(payments["posted_date"]).dt.date
    latest_allowed = config.END_DATE - timedelta(days=MIN_DELAY_DAYS)
    eligible = [i for i in payments.index if posted[i] <= latest_allowed]

    how_many = round(len(payments) * CORRECTION_SHARE)
    picked = sorted(rng.sample(eligible, how_many))

    rows = []
    amount_changes = 0

    for i in picked:
        row = payments.loc[i].copy()
        posted_date = posted[i]

        max_delay = min(MAX_DELAY_DAYS, (config.END_DATE - posted_date).days)
        arrival = posted_date + timedelta(days=rng.randint(MIN_DELAY_DAYS, max_delay))

        # The same random draws are made in both modes,
        # so the attribute fixes are identical with or without --with-amounts.
        row["field_officer_id"] = other_officer(row["field_officer_id"], rng)

        if rng.random() < 0.5:
            row["payment_mode"] = "UPI" if row["payment_mode"] == "CASH" else "CASH"

        wants_amount_change = rng.random() < AMOUNT_CHANGE_SHARE
        adjustment = rng.choice(AMOUNT_ADJUSTMENTS)

        if with_amounts and wants_amount_change:
            row["amount"] = f"{float(row['amount']) + adjustment:.2f}"
            amount_changes += 1

        row["arrival_date"] = arrival
        rows.append(row)

    return pd.DataFrame(rows), amount_changes


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--with-amounts", action="store_true",
                        help="also correct some amounts (changes DPD slightly)")
    parser.add_argument("--revert", action="store_true",
                        help="delete the correction files")
    args = parser.parse_args()

    removed = remove_old_corrections()

    if args.revert:
        print(f"Removed {removed} correction file(s).")
        return

    corrections, amount_changes = build_corrections(args.with_amounts)

    for arrival, group in corrections.groupby("arrival_date"):
        folder = COLLECTIONS_DIR / f"date={arrival}"
        folder.mkdir(parents=True, exist_ok=True)
        group[COLUMNS].to_csv(folder / CORRECTION_FILE, index=False)

    print(f"Corrected payments: {len(corrections)}")
    print(f"  with a changed amount: {amount_changes}")
    print(f"  arriving between {corrections['arrival_date'].min()} "
          f"and {corrections['arrival_date'].max()}")
    print("Now run the pipeline so the correction files are uploaded and loaded.")


if __name__ == "__main__":
    main()
