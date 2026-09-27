-- =====================================================================
-- Phase 3 · File format + external stage
-- =====================================================================
USE ROLE ACCOUNTADMIN;
USE DATABASE ZOMATO;
USE SCHEMA RAW;

CREATE FILE FORMAT IF NOT EXISTS ZOMATO.RAW.CSV_FMT
  TYPE = CSV
  COMPRESSION = AUTO
  FIELD_DELIMITER = ','
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  SKIP_HEADER = 1
  EMPTY_FIELD_AS_NULL = TRUE
  NULL_IF = ('', '\\N', 'null', 'NULL')
  TRIM_SPACE = FALSE
  ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;

-- >>> EDIT <BUCKET> <<<
CREATE STAGE IF NOT EXISTS ZOMATO.RAW.ZOMATO_RAW_STAGE
  STORAGE_INTEGRATION = ZOMATO_S3_INT
  URL = 's3://<BUCKET>/raw/'
  FILE_FORMAT = ZOMATO.RAW.CSV_FMT;

-- Confirm Snowflake can see your files.
LIST @ZOMATO.RAW.ZOMATO_RAW_STAGE;
