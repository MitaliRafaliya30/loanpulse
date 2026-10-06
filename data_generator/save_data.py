# save_data.py
# Saves tables as CSV files in the folder layout a bank would send daily.

import os
import shutil
import pandas as pd

import config


def save_full_table(df, table_name):
    """Master data: one complete file."""
    folder = os.path.join(config.OUTPUT_FOLDER, table_name)
    os.makedirs(folder, exist_ok=True)
    df.to_csv(os.path.join(folder, f"{table_name}.csv"), index=False)


def save_daily_files(df, table_name, date_column, keep_date_column=True):
    """Daily data: one file per day, inside a folder named date=YYYY-MM-DD."""
    for day, day_df in df.groupby(date_column):
        if not keep_date_column:
            day_df = day_df.drop(columns=[date_column])
        folder = os.path.join(config.OUTPUT_FOLDER, table_name, f"date={day}")
        os.makedirs(folder, exist_ok=True)
        day_df.to_csv(os.path.join(folder, f"{table_name}.csv"), index=False)


def save_all(branches, groups, customers, loans, schedules, collections, writeoffs):
    # Start fresh: delete old files from earlier runs
    if os.path.exists(config.OUTPUT_FOLDER):
        shutil.rmtree(config.OUTPUT_FOLDER)

    # Convert lists to tables (and remove hidden behaviour column)
    branches_df = pd.DataFrame(branches)
    groups_df = pd.DataFrame(groups)
    customers_df = pd.DataFrame(customers).drop(columns=["behaviour"])
    loans_df = pd.DataFrame(loans).drop(columns=["behaviour"])
    schedules_df = pd.DataFrame(schedules)
    collections_df = pd.DataFrame(collections)
    writeoffs_df = pd.DataFrame(writeoffs)

    # Put collection columns in the same order as our data model
    collections_df = collections_df[[
        "collection_id", "loan_id", "payment_date", "posted_date",
        "amount", "payment_mode", "field_officer_id",
    ]]

    # A loan's schedule arrives on the day the loan is disbursed
    schedules_df = schedules_df.merge(
        loans_df[["loan_id", "disbursement_date"]], on="loan_id"
    )

    # Master data: full files
    save_full_table(branches_df, "branches")
    save_full_table(groups_df, "borrower_groups")
    save_full_table(customers_df, "customers")

    # Daily data: one folder per day
    save_daily_files(loans_df, "loans", "disbursement_date")
    save_daily_files(schedules_df, "repayment_schedule", "disbursement_date",
                     keep_date_column=False)
    save_daily_files(collections_df, "collections", "posted_date")
    save_daily_files(writeoffs_df, "loan_writeoffs", "writeoff_date")

    return {
        "branches": len(branches_df),
        "borrower_groups": len(groups_df),
        "customers": len(customers_df),
        "loans": len(loans_df),
        "repayment_schedule": len(schedules_df),
        "collections": len(collections_df),
        "loan_writeoffs": len(writeoffs_df),
    }