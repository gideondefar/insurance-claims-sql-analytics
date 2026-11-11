USE insurance_portfolio_demo;
-- Fix a consistent claims valuation date for this portfolio snapshot.
-- Multiple payments per claim are consolidated first to PREVENT join fan-out.
DROP VIEW IF EXISTS v_portfolio_period;
DROP VIEW IF EXISTS v_policy_period;
DROP VIEW IF EXISTS v_claim_cost;

CREATE VIEW v_claim_cost AS
SELECT c.claim_id, c.policy_id, c.incident_date, c.claim_status,
       COALESCE(SUM(CASE WHEN pm.payment_date <= c.reserve_valuation_date
                         THEN pm.amount_gbp ELSE 0 END), 0) AS paid_gbp,
       c.outstanding_reserve_gbp AS case_reserve_gbp,
       COALESCE(SUM(CASE WHEN pm.payment_date <= c.reserve_valuation_date
                         THEN pm.amount_gbp ELSE 0 END), 0) + c.outstanding_reserve_gbp AS incurred_gbp
FROM claim AS c
LEFT JOIN claim_payment AS pm ON pm.claim_id = c.claim_id
GROUP BY c.claim_id, c.policy_id, c.incident_date, c.claim_status, c.outstanding_reserve_gbp, c.reserve_valuation_date;

-- One row per policy and reporting period, including zero-claim policies.
CREATE VIEW v_policy_period AS
SELECT e.exposure_id, e.policy_id, e.period_start, e.period_end,
       p.product_type, p.distribution_channel, p.risk_band,
       e.policy_years, e.earned_premium_gbp,
       COUNT(cc.claim_id) AS claim_count,
       COALESCE(SUM(cc.paid_gbp),0) AS paid_gbp,
       COALESCE(SUM(cc.case_reserve_gbp),0) AS case_reserve_gbp,
       COALESCE(SUM(cc.incurred_gbp),0) AS incurred_gbp
FROM earned_exposure AS e
JOIN policy AS p ON p.policy_id=e.policy_id
LEFT JOIN v_claim_cost AS cc ON cc.policy_id=e.policy_id
     AND cc.incident_date >= e.period_start
     AND cc.incident_date < e.period_end
GROUP BY e.exposure_id,e.policy_id,e.period_start,e.period_end,
         p.product_type,p.distribution_channel,p.risk_band,
         e.policy_years,e.earned_premium_gbp;

-- Claim frequency is annualised: claims / earned policy-years x 100.
-- Incurred loss ratio = (paid + outstanding case reserve) / earned premium.
CREATE VIEW v_portfolio_period AS
SELECT period_start,
       COUNT(DISTINCT policy_id) AS policies,
       ROUND(SUM(policy_years),2) AS earned_policy_years,
       ROUND(SUM(earned_premium_gbp),2) AS earned_premium_gbp,
       SUM(claim_count) AS claims,
       ROUND(SUM(paid_gbp),2) AS paid_gbp,
       ROUND(SUM(case_reserve_gbp),2) AS reserves_gbp,
       ROUND(SUM(incurred_gbp),2) AS incurred_gbp,
       ROUND(100.0*SUM(claim_count)/NULLIF(SUM(policy_years),0),2) AS claims_per_100_policy_years,
       ROUND(SUM(incurred_gbp)*1.0/NULLIF(SUM(claim_count),0),2) AS avg_incurred_severity_gbp,
       ROUND(100.0*SUM(incurred_gbp)/NULLIF(SUM(earned_premium_gbp),0),2) AS incurred_loss_ratio_pct
FROM v_policy_period
GROUP BY period_start;
