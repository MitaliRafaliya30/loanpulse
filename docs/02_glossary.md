# LoanPulse: Glossary

All examples use one borrower, Sunita, who took a loan of Rs 30,000
on 1 January for 12 months with a monthly installment of Rs 2,800.

## Loan basics

**Principal**
The amount the bank lends. Sunita's principal is Rs 30,000.

**Interest**
The charge the bank earns for lending money, calculated on the principal.

**Tenure**
The time given to repay the loan. Sunita's tenure is 12 months.

**Installment (EMI)**
The fixed amount the borrower pays each period. It contains a principal
part and an interest part. Sunita's installment is Rs 2,800 per month.

**Disbursement**
The day the bank gives the loan money. Sunita's disbursement date is 1 January.

**Outstanding**
The principal amount still unpaid at a point in time.

## Microfinance terms

**JLG (Joint Liability Group)**
A group of 5 to 10 borrowers who guarantee each other's loans. If one member
does not pay, the others are responsible. This replaces physical collateral.

**Field Officer**
Bank staff who visit borrowers, collect cash and record payments.

**Repayment Schedule**
The plan that lists every installment, its due date and its amount.
It is created once when the loan is disbursed.

**Collection**
An actual payment received from the borrower.

## Dates that matter

**Due Date**
The date an installment must be paid.

**Payment Date**
The date the borrower actually paid.

**Posted Date**
The date the payment was recorded in the system. It can be later than
the payment date.

**Late-arriving data**
Data that reaches the system after the day it belongs to. Example: Sunita
paid on 1 February, but it was posted on 3 February. The system must
correct her status for 1 and 2 February.

## Delinquency terms

**Overdue**
An installment that is past its due date and not fully paid.

**DPD (Days Past Due)**
Number of days since the due date of the oldest unpaid installment.
Example: Sunita has not paid the 1 February and 1 March installments.
On 15 March, the oldest unpaid one is 1 February, so DPD is 42.

**Payment allocation rule**
Every payment first clears the oldest unpaid installment.
Example: If Sunita pays Rs 2,800 on 15 March, it clears the 1 February
installment. The oldest unpaid one becomes 1 March, so DPD becomes 14.

## RBI asset classification

| DPD | Category | Meaning |
|---|---|---|
| 0 | Standard | Fully up to date |
| 1 to 30 | SMA-0 | Slightly late |
| 31 to 60 | SMA-1 | Warning stage |
| 61 to 90 | SMA-2 | Serious stress |
| More than 90 | NPA | Non-performing (bad) loan |

**SMA (Special Mention Account)**
A loan showing early signs of stress that needs close watching.

**NPA (Non-Performing Asset)**
A loan where payment is overdue for more than 90 days.

**NPA upgrade rule**
An NPA loan returns to Standard only when the borrower pays all overdue
amounts. Paying one installment is not enough.

**Write-off**
The bank removes a loan it does not expect to recover from its books.
GNPA goes down, but the money is not recovered. A falling GNPA caused
by write-offs is not real improvement.

## Portfolio metrics

**GNPA Ratio (Gross NPA Ratio)**
NPA outstanding divided by total loan outstanding.
Example: Rs 8 crore NPA out of Rs 100 crore total = 8%.

**Collection Efficiency**
Amount collected divided by amount due in a period.
Example: Rs 9.2 lakh collected out of Rs 10 lakh due = 92%.

**PAR 30 (Portfolio at Risk 30)**
Outstanding of all loans with DPD more than 30, divided by total outstanding.
It is the most common risk metric in microfinance.

**Roll Rate**
Percentage of loans that move from one DPD bucket to a worse bucket
in the next month.
Example: 1,000 loans in SMA-0 last month, 150 moved to SMA-1 this month.
Roll rate = 15%.

**Vintage Analysis**
Grouping loans by disbursement month and comparing how each batch
performs over time. It shows whether loans given in a certain month were
riskier.

## Data and reporting terms

**Month-end Snapshot**
A frozen record of every loan's status on the last day of a month.
These numbers are reported to management and regulators.

**Snapshot freeze rule**
Once a month-end snapshot is created, it never changes. Late payments
correct daily status going forward but do not change reported snapshots.

**Reconciliation**
Checking that totals from different systems match. Example: total
collections in the collections data must match the total reduction in
loan outstanding.

**PII (Personally Identifiable Information)**
Data that identifies a person, such as name, phone and Aadhaar number.
It must be masked for users who do not need it.

**DPDP Act**
India's Digital Personal Data Protection Act, which governs how
organisations collect and use personal data.