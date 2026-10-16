# generate_commentary.py
# Monthly portfolio commentary written by an LLM, with a number check.
#
# 1. SQL computes every number (the LLM never calculates anything).
# 2. The LLM turns those numbers into a short management note.
# 3. A checker confirms every number in the note exists in the facts.
# 4. If the check fails twice, a plain template is used instead.

import json
import re
import tomllib
from datetime import datetime
from decimal import Decimal
from pathlib import Path

import requests
import snowflake.connector


# This assumes the script is saved inside a subfolder of the project root,
# for example: loanpulse/ml/generate_commentary.py
PROJECT_DIR = Path(__file__).resolve().parent.parent
SECRETS_FILE = PROJECT_DIR / "dashboard" / ".streamlit" / "secrets.toml"
REPORTS_DIR = PROJECT_DIR / "reports"

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

# Numbers that can appear in text without being treated as portfolio facts:
# RBI categories (SMA-0/1/2) and DPD thresholds (30/60/90 days).
ALWAYS_ALLOWED = [0, 1, 2, 30, 60, 90]

SYSTEM_PROMPT = """
You are a credit risk analyst at an Indian small finance bank.
Write a short monthly portfolio commentary for senior management.

Rules:
1. Use ONLY the facts in the JSON you are given.
2. Every number you write must appear in the facts. Copy numbers exactly.
   Do not calculate new numbers. Do not round differently.
3. Do not mention loan IDs, branch IDs or customer details.
4. Plain, factual English. No hype words.
5. Use exactly this format, maximum 150 words:

### Headline
One sentence.

### What changed
- 2 or 3 bullet points

### Where to act
- 2 bullet points
""".strip()


def load_config():
    """Load Snowflake and OpenRouter settings from Streamlit secrets."""
    if not SECRETS_FILE.exists():
        raise FileNotFoundError(
            f"Secrets file not found: {SECRETS_FILE}. "
            "Create dashboard/.streamlit/secrets.toml first."
        )

    with open(SECRETS_FILE, "rb") as file:
        return tomllib.load(file)


def run_query(conn, sql, params=None):
    """Return query results as dictionaries with lowercase keys."""
    cursor = conn.cursor()
    try:
        cursor.execute(sql, params)
        columns = [column[0].lower() for column in cursor.description]
        rows = []

        for row in cursor.fetchall():
            rows.append(
                {
                    column: float(value)
                    if isinstance(value, Decimal)
                    else value
                    for column, value in zip(columns, row)
                }
            )

        return rows
    finally:
        cursor.close()


def build_facts(conn):
    """Compute every number the commentary is allowed to use."""
    months = run_query(
        conn,
        """
        SELECT
            snapshot_date,
            SUM(active_loans) AS active_loans,
            SUM(total_outstanding) AS total_outstanding,
            100 * SUM(npa_outstanding)
                / NULLIF(SUM(total_outstanding), 0) AS gnpa_pct,
            100 * SUM(par30_outstanding)
                / NULLIF(SUM(total_outstanding), 0) AS par30_pct,
            100 * SUM(amount_collected)
                / NULLIF(SUM(amount_due), 0) AS collection_efficiency_pct
        FROM FCT_BRANCH_MONTHLY_METRICS
        GROUP BY snapshot_date
        ORDER BY snapshot_date DESC
        LIMIT 2
        """,
    )

    if len(months) < 2:
        raise ValueError(
            "At least two month-end rows are required to calculate month-over-month changes."
        )

    latest, previous = months[0], months[1]
    month_end = latest["snapshot_date"]

    branches = run_query(
        conn,
        """
        SELECT
            b.branch_name,
            b.district,
            m.gnpa_pct,
            m.collection_efficiency_pct
        FROM FCT_BRANCH_MONTHLY_METRICS AS m
        JOIN (
            SELECT DISTINCT
                branch_id,
                branch_name,
                district
            FROM DIM_CUSTOMERS
        ) AS b
            ON m.branch_id = b.branch_id
        WHERE m.snapshot_date = %s
        ORDER BY m.gnpa_pct DESC
        LIMIT 3
        """,
        (month_end,),
    )

    roll = run_query(
        conn,
        """
        SELECT
            from_class,
            to_class,
            pct_of_from_class
        FROM FCT_MONTHLY_ROLL_RATES
        WHERE snapshot_date = %s
        """,
        (month_end,),
    )

    roll_lookup = {
        (row["from_class"], row["to_class"]): row["pct_of_from_class"]
        for row in roll
    }

    restatements = run_query(
        conn,
        """
        SELECT
            snapshot_date,
            loans_reclassified
        FROM RPT_MONTH_END_RESTATEMENTS
        ORDER BY snapshot_date
        """,
    )

    if len(restatements) < 2:
        raise ValueError(
            "At least two restatement rows are required for the data-quality facts."
        )

    if not branches:
        raise ValueError(
            "No branch metrics were found for the latest month-end snapshot."
        )

    return {
        "month": month_end.strftime("%B %Y"),
        "portfolio": {
            "outstanding_crore": round(
                latest["total_outstanding"] / 1e7, 2
            ),
            "active_loans": int(latest["active_loans"]),
            "gnpa_pct": round(latest["gnpa_pct"], 2),
            "gnpa_change_points": round(
                latest["gnpa_pct"] - previous["gnpa_pct"], 2
            ),
            "par30_pct": round(latest["par30_pct"], 2),
            "par30_change_points": round(
                latest["par30_pct"] - previous["par30_pct"], 2
            ),
            "collection_efficiency_pct": round(
                latest["collection_efficiency_pct"], 2
            ),
            "collection_efficiency_change_points": round(
                latest["collection_efficiency_pct"]
                - previous["collection_efficiency_pct"],
                2,
            ),
        },
        "most_stressed_branches": [
            {
                "branch": f"{branch['branch_name']} ({branch['district']})",
                "gnpa_pct": round(branch["gnpa_pct"], 2),
                "collection_efficiency_pct": round(
                    branch["collection_efficiency_pct"], 2
                ),
            }
            for branch in branches
        ],
        "roll_rates_pct": {
            "standard_to_sma0": roll_lookup.get(("STANDARD", "SMA_0"), 0),
            "sma0_cured_to_standard": roll_lookup.get(("SMA_0", "STANDARD"), 0),
            "sma1_to_sma2": roll_lookup.get(("SMA_1", "SMA_2"), 0),
            "sma2_to_npa": roll_lookup.get(("SMA_2", "NPA"), 0),
        },
        "data_quality": {
            "previous_month_loans_reclassified_after_reporting": int(
                restatements[-2]["loans_reclassified"]
            ),
            "total_loans_reclassified_after_reporting": int(
                sum(row["loans_reclassified"] for row in restatements)
            ),
        },
    }


# -------------------------------------------------------------------
# Number check
# -------------------------------------------------------------------

def collect_numbers(value, found):
    """Walk through the facts and collect all numeric values."""
    if isinstance(value, dict):
        for item in value.values():
            collect_numbers(item, found)
    elif isinstance(value, list):
        for item in value:
            collect_numbers(item, found)
    elif isinstance(value, (int, float)) and not isinstance(value, bool):
        found.append(abs(float(value)))
    elif isinstance(value, str):
        # Also collect numbers embedded in text, e.g. the year in "June 2026".
        for number in re.findall(r"\d+(?:\.\d+)?", value):
            found.append(float(number))

    return found


def numbers_in_text(text):
    """Find numbers while ignoring IDs such as BR005 and Q1."""
    return re.findall(
        r"(?<![A-Za-z0-9_])\d[\d,]*(?:\.\d+)?",
        text,
    )


def find_unsupported_numbers(text, facts):
    """Return text numbers that do not match a number from the supplied facts."""
    allowed = collect_numbers(facts, []) + ALWAYS_ALLOWED
    unsupported = []

    for raw in numbers_in_text(text):
        clean = raw.replace(",", "")
        value = float(clean)
        decimals = len(clean.split(".")[1]) if "." in clean else 0

        # Permit normal rounding, e.g. 5.2 when the fact is 5.18.
        tolerance = 0.5 * 10 ** (-decimals) + 1e-9

        if not any(abs(value - number) <= tolerance for number in allowed):
            unsupported.append(raw)

    return unsupported


# -------------------------------------------------------------------
# OpenRouter LLM call
# -------------------------------------------------------------------


def call_llm(messages, api_key, models):
    """Try configured models and report useful API errors."""
    last_error = None

    for model in models:
        try:
            response = requests.post(
                OPENROUTER_URL,
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": model,
                    "messages": messages,
                    "temperature": 0.2,
                },
                timeout=90,
            )

            try:
                payload = response.json()
            except ValueError:
                last_error = (
                    f"HTTP {response.status_code}: "
                    f"non-JSON response: {response.text[:300]}"
                )
                print(f"Model {model} failed: {last_error}")
                continue

            if not response.ok:
                error_info = payload.get("error", payload)
                last_error = (
                    error_info.get("message", str(error_info))
                    if isinstance(error_info, dict)
                    else str(error_info)
                )
                print(
                    f"Model {model} failed "
                    f"(HTTP {response.status_code}): {last_error}"
                )
                continue

            choices = payload.get("choices")
            if not choices:
                last_error = (
                    "Response has no choices: "
                    + json.dumps(payload)[:500]
                )
                print(f"Model {model} failed: {last_error}")
                continue

            content = choices[0].get("message", {}).get("content")

            if isinstance(content, str) and content.strip():
                return content.strip(), model

            last_error = "empty or non-text response"
            print(f"Model {model} failed: {last_error}")

        except requests.RequestException as error:
            last_error = str(error)
            print(f"Model {model} failed: {last_error}")

    raise RuntimeError(f"All models failed. Last error: {last_error}")



def template_commentary(facts):
    """Safe fallback with portfolio numbers inserted directly from the facts."""
    portfolio = facts["portfolio"]
    worst_branch = facts["most_stressed_branches"][0]
    roll_rates = facts["roll_rates_pct"]

    return f"""### Headline

GNPA was {portfolio['gnpa_pct']}% in {facts['month']}, a change of {portfolio['gnpa_change_points']} points.

### What changed
- PAR 30 was {portfolio['par30_pct']}% ({portfolio['par30_change_points']} points).
- Collection efficiency was {portfolio['collection_efficiency_pct']}% ({portfolio['collection_efficiency_change_points']} points).

### Where to act
- {worst_branch['branch']} has the highest GNPA at {worst_branch['gnpa_pct']}%.
- {roll_rates['sma1_to_sma2']}% of SMA-1 loans moved to SMA-2.
"""


def main():
    config = load_config()
    snowflake_config = config["snowflake"]
    openrouter_config = config["openrouter"]

    conn = snowflake.connector.connect(
        account=snowflake_config["account"],
        user=snowflake_config["user"],
        role=snowflake_config["role"],
        warehouse=snowflake_config["warehouse"],
        database=snowflake_config["database"],
        schema=snowflake_config["schema"],
        authenticator="SNOWFLAKE_JWT",
        private_key_file=snowflake_config["private_key_file"],
    )

    try:
        facts = build_facts(conn)
    finally:
        conn.close()

    print("Facts:")
    print(json.dumps(facts, indent=2, default=str))

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {
            "role": "user",
            "content": (
                f"Facts for {facts['month']}:\n"
                f"{json.dumps(facts, indent=2, default=str)}"
            ),
        },
    ]

    commentary = None
    source = None
    status = None

    for attempt in (1, 2):
        try:
            draft, model_used = call_llm(
                messages,
                openrouter_config["api_key"],
                openrouter_config["models"],
            )
        except RuntimeError as error:
            print(error)
            break

        bad_numbers = find_unsupported_numbers(draft, facts)

        if not bad_numbers:
            commentary = draft
            source = model_used
            status = f"PASSED on attempt {attempt}"
            break

        print(f"Attempt {attempt}: unsupported numbers: {bad_numbers}")

        # Ask the model to rewrite the draft with only supported numbers.
        messages.extend(
            [
                {"role": "assistant", "content": draft},
                {
                    "role": "user",
                    "content": (
                        "These numbers are not in the facts: "
                        f"{', '.join(bad_numbers)}. Rewrite the commentary "
                        "using only numbers that appear in the facts."
                    ),
                },
            ]
        )

    if commentary is None:
        commentary = template_commentary(facts)
        source = "template (LLM output not used)"
        status = "LLM draft failed the number check or the API was unavailable"

    # Save commentary with an audit trail.
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)

    month_key = datetime.strptime(facts["month"], "%B %Y").strftime("%Y-%m")
    report_file = REPORTS_DIR / f"commentary_{month_key}.md"

    report_content = f"""# Portfolio commentary: {facts['month']}

{commentary}

<!-- AUDIT -->

---

- Generated: {datetime.now():%Y-%m-%d %H:%M}
- Written by: {source}
- Number check: {status}

## Facts used

```json
{json.dumps(facts, indent=2, default=str)}
```
"""

    report_file.write_text(report_content, encoding="utf-8")

    print("\n" + commentary)
    print(f"\nWritten by: {source}")
    print(f"Number check: {status}")
    print(f"Saved to {report_file}")


if __name__ == "__main__":
    main()
