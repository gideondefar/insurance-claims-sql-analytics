USE insurance_portfolio_demo;
-- Quality-control report. PASS means the check returned its expected synthetic-demo value.
SELECT '40 fictional customers' AS check_name,
       CASE WHEN (SELECT COUNT(*) FROM customer)=40 THEN 'PASS' ELSE 'FAIL' END AS result
UNION ALL SELECT '48 policies',CASE WHEN (SELECT COUNT(*) FROM policy)=48 THEN 'PASS' ELSE 'FAIL' END
UNION ALL SELECT '96 policy-period exposures',CASE WHEN (SELECT COUNT(*) FROM earned_exposure)=96 THEN 'PASS' ELSE 'FAIL' END
UNION ALL SELECT '10 distinct claims',CASE WHEN (SELECT COUNT(DISTINCT claim_id) FROM claim)=10 THEN 'PASS' ELSE 'FAIL' END
UNION ALL SELECT 'Two reporting periods',CASE WHEN (SELECT COUNT(*) FROM v_portfolio_period)=2 THEN 'PASS' ELSE 'FAIL' END
UNION ALL SELECT 'Exactly 24 earned policy-years in each H1',
    CASE WHEN (SELECT COUNT(*) FROM v_portfolio_period WHERE earned_policy_years=24)=2 THEN 'PASS' ELSE 'FAIL' END
UNION ALL SELECT 'Claims allocated once across reporting periods',
    CASE WHEN (SELECT SUM(claim_count) FROM v_policy_period)=10 THEN 'PASS' ELSE 'FAIL' END
UNION ALL SELECT 'No closed claim has outstanding reserve',
    CASE WHEN (SELECT COUNT(*) FROM claim WHERE claim_status='Closed' AND outstanding_reserve_gbp<>0)=0 THEN 'PASS' ELSE 'FAIL' END
UNION ALL SELECT 'No claim precedes its policy start or follows end',
    CASE WHEN (SELECT COUNT(*) FROM claim c JOIN policy p ON c.policy_id=p.policy_id
      WHERE c.incident_date<p.policy_start OR c.incident_date>p.policy_end)=0 THEN 'PASS' ELSE 'FAIL' END
UNION ALL SELECT 'No claim outside recorded exposure window',
    CASE WHEN (SELECT COUNT(*) FROM claim c WHERE NOT EXISTS
      (SELECT 1 FROM earned_exposure e WHERE e.policy_id=c.policy_id
       AND c.incident_date>=e.period_start AND c.incident_date<e.period_end))=0 THEN 'PASS' ELSE 'FAIL' END
UNION ALL SELECT 'No payments after reserve valuation date',
    CASE WHEN (SELECT COUNT(*) FROM claim_payment cp JOIN claim c ON c.claim_id=cp.claim_id
       WHERE cp.payment_date>c.reserve_valuation_date)=0 THEN 'PASS' ELSE 'FAIL' END;

-- Reconciliation: naive claim-to-payment joins multiply rows; compare carefully.
SELECT (SELECT COUNT(*) FROM claim) AS distinct_claims,
       (SELECT COUNT(*) FROM claim_payment) AS payment_transactions,
       (SELECT SUM(claim_count) FROM v_policy_period) AS claims_counted_in_kpis,
       (SELECT ROUND(SUM(incurred_gbp),2) FROM v_claim_cost) AS incurred_in_claim_view,
       (SELECT ROUND(SUM(incurred_gbp),2) FROM v_policy_period) AS incurred_in_policy_view;
