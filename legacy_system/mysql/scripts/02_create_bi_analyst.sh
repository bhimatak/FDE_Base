#!/bin/sh
# =====================================================================
# 02_create_bi_analyst.sh - creates the read-only "BI analyst" login.
#
# In the legacy world, dashboards and analysts reach the database with a
# user ID and password only (no API). This login can READ every table in
# legacy_fleet and can change nothing.
#
# Runs INSIDE the fde-mysql container. The user name and password come
# from .env (docker compose passes them in); they are never printed.
# Safe to re-run: it also resets the password to the value in .env.
#
# Run (from the project folder, on macOS or Windows):
#   docker exec fde-mysql sh /scripts/02_create_bi_analyst.sh
# =====================================================================
set -eu

: "${BI_ANALYST_USER:?BI_ANALYST_USER is not set in the container - check .env}"
: "${BI_ANALYST_PASSWORD:?BI_ANALYST_PASSWORD is not set in the container - check .env}"

sh /scripts/run_sql.sh <<SQL
CREATE USER IF NOT EXISTS '${BI_ANALYST_USER}'@'%' IDENTIFIED BY '${BI_ANALYST_PASSWORD}';
ALTER USER '${BI_ANALYST_USER}'@'%' IDENTIFIED BY '${BI_ANALYST_PASSWORD}';
GRANT SELECT ON legacy_fleet.* TO '${BI_ANALYST_USER}'@'%';
SELECT '${BI_ANALYST_USER} can now log in (read-only on legacy_fleet)' AS status;
SHOW GRANTS FOR '${BI_ANALYST_USER}'@'%';
SQL
