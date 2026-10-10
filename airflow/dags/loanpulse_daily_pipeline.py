"""
LoanPulse daily pipeline.

Every morning:
1. Upload new source files to S3.
2. Load new files from S3 into Snowflake RAW.
3. Find the latest business date in the data.
4. Run dbt build (models + tests) for that date.
5. Log a portfolio health summary and raise alerts.
"""

import os

import boto3
import pendulum
import snowflake.connector

from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import dag, task


# ---------- Settings (paths are inside the Docker container) ----------

RAW_DATA_DIR = "/opt/airflow/project/data/raw"
DBT_PROJECT_DIR = "/opt/airflow/project/loanpulse_dbt"
DBT_PROFILES_DIR = "/opt/airflow/project/dbt_profiles"
DBT_EXECUTABLE = "/home/airflow/dbt_venv/bin/dbt"
PRIVATE_KEY_PATH = "/home/airflow/.snowflake/dbt_user_key.p8"

S3_BUCKET = os.environ["LOANPULSE_S3_BUCKET"]
SNOWFLAKE_ACCOUNT = os.environ["SNOWFLAKE_ACCOUNT"]

# Master data is sent as a full file every day.
MASTER_TABLES = [
    "branches",
    "borrower_groups",
    "customers",
]

# Daily transactional data.
DAILY_TABLES = [
    "loans",
    "repayment_schedule",
    "collections",
    "loan_writeoffs",
]

# Column lists must match the order of columns in the CSV files.
COLUMNS = {
    "branches": (
        "branch_id, branch_name, district, state, opened_date"
    ),
    "borrower_groups": (
        "group_id, branch_id, formed_date"
    ),
    "customers": (
        "customer_id, full_name, phone, aadhaar_number, group_id, "
        "branch_id, occupation, onboarded_date"
    ),
    "loans": (
        "loan_id, customer_id, product_type, principal_amount, "
        "interest_rate, tenure_months, disbursement_date"
    ),
    "repayment_schedule": (
        "loan_id, installment_number, due_date, principal_due, "
        "interest_due, total_due"
    ),
    "collections": (
        "collection_id, loan_id, payment_date, posted_date, amount, "
        "payment_mode, field_officer_id"
    ),
    "loan_writeoffs": (
        "loan_id, writeoff_date, writeoff_amount"
    ),
}

# Alert if GNPA rises by more than 0.5 percentage points month over month.
GNPA_ALERT_THRESHOLD = 0.5


# ---------- Snowflake connection ----------

def get_snowflake_connection(user, role):
    """Connect to Snowflake using key-pair authentication."""
    return snowflake.connector.connect(
        account=SNOWFLAKE_ACCOUNT,
        user=user,
        role=role,
        authenticator="SNOWFLAKE_JWT",
        private_key_file=PRIVATE_KEY_PATH,
        warehouse="LOANPULSE_WH",
        database="LOANPULSE",
    )


# ---------- S3-to-Snowflake loading helpers ----------

def build_copy_sql(table, force=False):
    """Build a COPY INTO statement for a source table."""
    columns = COLUMNS[table]
    number_of_columns = len(columns.split(","))

    positions = ", ".join(
        f"${i}"
        for i in range(1, number_of_columns + 1)
    )

    sql = (
        f"COPY INTO RAW.{table.upper()} ({columns}, _source_file) "
        f"FROM (SELECT {positions}, METADATA$FILENAME "
        f"FROM @RAW.S3_RAW_STAGE/{table}/) "
        "FILE_FORMAT = (FORMAT_NAME = 'RAW.CSV_FORMAT')"
    )

    if force:
        sql += " FORCE = TRUE"

    return sql


def count_loaded_files(cursor):
    """Count files whose Snowflake COPY status is LOADED."""
    if not cursor.description:
        return 0

    column_names = [
        column[0].lower()
        for column in cursor.description
    ]

    if "status" not in column_names:
        return 0

    status_index = column_names.index("status")

    return sum(
        1
        for row in cursor.fetchall()
        if row[status_index] == "LOADED"
    )


# ---------- DAG definition ----------

@dag(
    dag_id="loanpulse_daily_pipeline",
    description="Daily loan portfolio pipeline: S3 to Snowflake to dbt",
    schedule="0 6 * * *",
    start_date=pendulum.datetime(
        2026, 10, 1, tz="Asia/Kolkata"
    ),
    catchup=False,
    max_active_runs=1,
    default_args={
        "owner": "loanpulse",
        "retries": 2,
        "retry_delay": pendulum.duration(minutes=2),
    },
    tags=["loanpulse", "banking"],
)
def loanpulse_daily_pipeline():

    # ============================================================
    # TASK 1: Upload source files to S3
    # ============================================================

    @task
    def upload_new_files_to_s3():
        """
        Upload new transactional files.
        Master-data files are always re-uploaded.
        """
        s3 = boto3.client("s3")

        # Find all object keys already present in S3.
        existing_keys = set()
        paginator = s3.get_paginator("list_objects_v2")

        for page in paginator.paginate(
            Bucket=S3_BUCKET,
            Prefix="raw/",
        ):
            for obj in page.get("Contents", []):
                existing_keys.add(obj["Key"])

        uploaded = 0

        for folder, _, files in os.walk(RAW_DATA_DIR):
            for file_name in files:
                local_path = os.path.join(folder, file_name)

                relative_path = os.path.relpath(
                    local_path,
                    RAW_DATA_DIR,
                )

                s3_key = (
                    "raw/"
                    + relative_path.replace(os.sep, "/")
                )

                table_name = relative_path.split(os.sep)[0]
                is_master = table_name in MASTER_TABLES

                # Skip transactional files already present in S3.
                if s3_key in existing_keys and not is_master:
                    continue

                s3.upload_file(
                    local_path,
                    S3_BUCKET,
                    s3_key,
                )

                uploaded += 1

        print(
            f"Uploaded {uploaded} file(s) "
            f"to s3://{S3_BUCKET}/raw/"
        )

        return uploaded

    # ============================================================
    # TASK 2: Load files into Snowflake RAW
    # ============================================================

    @task
    def load_raw_to_snowflake():
        """Load master and transactional files into RAW tables."""
        conn = get_snowflake_connection(
            user="LOADER_USER",
            role="LOADER",
        )
        cursor = conn.cursor()

        total_loaded = 0

        try:
            # Master data: delete existing records and reload.
            for table in MASTER_TABLES:
                cursor.execute("BEGIN")

                cursor.execute(
                    f"DELETE FROM RAW.{table.upper()}"
                )

                cursor.execute(
                    build_copy_sql(table, force=True)
                )

                loaded = count_loaded_files(cursor)

                cursor.execute("COMMIT")

                print(
                    f"{table}: full reload, "
                    f"{loaded} file(s)"
                )

            # Transactional data: skip previously loaded files.
            for table in DAILY_TABLES:
                cursor.execute(
                    build_copy_sql(table, force=False)
                )

                loaded = count_loaded_files(cursor)
                total_loaded += loaded

                print(
                    f"{table}: {loaded} new file(s) loaded"
                )

        except Exception:
            try:
                cursor.execute("ROLLBACK")
            except Exception:
                pass
            raise

        finally:
            cursor.close()
            conn.close()

        print(
            f"Total new daily files loaded: {total_loaded}"
        )

        return total_loaded

    # ============================================================
    # TASK 3: Find the latest business date
    # ============================================================

    @task
    def get_business_date():
        """
        Use the latest posted payment date as the business date.
        dbt receives this value as as_of_date.
        """
        conn = get_snowflake_connection(
            user="LOADER_USER",
            role="LOADER",
        )
        cursor = conn.cursor()

        try:
            cursor.execute(
                "SELECT MAX(posted_date) FROM RAW.COLLECTIONS"
            )

            business_date = cursor.fetchone()[0]

        finally:
            cursor.close()
            conn.close()

        if business_date is None:
            raise ValueError(
                "Unable to determine business date: "
                "RAW.COLLECTIONS has no posted dates."
            )

        print(f"Business date: {business_date}")

        return str(business_date)

    # ============================================================
    # TASK 4: Run dbt models and tests
    # ============================================================

    dbt_build = BashOperator(
        task_id="dbt_build",
        bash_command=(
            f"cd {DBT_PROJECT_DIR} && "
            f"{DBT_EXECUTABLE} build "
            f"--profiles-dir {DBT_PROFILES_DIR} "
            "--target-path /tmp/dbt_target "
            "--log-path /tmp/dbt_logs "
            '--vars "{as_of_date: \'$AS_OF_DATE\'}"'
        ),
        env={
            "AS_OF_DATE": (
                "{{ ti.xcom_pull(task_ids='get_business_date') }}"
            )
        },
        append_env=True,
        retries=0,
    )

    # ============================================================
    # TASK 5: Portfolio health summary and alert
    # ============================================================

    @task
    def portfolio_health_summary():
        """Log portfolio metrics and flag a sharp GNPA increase."""
        conn = get_snowflake_connection(
            user="DBT_USER",
            role="TRANSFORMER",
        )
        cursor = conn.cursor()

        try:
            cursor.execute(
                """
                SELECT
                    snapshot_date,
                    ROUND(
                        100 * SUM(npa_outstanding)
                        / NULLIF(SUM(total_outstanding), 0),
                        2
                    ) AS gnpa_pct,
                    ROUND(
                        100 * SUM(par30_outstanding)
                        / NULLIF(SUM(total_outstanding), 0),
                        2
                    ) AS par30_pct,
                    ROUND(
                        100 * SUM(amount_collected)
                        / NULLIF(SUM(amount_due), 0),
                        2
                    ) AS collection_efficiency_pct
                FROM MARTS.FCT_BRANCH_MONTHLY_METRICS
                GROUP BY snapshot_date
                ORDER BY snapshot_date DESC
                LIMIT 2
                """
            )

            rows = cursor.fetchall()

            if not rows:
                print("No monthly portfolio metrics are available.")
                return

            latest = rows[0]
            previous = rows[1] if len(rows) > 1 else None

            cursor.execute(
                """
                SELECT
                    branch_id,
                    gnpa_pct
                FROM MARTS.FCT_BRANCH_MONTHLY_METRICS
                WHERE snapshot_date = (
                    SELECT MAX(snapshot_date)
                    FROM MARTS.FCT_BRANCH_MONTHLY_METRICS
                )
                ORDER BY gnpa_pct DESC
                LIMIT 1
                """
            )

            worst_branch_row = cursor.fetchone()

        finally:
            cursor.close()
            conn.close()

        month, gnpa, par30, collection_eff = latest

        previous_gnpa = previous[1] if previous else None

        if gnpa is not None and previous_gnpa is not None:
            gnpa_change = gnpa - previous_gnpa
        else:
            gnpa_change = None

        print("=========== PORTFOLIO HEALTH ===========")
        print(f"Month-end: {month}")
        print(f"GNPA: {gnpa}%")
        print(f"PAR 30: {par30}%")
        print(f"Collection efficiency: {collection_eff}%")

        if worst_branch_row:
            worst_branch, worst_gnpa = worst_branch_row
            print(
                f"Worst branch: {worst_branch} "
                f"({worst_gnpa}% GNPA)"
            )
        else:
            worst_branch = None
            print("Worst branch: unavailable")

        if gnpa_change is not None:
            print(f"GNPA change: {gnpa_change:+.2f} percentage points")

        print("========================================")

        if (
            gnpa_change is not None
            and gnpa_change > GNPA_ALERT_THRESHOLD
        ):
            print(
                f"ALERT: GNPA rose by {gnpa_change:.2f} "
                f"percentage points. Review branch "
                f"{worst_branch} first."
            )

    # ============================================================
    # TASK DEPENDENCIES
    # ============================================================

    uploaded = upload_new_files_to_s3()
    loaded = load_raw_to_snowflake()
    business_date = get_business_date()
    summary = portfolio_health_summary()

    uploaded >> loaded >> business_date >> dbt_build >> summary


loanpulse_daily_pipeline()