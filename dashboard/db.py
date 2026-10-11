# db.py
# Connection to Snowflake and a helper to run queries.

from decimal import Decimal

import pandas as pd
import snowflake.connector
import streamlit as st


@st.cache_resource
def get_connection():
    """Open ONE Snowflake connection and reuse it for every query."""
    cfg = st.secrets["snowflake"]

    return snowflake.connector.connect(
        account=cfg["account"],
        user=cfg["user"],
        role=cfg["role"],
        warehouse=cfg["warehouse"],
        database=cfg["database"],
        schema=cfg["schema"],
        authenticator="SNOWFLAKE_JWT",
        private_key_file=cfg["private_key_file"],
        client_session_keep_alive=True,
    )


@st.cache_data(ttl=3600)
def run_query(sql, params=None):
    """Run a query and return a pandas DataFrame.
    Results are cached for 1 hour.
    """
    cursor = get_connection().cursor()

    try:
        cursor.execute(sql, params)
        rows = cursor.fetchall()
        columns = [col[0].lower() for col in cursor.description]
    finally:
        cursor.close()

    df = pd.DataFrame(rows, columns=columns)

    # Snowflake sends numbers as Decimal. Charts need normal floats.
    for col in df.columns:
        if df[col].map(lambda v: isinstance(v, Decimal)).any():
            df[col] = df[col].astype(float)

    return df