# Start from the official Airflow image (same version as docker-compose.yaml)
FROM apache/airflow:3.3.2

# Libraries our DAG uses directly
RUN pip install --no-cache-dir \
    "apache-airflow==${AIRFLOW_VERSION}" \
    boto3 \
    snowflake-connector-python

# dbt in its OWN virtual environment, so its libraries never clash with Airflow's
RUN python -m venv /home/airflow/dbt_venv \
    && /home/airflow/dbt_venv/bin/pip install --no-cache-dir dbt-snowflake

# Do not send anonymous usage data from dbt
ENV DBT_SEND_ANONYMOUS_USAGE_STATS=False