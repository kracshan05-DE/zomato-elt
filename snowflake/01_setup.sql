-- =====================================================================
-- Phase 1 · Warehouse, database, schemas, role
-- Run in Snowsight as ACCOUNTADMIN.
-- =====================================================================
USE ROLE ACCOUNTADMIN;

-- Compute: extra-small, fast auto-suspend so trial credits last.
CREATE WAREHOUSE IF NOT EXISTS ZOMATO_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND   = 60
  AUTO_RESUME    = TRUE
  INITIALLY_SUSPENDED = TRUE;

-- Database + medallion schemas.
CREATE DATABASE IF NOT EXISTS ZOMATO;
CREATE SCHEMA IF NOT EXISTS ZOMATO.RAW;        -- Bronze: COPY INTO from S3, untouched
CREATE SCHEMA IF NOT EXISTS ZOMATO.STAGING;    -- Silver: dbt cleaned/typed views
CREATE SCHEMA IF NOT EXISTS ZOMATO.MARTS;      -- Gold: dims, incremental facts, business marts
CREATE SCHEMA IF NOT EXISTS ZOMATO.SNAPSHOTS;  -- SCD2 history (dbt snapshot)
CREATE SCHEMA IF NOT EXISTS ZOMATO.AI;         -- LLM-enriched tables

-- A role dbt/Airflow will use — never run pipelines as ACCOUNTADMIN.
CREATE ROLE IF NOT EXISTS DBT_ROLE;
GRANT USAGE   ON WAREHOUSE ZOMATO_WH TO ROLE DBT_ROLE;
GRANT OPERATE ON WAREHOUSE ZOMATO_WH TO ROLE DBT_ROLE;
GRANT ALL     ON DATABASE  ZOMATO    TO ROLE DBT_ROLE;
GRANT ALL     ON ALL SCHEMAS IN DATABASE ZOMATO TO ROLE DBT_ROLE;
GRANT ALL     ON FUTURE SCHEMAS IN DATABASE ZOMATO TO ROLE DBT_ROLE;
GRANT ALL     ON FUTURE TABLES  IN DATABASE ZOMATO TO ROLE DBT_ROLE;
GRANT ALL     ON FUTURE VIEWS   IN DATABASE ZOMATO TO ROLE DBT_ROLE;

-- Service user for dbt/Airflow, authenticated by RSA key pair (no password).
-- Generate the key pair locally, then paste the public key value below:
--   openssl genrsa -out rsa_key.pem 2048
--   openssl rsa -in rsa_key.pem -pubout -out rsa_key.pub
CREATE USER IF NOT EXISTS dbt_svc_user
  DEFAULT_ROLE = DBT_ROLE
  DEFAULT_WAREHOUSE = ZOMATO_WH
  RSA_PUBLIC_KEY = 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnLGLvIRPN5Wz1IcdQ2JKemrBPJ7AVXLooZFK5H1O+rhoC+59qSWErUlm+oDAZTK0IJSzsD6evhKLOorTx1hMum89JMiPpvGiVMI+SiE1CLMJOLvdz4OFPBnin0grHfdLo/5w0eHcKWLRRUAn+R7z1K++y5qBaige2ny4aqsnHfh1Kz6fe4SViR+B0y/Q5E3osQ1tlrz9VzcS5Y2Qjp9t6+yoUQcMu+2QyeWjgOXhEEkXAO7dnRO1NM/8qRsOr5u1Tss3HcnSxn2xlW8+xQDgwoz6RPRUsS1gAgOavnBFFzswt8+C/s9cqDej3rwHFikVluYPu0o+29+932ANZFmVXwIDAQAB';

GRANT ROLE DBT_ROLE TO USER dbt_svc_user;

SELECT 'setup complete' AS status;
