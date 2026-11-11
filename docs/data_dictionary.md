# Data dictionary and metric definitions

All records are **synthetic**. This is not real customer, policy or claim information.

| Table | Grain | Key fields | Why it exists |
|---|---|---|---|
| `customer` | One fictional customer | `customer_id`, segment, region | Customer dimension |
| `policy` | One insurance contract | `policy_id`, `customer_id`, product, channel, risk band | Underwriting segmentation |
| `earned_exposure` | One policy × reporting period | `exposure_id`, `policy_id`, `period_start`, `period_end`, `policy_years`, earned premium | Correct denominator for claims frequency and loss ratio |
| `claim` | One reported claim | `claim_id`, `policy_id`, incident and report dates, status, reserve | Claim frequency and outstanding liability |
| `claim_payment` | One claim payment transaction | `payment_id`, `claim_id`, amount, payment date | Paid losses; multiple payments possible per claim |

## Metrics

- **Claim frequency per 100 policy-years:** `100 × distinct claims in the incident period ÷ earned policy-years`. It is *not* claims divided by policy count.
- **Average incurred severity:** `sum(paid + outstanding case reserve) ÷ distinct claims` for that period. A zero-claim segment yields NULL, not a misleading zero.
- **Incurred loss ratio:** `100 × incurred cost ÷ earned premium`, where incurred cost includes paid payments through the valuation date plus outstanding case reserves.
- **Earned premium:** supplied synthetic premium attributable to each six-month reporting period, not total annual written premium.

**Reporting windows:** H1 2025 and H1 2026, `[1 January, 1 July)`. Claims are assigned by **incident date**, not payment date. Valuation date is **31 August 2026** for all sample claim reserves. No payments occur after this date.

**Key modelling precaution:** A claim can have multiple payments. Payments are aggregated to one row per claim in `v_claim_cost` *before* calculating period-level KPIs. This prevents accidentally counting a claim more than once or multiplying policy premiums by the number of payments.

**Limitations:** There are only 48 policies. These illustrative numbers cannot estimate real motor/home insurance pricing, causal effects or actual risk levels. Reserves are manually supplied synthetic valuations, not actuarial best estimates, IBNR or developed ultimate losses; expenses, reinsurance, inflation adjustments and claim development are excluded. The two reporting periods are not proof of general market trends.
