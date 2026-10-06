# main.py
# Run this file to generate all fake bank data.

import random
from collections import Counter
from faker import Faker

import config
from generate_master_data import make_branches, make_groups_and_customers
from generate_loans import make_loans_and_schedules
from generate_collections import make_collections_and_writeoffs
from save_data import save_all


def main():
    # Fix the seeds so we get the same data every run
    random.seed(config.RANDOM_SEED)
    Faker.seed(config.RANDOM_SEED)

    print("Creating branches, groups and customers...")
    branches = make_branches()
    groups, customers = make_groups_and_customers(branches)

    print("Creating loans and repayment schedules...")
    loans, schedules = make_loans_and_schedules(customers)

    print("Creating collections and write-offs...")
    collections, writeoffs = make_collections_and_writeoffs(loans, schedules, customers)

    print("Saving files...")
    counts = save_all(branches, groups, customers, loans, schedules, collections, writeoffs)

    # Summary so we can check the data makes sense
    print("\n===== ROW COUNTS =====")
    for table, count in counts.items():
        print(f"{table:20s} {count:>8,}")

    print("\n===== CUSTOMER BEHAVIOUR (hidden truth) =====")
    for behaviour, count in Counter(c["behaviour"] for c in customers).items():
        print(f"{behaviour:20s} {count:>8,}")

    late_posted = sum(1 for c in collections if c["posted_date"] > c["payment_date"])
    print("\n===== DATA CHECKS =====")
    print(f"Payments posted late:  {late_posted:,} of {len(collections):,} "
          f"({late_posted / len(collections):.1%})")
    unique_ids = len(set(c["collection_id"] for c in collections))
    print(f"Duplicate payment rows: {len(collections) - unique_ids:,}")
    print(f"\nFiles saved in: {config.OUTPUT_FOLDER}")


if __name__ == "__main__":
    main()