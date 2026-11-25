-- =====================================================================
-- 04_verify_load.sql
-- Step 1 (legacy system): checks that the CSV landed in the legacy table
-- completely and in the right columns.
--
-- The expected values were computed directly from the CSV file
-- (data/raw/dynamic_supply_chain_logistics_dataset.csv), not from MySQL.
-- The three checksums prove that the first, a middle and the last numeric
-- columns were loaded into the right place with full precision.
--
-- Read-only: it changes nothing. Safe to run any time.
-- Run (from the project folder, on macOS or Windows):
--   docker exec fde-mysql sh /scripts/run_sql.sh /scripts/04_verify_load.sql
-- =====================================================================

USE legacy_fleet;

-- ---------- What is in the table ------------------------------------
SELECT YEAR(TS_UTC) AS reading_year,
       COUNT(*)     AS readings
FROM TBL_SC_FLEET_HIST_RAW
GROUP BY YEAR(TS_UTC)
ORDER BY reading_year;

SELECT RISK_CLS_TXT AS risk_class,
       COUNT(*)     AS readings
FROM TBL_SC_FLEET_HIST_RAW
GROUP BY RISK_CLS_TXT
ORDER BY readings DESC;

SELECT ROUND(MIN(IOT_TEMP_VAL_C), 2)              AS min_temp_c,
       ROUND(MAX(IOT_TEMP_VAL_C), 2)              AS max_temp_c,
       SUM(IOT_TEMP_VAL_C < 0)                    AS below_0c,
       SUM(IOT_TEMP_VAL_C BETWEEN 0 AND 4)        AS from_0_to_4c,
       SUM(IOT_TEMP_VAL_C > 4)                    AS above_4c
FROM TBL_SC_FLEET_HIST_RAW;

-- ---------- PASS / FAIL checklist -----------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_load_checks;

CREATE TEMPORARY TABLE tmp_load_checks AS
SELECT check_no, check_name, expected, actual,
       IF(expected = actual, 'PASS', 'FAIL') AS result
FROM (
  SELECT 1 AS check_no, 'Rows loaded' AS check_name,
         '32065' AS expected, CAST(COUNT(*) AS CHAR) AS actual
  FROM TBL_SC_FLEET_HIST_RAW
  UNION ALL
  SELECT 2, 'Distinct hourly timestamps',
         '32065', CAST(COUNT(DISTINCT TS_UTC) AS CHAR)
  FROM TBL_SC_FLEET_HIST_RAW
  UNION ALL
  SELECT 3, 'First reading',
         '2021-01-01 00:00:00', CAST(MIN(TS_UTC) AS CHAR)
  FROM TBL_SC_FLEET_HIST_RAW
  UNION ALL
  SELECT 4, 'Last reading',
         '2024-08-29 00:00:00', CAST(MAX(TS_UTC) AS CHAR)
  FROM TBL_SC_FLEET_HIST_RAW
  UNION ALL
  SELECT 5, 'High Risk rows',
         '23944', CAST(SUM(RISK_CLS_TXT = 'High Risk') AS CHAR)
  FROM TBL_SC_FLEET_HIST_RAW
  UNION ALL
  SELECT 6, 'Moderate Risk rows',
         '5011', CAST(SUM(RISK_CLS_TXT = 'Moderate Risk') AS CHAR)
  FROM TBL_SC_FLEET_HIST_RAW
  UNION ALL
  SELECT 7, 'Low Risk rows',
         '3110', CAST(SUM(RISK_CLS_TXT = 'Low Risk') AS CHAR)
  FROM TBL_SC_FLEET_HIST_RAW
  UNION ALL
  SELECT 8, 'Rows with a missing value',
         '0', CAST(SUM(
              TS_UTC IS NULL OR V_LAT IS NULL OR V_LON IS NULL
           OR FUEL_CONS_RT IS NULL OR ETA_VAR_HRS IS NULL OR TRF_CNG_LVL IS NULL
           OR WH_INV_LVL IS NULL OR LD_ULD_TM IS NULL OR HDL_EQP_AVL IS NULL
           OR ORD_FUL_STS IS NULL OR WX_SEV_IDX IS NULL OR PRT_CNG_LVL IS NULL
           OR SHP_CST_AMT IS NULL OR SUP_REL_SCR IS NULL OR LEAD_TM_DAYS IS NULL
           OR HIST_DMD_QTY IS NULL OR IOT_TEMP_VAL_C IS NULL OR CGO_COND_CD IS NULL
           OR RT_RSK_IDX IS NULL OR CUST_CLR_TM IS NULL OR DRV_BHV_SCR IS NULL
           OR DRV_FTG_SCR IS NULL OR DSRP_LKH_SCR IS NULL OR DELAY_PROB_DEC IS NULL
           OR RISK_CLS_TXT IS NULL OR DLV_TM_DEV IS NULL) AS CHAR)
  FROM TBL_SC_FLEET_HIST_RAW
  UNION ALL
  SELECT 9, 'Columns in table (26 data + 3 system)',
         '29', CAST(COUNT(*) AS CHAR)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = 'legacy_fleet' AND TABLE_NAME = 'TBL_SC_FLEET_HIST_RAW'
  UNION ALL
  SELECT 10, 'Checksum SUM(FUEL_CONS_RT)  - column 4',
         '256896.28', CAST(CAST(SUM(FUEL_CONS_RT) AS DECIMAL(20,2)) AS CHAR)
  FROM TBL_SC_FLEET_HIST_RAW
  UNION ALL
  SELECT 11, 'Checksum SUM(IOT_TEMP_VAL_C) - column 17',
         '1436.24', CAST(CAST(SUM(IOT_TEMP_VAL_C) AS DECIMAL(20,2)) AS CHAR)
  FROM TBL_SC_FLEET_HIST_RAW
  UNION ALL
  SELECT 12, 'Checksum SUM(DLV_TM_DEV)    - column 26',
         '166021.29', CAST(CAST(SUM(DLV_TM_DEV) AS DECIMAL(20,2)) AS CHAR)
  FROM TBL_SC_FLEET_HIST_RAW
  UNION ALL
  SELECT 13, 'Rows with SYS_INGEST_FLAG = Y',
         '32065', CAST(SUM(SYS_INGEST_FLAG = 'Y') AS CHAR)
  FROM TBL_SC_FLEET_HIST_RAW
) AS checks;

SELECT check_no AS `#`, check_name, expected, actual, result
FROM tmp_load_checks
ORDER BY check_no;

SELECT IF(SUM(result = 'FAIL') = 0,
          CONCAT('ALL ', COUNT(*), ' CHECKS PASSED - the legacy system is ready'),
          CONCAT(SUM(result = 'FAIL'), ' CHECK(S) FAILED - see the table above'))
       AS verdict
FROM tmp_load_checks;

DROP TEMPORARY TABLE IF EXISTS tmp_load_checks;
