# generate_loans.py
# Creates loans and their repayment schedules.

import random
from datetime import timedelta
from dateutil.relativedelta import relativedelta

import config


def calculate_emi(principal, annual_rate, months):
    """Standard EMI formula (reducing balance)."""
    r = annual_rate / 12 / 100          # monthly interest rate
    emi = principal * r * (1 + r) ** months / ((1 + r) ** months - 1)
    return round(emi, 2)


def make_schedule(loan):
    """Break the loan into monthly installments."""
    schedule = []
    balance = loan["principal_amount"]
    r = loan["interest_rate"] / 12 / 100
    emi = calculate_emi(loan["principal_amount"], loan["interest_rate"], loan["tenure_months"])

    for n in range(1, loan["tenure_months"] + 1):
        interest_due = round(balance * r, 2)
        principal_due = round(emi - interest_due, 2)

        # Last installment clears whatever is left (fixes rounding)
        if n == loan["tenure_months"]:
            principal_due = round(balance, 2)

        balance = round(balance - principal_due, 2)

        schedule.append({
            "loan_id": loan["loan_id"],
            "installment_number": n,
            "due_date": loan["disbursement_date"] + relativedelta(months=n),
            "principal_due": principal_due,
            "interest_due": interest_due,
            "total_due": round(principal_due + interest_due, 2),
        })
    return schedule


def make_loans_and_schedules(customers):
    loans = []
    schedules = []
    loan_number = 0

    for customer in customers:
        # First loan: 7 to 30 days after joining
        disbursement_date = customer["onboarded_date"] + timedelta(days=random.randint(7, 30))

        while disbursement_date <= config.LAST_DISBURSEMENT_DATE:
            loan_number += 1
            loan = {
                "loan_id": f"LN{loan_number:06d}",
                "customer_id": customer["customer_id"],
                "product_type": "MICROFINANCE_JLG",
                "principal_amount": random.choice(config.PRINCIPAL_OPTIONS),
                "interest_rate": round(random.uniform(config.INTEREST_RATE_MIN,
                                                      config.INTEREST_RATE_MAX), 2),
                "tenure_months": random.choice(config.TENURE_OPTIONS),
                "disbursement_date": disbursement_date,
                # Hidden column, removed before saving
                "behaviour": customer["behaviour"],
            }
            schedule = make_schedule(loan)
            loans.append(loan)
            schedules.extend(schedule)

            # Only good customers get a repeat loan, and only sometimes
            if customer["behaviour"] != "good" or random.random() > config.REPEAT_LOAN_CHANCE:
                break

            # Repeat loan starts 7 to 30 days after the last installment
            last_due_date = schedule[-1]["due_date"]
            disbursement_date = last_due_date + timedelta(days=random.randint(7, 30))

    return loans, schedules