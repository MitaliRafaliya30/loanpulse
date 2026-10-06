# generate_master_data.py
# Creates branches, borrower groups and customers.

import random
from datetime import date, timedelta
from faker import Faker

import config

fake = Faker("en_IN")  # Indian names


def random_date_between(start, end):
    """Pick a random date between start and end (both included)."""
    total_days = (end - start).days
    return start + timedelta(days=random.randint(0, total_days))


def make_branches():
    branches = []
    for branch_id, name, district, state in config.BRANCHES:
        branches.append({
            "branch_id": branch_id,
            "branch_name": name,
            "district": district,
            "state": state,
            "opened_date": random_date_between(date(2017, 1, 1), date(2023, 12, 31)),
        })
    return branches


def pick_behaviour(is_high_risk_group):
    """Decide how a customer will repay. This stays hidden from the bank."""
    if is_high_risk_group:
        weights = config.BEHAVIOUR_HIGH_RISK_GROUP
    else:
        weights = config.BEHAVIOUR_LOW_RISK_GROUP
    return random.choices(["good", "sometimes_late", "defaulter"], weights=weights)[0]


def make_groups_and_customers(branches):
    groups = []
    customers = []
    branch_ids = [b["branch_id"] for b in branches]

    # Groups are formed up to 30 days before the last loan date
    last_group_date = config.LAST_DISBURSEMENT_DATE - timedelta(days=30)

    group_number = 0
    customer_number = 0

    while customer_number < config.NUM_CUSTOMERS:
        group_number += 1
        group_id = f"GRP{group_number:04d}"
        branch_id = random.choice(branch_ids)
        formed_date = random_date_between(config.START_DATE, last_group_date)

        # Is this a high risk group?
        if branch_id in config.STRESSED_BRANCHES:
            high_risk_chance = config.HIGH_RISK_GROUP_SHARE_STRESSED
        else:
            high_risk_chance = config.HIGH_RISK_GROUP_SHARE_NORMAL
        is_high_risk = random.random() < high_risk_chance

        groups.append({
            "group_id": group_id,
            "branch_id": branch_id,
            "formed_date": formed_date,
        })

        group_size = random.randint(config.GROUP_SIZE_MIN, config.GROUP_SIZE_MAX)
        for _ in range(group_size):
            if customer_number >= config.NUM_CUSTOMERS:
                break
            customer_number += 1
            customers.append({
                "customer_id": f"CUST{customer_number:05d}",
                "full_name": fake.name_female(),
                "phone": str(random.randint(6000000000, 9999999999)),
                "aadhaar_number": str(random.randint(200000000000, 999999999999)),
                "group_id": group_id,
                "branch_id": branch_id,
                "occupation": random.choice(
                    ["Kirana Shop", "Tailoring", "Dairy", "Vegetable Vendor",
                     "Goat Rearing", "Beauty Parlour", "Agriculture"]
                ),
                "onboarded_date": formed_date,
                # Hidden column, removed before saving
                "behaviour": pick_behaviour(is_high_risk),
            })

    return groups, customers