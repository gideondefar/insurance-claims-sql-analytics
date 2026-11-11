"""SQLite-compatible regression tests of MySQL-oriented portfolio SQL.
Run: python3 -m unittest discover -s tests -v
These tests do NOT replace execution in a MySQL 8.0 instance.
"""
import sqlite3
import re
import unittest
from pathlib import Path

BASE = Path(__file__).resolve().parents[1]

def sqlite_compatible(text):
    text = re.sub(r'^\s*(?:DROP DATABASE|CREATE DATABASE|USE)\b[^;]*;', '', text, flags=re.I | re.M)
    text = re.sub(r'\) ENGINE=InnoDB;', ');', text, flags=re.I)
    return text

class PortfolioTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.db = sqlite3.connect(':memory:')
        cls.db.execute('PRAGMA foreign_keys = ON')
        for filename in ['01_schema.sql','02_seed_data.sql','03_metric_views.sql']:
            sql=(BASE/'sql'/filename).read_text(encoding='utf-8')
            cls.db.executescript(sqlite_compatible(sql))

    @classmethod
    def tearDownClass(cls):
        cls.db.close()

    def scalar(self, sql):
        return self.db.execute(sql).fetchone()[0]

    def test_all_quality_assertions_pass(self):
        content=(BASE/'sql'/'05_quality_checks.sql').read_text(encoding='utf-8')
        # The second SELECT is a separate reconciliation query.
        checks=sqlite_compatible(content).split('-- Reconciliation:')[0]
        results=self.db.execute(checks).fetchall()
        self.assertEqual(len(results),11)
        self.assertTrue(all(status=='PASS' for label,status in results),results)

    def test_claim_counts_not_multiplied_by_payments(self):
        self.assertEqual(self.scalar('SELECT COUNT(*) FROM claim'),10)
        self.assertGreater(self.scalar('SELECT COUNT(*) FROM claim_payment'),10)
        self.assertEqual(self.scalar('SELECT SUM(claim_count) FROM v_policy_period'),10)

    def test_premium_and_claim_cost_reconcile(self):
        a=self.scalar('SELECT ROUND(SUM(incurred_gbp),2) FROM v_claim_cost')
        b=self.scalar('SELECT ROUND(SUM(incurred_gbp),2) FROM v_policy_period')
        self.assertEqual(a,b)
        self.assertEqual(float(a),28450.00)

    def test_policy_year_denominator(self):
        rows=self.db.execute('SELECT earned_policy_years,claims FROM v_portfolio_period ORDER BY period_start').fetchall()
        self.assertEqual(rows,[(24,4),(24,6)])

    def test_exposure_unique_constraint(self):
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO earned_exposure VALUES (999,1,'2025-01-01','2025-07-01',0.5,1)")

    def test_foreign_key_constraint(self):
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO claim_payment VALUES (9999,9999,'2025-01-01',50)")

    def test_incident_mapping_by_year(self):
        rows=self.db.execute('SELECT period_start,claims FROM v_portfolio_period ORDER BY period_start').fetchall()
        self.assertEqual(rows,[('2025-01-01',4),('2026-01-01',6)])

if __name__=='__main__':
    unittest.main()
