# LoanPulse: Problem Statement

## Business context
A small finance bank gives small loans to low-income borrowers in rural and
semi-urban areas. Most loans are given through Joint Liability Groups (JLG),
where 5 to 10 borrowers guarantee each other instead of giving collateral.
Borrowers repay in monthly installments. Field officers collect cash from
borrowers and record payments in a collections app.

## The problem
1. **Data is scattered.** Loan details, repayment schedules and collections
   sit in separate systems.
2. **Payments are recorded late.** A field officer may record a payment
   1 to 3 days after the borrower actually paid. Systems that only look at
   recorded payments wrongly show on-time borrowers as overdue.
3. **Month-end numbers are not stable.** When month-end reports are re-run
   later, late entries change the numbers. Reported figures cannot be
   reproduced during audit.
4. **Stress is detected too late.** By the time reports show a problem,
   borrowers are already 60 to 90 days overdue and recovery is hard.
5. **Customer data is exposed.** Analysts can see names, phone numbers and
   Aadhaar numbers they do not need.

## What LoanPulse does
1. Loads loan, schedule, collection and branch data daily into one warehouse.
2. Calculates correct Days Past Due (DPD) and RBI asset classification
   (Standard, SMA-0, SMA-1, SMA-2, NPA) for every loan, every day,
   even when payments arrive late.
3. Freezes month-end portfolio snapshots so reported numbers never change.
4. Reconciles loan and collection totals and runs data quality checks.
5. Masks customer personal data based on user role.
6. Shows portfolio health on a dashboard.
7. Flags currently healthy loans that are likely to become overdue soon.

## Key metrics
- GNPA ratio
- Collection efficiency
- PAR 30 (Portfolio at Risk 30)
- Roll rates between DPD buckets
- Vintage delinquency

## Scope
- Product: microfinance JLG loans only
- Repayment frequency: monthly (real microfinance is often weekly or
  fortnightly; monthly is used to keep the project simple)
- Data: synthetic, generated with realistic patterns
- Scale: 10 branches, about 5,000 customers, about 5,000 loans, 18 months

## Out of scope
- Other products (MSME, housing loans)
- Interest accrual and income recognition
- Restructured loans
- Real-time streaming

## Success criteria
- DPD is correct after late payments are posted
- Re-running a past month-end report gives exactly the same numbers
- Loan and collection totals reconcile with zero unexplained difference
- Analyst role cannot see unmasked personal data
- Full daily pipeline runs end to end with one trigger