# Portfolio commentary: June 2026

### Headline
June 2026 credit quality weakened as GNPA rose to 5.18% and collection efficiency fell to 93.22%.

### What changed
- GNPA increased 0.91 points to 5.18%, PAR30 rose 1.17 points to 7.27%, and collection efficiency fell 4.28 points to 93.22%.
- Roll rates show 91.43% of SMA1 loans moved to SMA2 and 90.0% of SMA2 loans became NPAs.
- The portfolio stands at 9.19 crore outstanding across 4468 active loans.

### Where to act
- Gaya Town (Gaya) has the highest GNPA at 10.53% and lowest collection efficiency at 86.03%.
- Review data quality after 28 loans were reclassified in the previous month and 328 total reclassifications.

<!-- AUDIT -->

---

- Generated: 2026-10-11 20:34
- Written by: openrouter/free
- Number check: PASSED on attempt 1

## Facts used

```json
{
  "month": "June 2026",
  "portfolio": {
    "outstanding_crore": 9.19,
    "active_loans": 4468,
    "gnpa_pct": 5.18,
    "gnpa_change_points": 0.91,
    "par30_pct": 7.27,
    "par30_change_points": 1.17,
    "collection_efficiency_pct": 93.22,
    "collection_efficiency_change_points": -4.28
  },
  "most_stressed_branches": [
    {
      "branch": "Gaya Town (Gaya)",
      "gnpa_pct": 10.53,
      "collection_efficiency_pct": 86.03
    },
    {
      "branch": "Muzaffarpur Market (Muzaffarpur)",
      "gnpa_pct": 7.62,
      "collection_efficiency_pct": 91.53
    },
    {
      "branch": "Varanasi Main (Varanasi)",
      "gnpa_pct": 7.36,
      "collection_efficiency_pct": 88.97
    }
  ],
  "roll_rates_pct": {
    "standard_to_sma0": 5.23,
    "sma0_cured_to_standard": 62.06,
    "sma1_to_sma2": 91.43,
    "sma2_to_npa": 90.0
  },
  "data_quality": {
    "previous_month_loans_reclassified_after_reporting": 28,
    "total_loans_reclassified_after_reporting": 328
  }
}
```
