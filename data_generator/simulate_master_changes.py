# simulate_master_changes.py
# Simulates a LATER version of the master files (branches, customers),
# so the SCD Type 2 snapshots have real history to show.
#
# Run from the project root:
#   python data_generator/simulate_master_changes.py            apply changes
#   python data_generator/simulate_master_changes.py --revert   back to version 1
#
# Safe by design:
# - It never touches main.py, loans, schedules or collections,
#   so every portfolio number stays the same.
# - Only changes that cannot affect risk metrics are made:
#   branch renames and customer occupation changes.
# - Version 1 is saved once in data/master_baseline. Every run starts from
#   that copy, so running the script twice gives the same result.
# - If you regenerate the data with main.py, delete data/master_baseline first.

import argparse
import random
import shutil
from pathlib import Path

import pandas as pd

import config


SEED = 2026
OCCUPATION_CHANGE_SHARE = 0.03   # 3% of customers change occupation

OCCUPATIONS = [
    "Kirana Shop", "Tailoring", "Dairy", "Vegetable Vendor",
    "Goat Rearing", "Beauty Parlour", "Agriculture",
]

BRANCH_RENAMES = {
    "BR003": "Gorakhpur Central",
    "BR010": "Jabalpur Civil Lines",
}

TABLES = ["branches", "customers"]

RAW_DIR = Path(config.OUTPUT_FOLDER)
BASELINE_DIR = Path("data/master_baseline")


def read_csv(path):
    """Read everything as text so values are written back exactly as they were."""
    return pd.read_csv(path, dtype=str, keep_default_na=False)


def table_path(folder, table):
    return folder / table / f"{table}.csv"


def save_baseline():
    """Keep a copy of version 1 outside data/raw (files there get uploaded)."""
    for table in TABLES:
        source = table_path(RAW_DIR, table)
        target = table_path(BASELINE_DIR, table)

        if target.exists():
            continue

        if not source.exists():
            raise SystemExit(f"{source} not found. Run data_generator/main.py first.")

        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        print(f"Saved version 1 of {table} to {target}")


def check_baseline_is_current():
    """Stop if the data was regenerated after the baseline was saved."""
    base = read_csv(table_path(BASELINE_DIR, "customers"))["customer_id"]
    current = read_csv(table_path(RAW_DIR, "customers"))["customer_id"]

    if set(base) != set(current):
        raise SystemExit(
            "data/master_baseline is out of date (the data was regenerated). "
            "Delete the data/master_baseline folder and run this script again."
        )


def revert():
    for table in TABLES:
        shutil.copy2(table_path(BASELINE_DIR, table), table_path(RAW_DIR, table))
    print("Master files are back to version 1.")


def apply_changes():
    rng = random.Random(SEED)   # own generator, no effect on the main data

    # ----- Customers: some change occupation -----
    customers = read_csv(table_path(BASELINE_DIR, "customers"))

    how_many = round(len(customers) * OCCUPATION_CHANGE_SHARE)
    changed_rows = sorted(rng.sample(range(len(customers)), how_many))

    for row in changed_rows:
        old = customers.at[row, "occupation"]
        customers.at[row, "occupation"] = rng.choice(
            [o for o in OCCUPATIONS if o != old]
        )

    customers.to_csv(table_path(RAW_DIR, "customers"), index=False)

    # ----- Branches: a few are renamed -----
    branches = read_csv(table_path(BASELINE_DIR, "branches"))

    for branch_id, new_name in BRANCH_RENAMES.items():
        branches.loc[branches["branch_id"] == branch_id, "branch_name"] = new_name

    branches.to_csv(table_path(RAW_DIR, "branches"), index=False)

    print(f"Customers with a new occupation: {how_many}")
    print(f"Branches renamed: {len(BRANCH_RENAMES)}")
    print("Now run the pipeline so the new master files are loaded.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--revert", action="store_true",
                        help="restore the original (version 1) master files")
    args = parser.parse_args()

    save_baseline()
    check_baseline_is_current()

    if args.revert:
        revert()
    else:
        apply_changes()


if __name__ == "__main__":
    main()
