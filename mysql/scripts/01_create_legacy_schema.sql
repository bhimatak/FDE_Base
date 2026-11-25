-- =====================================================================
-- 01_create_legacy_schema.sql
-- Step 1 (legacy system): creates the legacy fleet database and its raw
-- history table.
--
-- The column names are short and cryptic on purpose: this is how an old
-- enterprise system stores its data. The CSV column each one holds is
-- noted on the right; the full mapping is in Appendix A of
-- docs/01_Legacy_System_Setup_Guide_macOS.md (or _Windows.md).
--
-- All 26 CSV columns are kept. Three system columns are added:
-- REC_ID (row number), SYS_INGEST_FLAG and SYS_LOAD_TS.
--
-- Safe to re-run: nothing is dropped and no data is changed.
-- Run (from the project folder, on macOS or Windows):
--   docker exec fde-mysql sh /scripts/run_sql.sh /scripts/01_create_legacy_schema.sql
-- =====================================================================

CREATE DATABASE IF NOT EXISTS legacy_fleet
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS legacy_fleet.TBL_SC_FLEET_HIST_RAW (
  REC_ID           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,  -- system row number (not a shipment id)
  TS_UTC           DATETIME     NOT NULL,                    -- timestamp
  V_LAT            DOUBLE       NULL,                        -- vehicle_gps_latitude
  V_LON            DOUBLE       NULL,                        -- vehicle_gps_longitude
  FUEL_CONS_RT     DOUBLE       NULL,                        -- fuel_consumption_rate
  ETA_VAR_HRS      DOUBLE       NULL,                        -- eta_variation_hours
  TRF_CNG_LVL      DOUBLE       NULL,                        -- traffic_congestion_level
  WH_INV_LVL       DOUBLE       NULL,                        -- warehouse_inventory_level
  LD_ULD_TM        DOUBLE       NULL,                        -- loading_unloading_time
  HDL_EQP_AVL      DOUBLE       NULL,                        -- handling_equipment_availability
  ORD_FUL_STS      DOUBLE       NULL,                        -- order_fulfillment_status
  WX_SEV_IDX       DOUBLE       NULL,                        -- weather_condition_severity
  PRT_CNG_LVL      DOUBLE       NULL,                        -- port_congestion_level
  SHP_CST_AMT      DOUBLE       NULL,                        -- shipping_costs
  SUP_REL_SCR      DOUBLE       NULL,                        -- supplier_reliability_score
  LEAD_TM_DAYS     DOUBLE       NULL,                        -- lead_time_days
  HIST_DMD_QTY     DOUBLE       NULL,                        -- historical_demand
  IOT_TEMP_VAL_C   DOUBLE       NULL,                        -- iot_temperature
  CGO_COND_CD      DOUBLE       NULL,                        -- cargo_condition_status
  RT_RSK_IDX       DOUBLE       NULL,                        -- route_risk_level
  CUST_CLR_TM      DOUBLE       NULL,                        -- customs_clearance_time
  DRV_BHV_SCR      DOUBLE       NULL,                        -- driver_behavior_score
  DRV_FTG_SCR      DOUBLE       NULL,                        -- fatigue_monitoring_score
  DSRP_LKH_SCR     DOUBLE       NULL,                        -- disruption_likelihood_score
  DELAY_PROB_DEC   DOUBLE       NULL,                        -- delay_probability
  RISK_CLS_TXT     VARCHAR(50)  NULL,                        -- risk_classification
  DLV_TM_DEV       DOUBLE       NULL,                        -- delivery_time_deviation
  SYS_INGEST_FLAG  CHAR(1)      NOT NULL DEFAULT 'Y',        -- system: row came from the batch load
  SYS_LOAD_TS      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,  -- system: when the row was loaded (UTC)
  PRIMARY KEY (REC_ID),
  KEY IX_FLEET_HIST_TS (TS_UTC)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;

SELECT 'legacy_fleet.TBL_SC_FLEET_HIST_RAW is ready' AS status;

SELECT COUNT(*) AS columns_in_table
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'legacy_fleet'
  AND TABLE_NAME   = 'TBL_SC_FLEET_HIST_RAW';
