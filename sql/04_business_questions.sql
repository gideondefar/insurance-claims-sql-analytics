USE insurance_portfolio_demo;
-- Q1. Overall underwriting performance: compare H1 2025 and H1 2026.
SELECT * FROM v_portfolio_period ORDER BY period_start;

-- Q2. Which products have a higher incurred loss ratio?
SELECT period_start, product_type,
       SUM(claim_count) AS claims,
       ROUND(SUM(policy_years),2) AS earned_policy_years,
       ROUND(SUM(earned_premium_gbp),2) AS earned_premium_gbp,
       ROUND(SUM(incurred_gbp),2) AS incurred_gbp,
       ROUND(100.0*SUM(incurred_gbp)/NULLIF(SUM(earned_premium_gbp),0),2) AS incurred_loss_ratio_pct
FROM v_policy_period
GROUP BY period_start,product_type
ORDER BY period_start,incurred_loss_ratio_pct DESC;

-- Q3. Does recorded frequency differ by risk band? (Very small synthetic samples.)
SELECT period_start,risk_band,COUNT(*) AS policy_period_rows,
       ROUND(SUM(policy_years),2) AS earned_policy_years,
       SUM(claim_count) AS claims,
       ROUND(100.0*SUM(claim_count)/NULLIF(SUM(policy_years),0),2) AS claims_per_100_policy_years,
       ROUND(100.0*SUM(incurred_gbp)/NULLIF(SUM(earned_premium_gbp),0),2) AS incurred_loss_ratio_pct
FROM v_policy_period
GROUP BY period_start,risk_band
ORDER BY period_start,risk_band;

-- Q4. How does portfolio experience vary between direct and broker channels?
SELECT period_start,distribution_channel,
       COUNT(*) AS policy_period_rows,
       SUM(claim_count) AS claims,
       ROUND(SUM(earned_premium_gbp),2) AS earned_premium_gbp,
       ROUND(SUM(incurred_gbp),2) AS incurred_gbp,
       ROUND(100.0*SUM(incurred_gbp)/NULLIF(SUM(earned_premium_gbp),0),2) AS incurred_loss_ratio_pct
FROM v_policy_period
GROUP BY period_start,distribution_channel
ORDER BY period_start,distribution_channel;

-- Q5. Outstanding claims are an indicator of valuation uncertainty.
SELECT claim_status,COUNT(*) AS claim_count,
       ROUND(SUM(paid_gbp),2) AS paid_to_date_gbp,
       ROUND(SUM(case_reserve_gbp),2) AS outstanding_reserve_gbp,
       ROUND(SUM(incurred_gbp),2) AS incurred_gbp
FROM v_claim_cost
GROUP BY claim_status
ORDER BY claim_status;
