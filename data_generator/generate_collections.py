# generate_collections.py
# Creates payments (collections) and write-offs based on customer behaviour.

import random
from datetime import timedelta

import config


def make_payment(loan_id, branch_id, payment_date, amount):
    """Create one payment row. Returns None if it falls after 'today'."""
    if random.random() < config.UPI_SHARE:
        payment_mode = "UPI"
        delay = 0                      # UPI is recorded instantly
    else:
        payment_mode = "CASH"
        delay = random.choices(config.CASH_POSTING_DELAY_DAYS,
                               weights=config.CASH_POSTING_DELAY_WEIGHTS)[0]

    posted_date = payment_date + timedelta(days=delay)

    # Our bank cannot know about payments recorded after END_DATE
    if posted_date > config.END_DATE:
        return None

    return {
        "loan_id": loan_id,
        "payment_date": payment_date,
        "posted_date": posted_date,
        "amount": round(amount, 2),
        "payment_mode": payment_mode,
        "field_officer_id": f"FO_{branch_id}_{random.randint(1, config.OFFICERS_PER_BRANCH)}",
    }


def on_time_date(due_date):
    """Good payers pay between 2 days early and 3 days late."""
    return due_date + timedelta(days=random.randint(-2, 3))


def make_collections_and_writeoffs(loans, schedules, customers):
    # Quick lookups
    branch_of_customer = {c["customer_id"]: c["branch_id"] for c in customers}
    schedule_of_loan = {}
    for row in schedules:
        schedule_of_loan.setdefault(row["loan_id"], []).append(row)

    collections = []
    writeoffs = []

    for loan in loans:
        loan_id = loan["loan_id"]
        branch_id = branch_of_customer[loan["customer_id"]]
        installments = schedule_of_loan[loan_id]
        behaviour = loan["behaviour"]
        planned = []   # list of (payment_date, amount)

        if behaviour == "good":
            for inst in installments:
                planned.append((on_time_date(inst["due_date"]), inst["total_due"]))

        elif behaviour == "sometimes_late":
            for inst in installments:
                if random.random() < 0.7:
                    pay_date = on_time_date(inst["due_date"])
                else:
                    pay_date = inst["due_date"] + timedelta(days=random.randint(5, 40))
                planned.append((pay_date, inst["total_due"]))

        else:  # defaulter
            stop_at = random.randint(2, loan["tenure_months"] - 2)

            # Pays normally before stopping
            for inst in installments:
                if inst["installment_number"] < stop_at:
                    planned.append((on_time_date(inst["due_date"]), inst["total_due"]))

            first_missed_due = installments[stop_at - 1]["due_date"]

            if random.random() < config.DEFAULTER_RECOVERY_CHANCE:
                # Pays ALL missed dues in one go later, then continues normally
                recovery_date = first_missed_due + timedelta(days=random.randint(60, 150))
                lump_sum = sum(i["total_due"] for i in installments
                               if i["installment_number"] >= stop_at
                               and i["due_date"] <= recovery_date)
                planned.append((recovery_date, lump_sum))
                for inst in installments:
                    if inst["installment_number"] >= stop_at and inst["due_date"] > recovery_date:
                        planned.append((on_time_date(inst["due_date"]), inst["total_due"]))
            else:
                # Never pays again, bank writes it off later
                writeoff_date = first_missed_due + timedelta(days=config.WRITEOFF_AFTER_DAYS)
                if writeoff_date <= config.END_DATE:
                    unpaid_principal = sum(i["principal_due"] for i in installments
                                           if i["installment_number"] >= stop_at)
                    writeoffs.append({
                        "loan_id": loan_id,
                        "writeoff_date": writeoff_date,
                        "writeoff_amount": round(unpaid_principal, 2),
                    })

        # Turn planned payments into rows (skip future ones)
        for pay_date, amount in planned:
            if pay_date > config.END_DATE:
                continue
            row = make_payment(loan_id, branch_id, pay_date, amount)
            if row is not None:
                collections.append(row)

    # Give every payment an ID, in date order
    collections.sort(key=lambda r: (r["payment_date"], r["loan_id"]))
    for i, row in enumerate(collections, start=1):
        row["collection_id"] = f"COL{i:07d}"

    # Add a few duplicate rows on purpose (real systems send duplicates)
    num_duplicates = int(len(collections) * config.DUPLICATE_COLLECTION_SHARE)
    duplicates = [dict(row) for row in random.sample(collections, num_duplicates)]
    collections.extend(duplicates)

    return collections, writeoffs