-- Motor and home insurance portfolio demo (fictional). MySQL 8.0+
-- DESTRUCTIVE: resets ONLY the named local demo database. Do not run on production.
DROP DATABASE IF EXISTS insurance_portfolio_demo;
CREATE DATABASE insurance_portfolio_demo CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE insurance_portfolio_demo;

CREATE TABLE customer (
  customer_id INT PRIMARY KEY,
  customer_segment VARCHAR(30) NOT NULL,
  region VARCHAR(30) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE policy (
  policy_id INT PRIMARY KEY,
  customer_id INT NOT NULL,
  product_type VARCHAR(12) NOT NULL,
  distribution_channel VARCHAR(12) NOT NULL,
  risk_band VARCHAR(10) NOT NULL,
  policy_start DATE NOT NULL,
  policy_end DATE NOT NULL,
  CONSTRAINT fk_policy_customer FOREIGN KEY(customer_id) REFERENCES customer(customer_id) ON DELETE RESTRICT,
  CONSTRAINT chk_policy_dates CHECK (policy_end > policy_start),
  CONSTRAINT chk_product CHECK (product_type IN ('Motor','Home')),
  CONSTRAINT chk_risk CHECK (risk_band IN ('Low','Medium','High'))
) ENGINE=InnoDB;

CREATE TABLE earned_exposure (
  exposure_id INT PRIMARY KEY,
  policy_id INT NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  policy_years DECIMAL(8,4) NOT NULL,
  earned_premium_gbp DECIMAL(12,2) NOT NULL,
  CONSTRAINT fk_exposure_policy FOREIGN KEY(policy_id) REFERENCES policy(policy_id) ON DELETE RESTRICT,
  CONSTRAINT uq_exposure UNIQUE(policy_id, period_start),
  CONSTRAINT chk_exposure_dates CHECK (period_end > period_start),
  CONSTRAINT chk_exposure_positive CHECK (policy_years > 0 AND policy_years <= 1),
  CONSTRAINT chk_premium_nonnegative CHECK (earned_premium_gbp >= 0)
) ENGINE=InnoDB;

CREATE TABLE claim (
  claim_id INT PRIMARY KEY,
  policy_id INT NOT NULL,
  incident_date DATE NOT NULL,
  reported_date DATE NOT NULL,
  claim_status VARCHAR(10) NOT NULL,
  outstanding_reserve_gbp DECIMAL(12,2) NOT NULL,
  reserve_valuation_date DATE NOT NULL,
  CONSTRAINT fk_claim_policy FOREIGN KEY(policy_id) REFERENCES policy(policy_id) ON DELETE RESTRICT,
  CONSTRAINT chk_claim_dates CHECK (reported_date >= incident_date),
  CONSTRAINT chk_claim_status CHECK (claim_status IN ('Open','Closed')),
  CONSTRAINT chk_claim_reserve CHECK (outstanding_reserve_gbp >= 0),
  CONSTRAINT chk_closed_reserve CHECK (claim_status <> 'Closed' OR outstanding_reserve_gbp = 0)
) ENGINE=InnoDB;

CREATE TABLE claim_payment (
  payment_id INT PRIMARY KEY,
  claim_id INT NOT NULL,
  payment_date DATE NOT NULL,
  amount_gbp DECIMAL(12,2) NOT NULL,
  CONSTRAINT fk_payment_claim FOREIGN KEY(claim_id) REFERENCES claim(claim_id) ON DELETE RESTRICT,
  CONSTRAINT chk_payment_amount CHECK (amount_gbp > 0)
) ENGINE=InnoDB;

CREATE INDEX idx_claim_policy_date ON claim(policy_id, incident_date);
CREATE INDEX idx_payment_claim ON claim_payment(claim_id);
CREATE INDEX idx_exposure_period ON earned_exposure(period_start,period_end);
