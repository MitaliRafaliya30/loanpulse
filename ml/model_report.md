# Early Warning Model Report

## Question

Of loans that are 0 to 30 days late at month-end, which will become
more than 30 days late within the next 60 days?

## Data

- Features: as reported at month-end (frozen snapshot), so no future information leaks in.
- Outcome: actual DPD over the next 60 days (restated daily view).
- Train: month-ends up to 2025-12-31 (24,983 loan-months).
- Test: later month-ends (17,759 loan-months, 505 went 30+ DPD).
- Base rate in test: 2.84%.

## Champion vs challenger

Same number of loans flagged: 1,022.

| Approach | Bad loans caught | Precision |
|---|---:|---:|
| Rule: already late (DPD > 0) | 50.7% | 25.0% |
| Logistic regression | 49.3% | 24.4% |

- Model AUC on test: 0.818
- Ranking loans that are already late: model AUC 0.782
  vs sorting by DPD 0.803.

## Decision

**KEEP CHAMPION: the model does not clearly beat the simple rule. Use the rule in production and keep the model as a challenger.**

## Model coefficients (standardised features)

| Feature | Coefficient |
|---|---:|
| dpd_now | +0.678 |
| late_months_6m | +0.259 |
| branch_gnpa_pct | +0.180 |
| group_late_share | +0.167 |

## Limitations

- Synthetic data: defaulters stop paying suddenly, with no warning signs like
  partial payments. Real data usually has such signals, so results would differ.
- Only 4 features. Real early warning models also use bureau data, bank
  account inflows and field officer notes.
