-- =====================================================================
-- 03_load_legacy_data.sql
-- Step 1 (legacy system): loads the raw CSV into
-- legacy_fleet.TBL_SC_FLEET_HIST_RAW.
--
-- Source file : data/raw/dynamic_supply_chain_logistics_dataset.csv
--               (mounted read-only into the container as /import/raw)
-- Rows        : every row of the CSV (32,065), all 26 columns
-- Re-runnable : yes. The table is emptied first and then fully reloaded,
--               so running it twice never creates duplicates.
--
-- Run (from the project folder, on macOS or Windows):
--   docker exec fde-mysql sh /scripts/run_sql.sh /scripts/03_load_legacy_data.sql
-- =====================================================================

USE legacy_fleet;

SELECT '1/3  Emptying legacy_fleet.TBL_SC_FLEET_HIST_RAW' AS status;
TRUNCATE TABLE TBL_SC_FLEET_HIST_RAW;

SELECT '2/3  Loading /import/raw/dynamic_supply_chain_logistics_dataset.csv' AS status;

-- The column list below follows the order of the CSV header exactly.
-- The timestamp is converted from text to DATETIME, and a trailing
-- carriage return is removed from the last column in case the file was
-- ever saved with Windows line endings.
LOAD DATA LOCAL INFILE '/import/raw/dynamic_supply_chain_logistics_dataset.csv'
INTO TABLE TBL_SC_FLEET_HIST_RAW
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
  @csv_timestamp,     -- timestamp
  V_LAT,              -- vehicle_gps_latitude
  V_LON,              -- vehicle_gps_longitude
  FUEL_CONS_RT,       -- fuel_consumption_rate
  ETA_VAR_HRS,        -- eta_variation_hours
  TRF_CNG_LVL,        -- traffic_congestion_level
  WH_INV_LVL,         -- warehouse_inventory_level
  LD_ULD_TM,          -- loading_unloading_time
  HDL_EQP_AVL,        -- handling_equipment_availability
  ORD_FUL_STS,        -- order_fulfillment_status
  WX_SEV_IDX,         -- weather_condition_severity
  PRT_CNG_LVL,        -- port_congestion_level
  SHP_CST_AMT,        -- shipping_costs
  SUP_REL_SCR,        -- supplier_reliability_score
  LEAD_TM_DAYS,       -- lead_time_days
  HIST_DMD_QTY,       -- historical_demand
  IOT_TEMP_VAL_C,     -- iot_temperature
  CGO_COND_CD,        -- cargo_condition_status
  RT_RSK_IDX,         -- route_risk_level
  CUST_CLR_TM,        -- customs_clearance_time
  DRV_BHV_SCR,        -- driver_behavior_score
  DRV_FTG_SCR,        -- fatigue_monitoring_score
  DSRP_LKH_SCR,       -- disruption_likelihood_score
  DELAY_PROB_DEC,     -- delay_probability
  RISK_CLS_TXT,       -- risk_classification
  @csv_delivery_dev   -- delivery_time_deviation
)
SET
  TS_UTC          = STR_TO_DATE(@csv_timestamp, '%Y-%m-%d %H:%i:%s'),
  DLV_TM_DEV      = NULLIF(TRIM(TRAILING '\r' FROM @csv_delivery_dev), ''),
  SYS_INGEST_FLAG = 'Y';

-- Any value MySQL could not store cleanly is listed here (expected: none),
-- followed by the number of such warnings (expected: 0).
SHOW WARNINGS LIMIT 5;
SELECT @@warning_count AS load_warnings;

SELECT '3/3  Load finished' AS status,
       COUNT(*)            AS rows_loaded,
       MIN(TS_UTC)         AS first_reading,
       MAX(TS_UTC)         AS last_reading
FROM TBL_SC_FLEET_HIST_RAW;
