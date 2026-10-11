# train_early_warning.py
# Early warning: which loans that are 0 to 30 days late today
# will become MORE than 30 days late in the next 60 days?
#
# Champion: a simple business rule (flag every loan that is already late).
# Challenger: a logistic regression model.
# The model is only recommended if it clearly beats the rule.

import tomllib
from datetime import date
from decimal import Decimal
from pathlib import Path

import pandas as pd
import snowflake.connector
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score


FEATURES = [
    "dpd_now",
    "late_months_6m",
    "branch_gnpa_pct",
    "group_late_share",
]

LABEL = "went_30plus_next_60d"

TRAIN_END = date(2025, 12, 31)  # Train on months up to here
MIN_IMPROVEMENT = 0.05  # Challenger must catch 5+ percentage points more bad loans

PROJECT_DIR = Path(__file__).resolve().parent.parent

SECRETS_FILE = (
    PROJECT_DIR / "dashboard" / ".streamlit" / "secrets.toml"
)

REPORT_FILE = Path(__file__).resolve().parent / "model_report.md"


def load_features():
    """Read the feature table from Snowflake using read-only ANALYST access."""

    with open(SECRETS_FILE, "rb") as f:
        cfg = tomllib.load(f)["snowflake"]

    conn = snowflake.connector.connect(
        account=cfg["account"],
        user=cfg["user"],
        role=cfg["role"],
        warehouse=cfg["warehouse"],
        database=cfg["database"],
        schema=cfg["schema"],
        authenticator="SNOWFLAKE_JWT",
        private_key_file=cfg["private_key_file"],
    )

    try:
        cursor = conn.cursor()

        cursor.execute(
            f"""
            SELECT
                snapshot_date,
                loan_id,
                {", ".join(FEATURES)},
                {LABEL}
            FROM FCT_EARLY_WARNING_FEATURES
            WHERE {LABEL} IS NOT NULL
            """
        )

        columns = [col[0].lower() for col in cursor.description]

        df = pd.DataFrame(
            cursor.fetchall(),
            columns=columns,
        )

        cursor.close()

    finally:
        conn.close()

    for col in FEATURES + [LABEL]:
        df[col] = df[col].map(
            lambda v: float(v) if isinstance(v, Decimal) else v
        ).astype(float)

    return df


def capture_and_precision(flags, labels):
    """
    Capture = share of all bad loans we flagged.
    Precision = share of flags that went bad.
    """

    flagged_bad = (flags & (labels == 1)).sum()

    capture = flagged_bad / (labels == 1).sum()

    precision = flagged_bad / flags.sum() if flags.sum() else 0

    return capture, precision


def main():
    df = load_features()

    # ----- 1. Split by TIME, not randomly -----

    train = df[df["snapshot_date"] <= TRAIN_END]
    test = df[df["snapshot_date"] > TRAIN_END].copy()

    print(
        f"Train: {len(train):,} rows, "
        f"{int(train[LABEL].sum())} went 30+ DPD"
    )

    print(
        f"Test: {len(test):,} rows, "
        f"{int(test[LABEL].sum())} went 30+ DPD"
    )

    # ----- 2. Champion: simple rule -----

    rule_flags = test["dpd_now"] > 0

    rule_capture, rule_precision = capture_and_precision(
        rule_flags,
        test[LABEL],
    )

    flag_volume = int(rule_flags.sum())

    # ----- 3. Challenger: logistic regression -----

    mean = train[FEATURES].mean()
    std = train[FEATURES].std()

    model = LogisticRegression(
        class_weight="balanced",
        max_iter=1000,
    )

    model.fit(
        (train[FEATURES] - mean) / std,
        train[LABEL],
    )

    test["score"] = model.predict_proba(
        (test[FEATURES] - mean) / std
    )[:, 1]

    auc = roc_auc_score(
        test[LABEL],
        test["score"],
    )

    # Flag the SAME number of loans as the rule,
    # so the comparison is fair.

    top = test.nlargest(
        flag_volume,
        "score",
    )

    model_flags = test.index.isin(top.index)

    model_capture, model_precision = capture_and_precision(
        model_flags,
        test[LABEL],
    )

    # Rank loans that are already late:
    # model vs simply sorting by DPD.

    late = test[test["dpd_now"] > 0]

    auc_model_late = roc_auc_score(
        late[LABEL],
        late["score"],
    )

    auc_dpd_late = roc_auc_score(
        late[LABEL],
        late["dpd_now"],
    )

    # ----- 4. Decision -----

    improvement = model_capture - rule_capture

    if improvement >= MIN_IMPROVEMENT:
        decision = (
            "DEPLOY CHALLENGER: "
            "the model catches clearly more bad loans."
        )
    else:
        decision = (
            "KEEP CHAMPION: the model does not clearly beat "
            "the simple rule. Use the rule in production and "
            "keep the model as a challenger."
        )

    # ----- 5. Report -----

    coefficients = "\n".join(
        f"| {name} | {coef:+.3f} |"
        for name, coef in zip(FEATURES, model.coef_[0])
    )

    report = f"""# Early Warning Model Report

## Question

Of loans that are 0 to 30 days late at month-end, which will become
more than 30 days late within the next 60 days?

## Data

- Features: as reported at month-end (frozen snapshot), so no future information leaks in.
- Outcome: actual DPD over the next 60 days (restated daily view).
- Train: month-ends up to {TRAIN_END} ({len(train):,} loan-months).
- Test: later month-ends ({len(test):,} loan-months, {int(test[LABEL].sum())} went 30+ DPD).
- Base rate in test: {test[LABEL].mean():.2%}.

## Champion vs challenger

Same number of loans flagged: {flag_volume:,}.

| Approach | Bad loans caught | Precision |
|---|---:|---:|
| Rule: already late (DPD > 0) | {rule_capture:.1%} | {rule_precision:.1%} |
| Logistic regression | {model_capture:.1%} | {model_precision:.1%} |

- Model AUC on test: {auc:.3f}
- Ranking loans that are already late: model AUC {auc_model_late:.3f}
  vs sorting by DPD {auc_dpd_late:.3f}.

## Decision

**{decision}**

## Model coefficients (standardised features)

| Feature | Coefficient |
|---|---:|
{coefficients}

## Limitations

- Synthetic data: defaulters stop paying suddenly, with no warning signs like
  partial payments. Real data usually has such signals, so results would differ.
- Only 4 features. Real early warning models also use bureau data, bank
  account inflows and field officer notes.
"""

    REPORT_FILE.write_text(
        report,
        encoding="utf-8",
    )

    print(report)
    print(f"Report saved to {REPORT_FILE}")


if __name__ == "__main__":
    main()