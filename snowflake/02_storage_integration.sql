-- =====================================================================
-- Phase 2 · Secure S3 <-> Snowflake link (Storage Integration, no keys)
-- See aws/iam/README.md for the AWS-side steps that pair with this file.
--
-- ORDER OF OPERATIONS:
--   A. In AWS IAM, create policy zomato-s3-read (aws/iam/s3-read-policy.json)
--   B. Create role snowflake-s3-role with a PLACEHOLDER trust policy
--      (aws/iam/snowflake-role-trust-policy-initial.json) and attach the policy
--   C. Run CREATE STORAGE INTEGRATION below with that role's ARN
--   D. DESC INTEGRATION -> copy STORAGE_AWS_IAM_USER_ARN + EXTERNAL_ID
--   E. Edit the IAM role's trust policy with those two real values
--      (aws/iam/snowflake-role-trust-policy-final.json is the template)
--
-- WARNING: never re-run CREATE OR REPLACE on this integration after step E —
-- it regenerates the external ID and silently breaks the trust relationship.
-- =====================================================================
USE ROLE ACCOUNTADMIN;

-- >>> EDIT THESE TWO <<<
--   <ROLE_ARN> = arn:aws:iam::<your-account-id>:role/snowflake-s3-role
--   <BUCKET>   = your bucket name
CREATE STORAGE INTEGRATION IF NOT EXISTS ZOMATO_S3_INT
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = '<ROLE_ARN>'
  STORAGE_ALLOWED_LOCATIONS = ('s3://<BUCKET>/raw/');

GRANT USAGE ON INTEGRATION ZOMATO_S3_INT TO ROLE DBT_ROLE;

-- Run this, then copy the two values into the IAM role trust policy (step E).
DESC INTEGRATION ZOMATO_S3_INT;
--   STORAGE_AWS_IAM_USER_ARN  ->  the "AWS" principal in the trust policy
--   STORAGE_AWS_EXTERNAL_ID   ->  the sts:ExternalId condition
