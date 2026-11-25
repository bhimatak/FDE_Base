"""
Legacy BI Dashboard - Cold-Chain Fleet (Step 2 of the FDE_PB_Sol project)

A deliberately simple Streamlit app that behaves like an OLD BI dashboard:
  * you log in with a user ID and password (the read-only bi_analyst login)
  * it reads the raw legacy table with its cryptic column names
  * it shows fixed KPIs, charts, a map and filter-based reports
  * every page can show the exact SQL it sent to MySQL ("back end" panel)

What it does NOT do (on purpose, because the legacy system cannot):
  no plain-English questions, no live weather, no company SOPs, no audit trail.

Run from the project folder (see docs/02_Legacy_BI_Dashboard_Guide.md):
  Windows: .\\venv_legacy\\Scripts\\python.exe -m streamlit run legacy_system/bi_dashboard/app.py --server.port 8502 --server.headless true
  macOS:   ./venv_legacy/bin/python -m streamlit run legacy_system/bi_dashboard/app.py --server.port 8502 --server.headless true
"""
import os
import time
from datetime import date, timedelta
from pathlib import Path

import pandas as pd
import streamlit as st
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL

# ---------------------------------------------------------------------------
# 1. Settings (read from the project-root .env created in Step 1)
# ---------------------------------------------------------------------------
PROJECT_ROOT = Path(__file__).resolve().parents[2]
load_dotenv(PROJECT_ROOT / ".env")

DB_HOST = os.getenv("MYSQL_HOST", "127.0.0.1")
DB_PORT = int(os.getenv("MYSQL_PORT", "3306"))
DB_NAME = os.getenv("LEGACY_DB", "legacy_fleet")
DEFAULT_USER = os.getenv("BI_ANALYST_USER", "bi_analyst")
TABLE = "TBL_SC_FLEET_HIST_RAW"

# Cryptic legacy column  ->  label shown on the dashboard
LABELS = {
    "TS_UTC": "Reading time (UTC)",
    "V_LAT": "Latitude",
    "V_LON": "Longitude",
    "IOT_TEMP_VAL_C": "Cargo temperature (°C)",
    "CGO_COND_CD": "Cargo condition code",
    "RISK_CLS_TXT": "Risk class",
    "DELAY_PROB_DEC": "Delay probability",
    "PRT_CNG_LVL": "Port congestion (0-10)",
    "RT_RSK_IDX": "Route risk (0-10)",
    "FUEL_CONS_RT": "Fuel consumption rate",
    "ETA_VAR_HRS": "ETA variation (hours)",
    "TRF_CNG_LVL": "Traffic congestion (0-10)",
    "DRV_BHV_SCR": "Driver behaviour score (0-1)",
    "DRV_FTG_SCR": "Driver fatigue score (0-1)",
    "WX_SEV_IDX": "Weather severity, stored (0-1)",
    "DLV_TM_DEV": "Delivery time deviation",
    "SHP_CST_AMT": "Shipping cost",
}
# The 9 core columns (the same 9 the AI system will use later)
CORE_COLUMNS = ["TS_UTC", "V_LAT", "V_LON", "IOT_TEMP_VAL_C", "CGO_COND_CD",
                "RISK_CLS_TXT", "DELAY_PROB_DEC", "PRT_CNG_LVL", "RT_RSK_IDX"]
# Extra columns used on the Operations page
OPS_COLUMNS = ["FUEL_CONS_RT", "ETA_VAR_HRS", "TRF_CNG_LVL", "DRV_BHV_SCR",
               "DRV_FTG_SCR", "WX_SEV_IDX", "DLV_TM_DEV", "SHP_CST_AMT"]

RISK_CLASSES = ["All", "High Risk", "Moderate Risk", "Low Risk"]
RISK_COLOURS = {"High Risk": "#d62728", "Moderate Risk": "#ff7f0e", "Low Risk": "#2ca02c"}
YEARS = ["All", 2021, 2022, 2023, 2024]
MONTHS = ["All"] + list(range(1, 13))
FIRST_DAY, LAST_DAY = date(2021, 1, 1), date(2024, 8, 29)

st.set_page_config(page_title="Legacy BI Dashboard", page_icon="🚚", layout="wide")

# Every query of the current page is recorded here and shown in the back-end
# panel. Streamlit re-runs this whole script on each click, so it starts empty.
QUERY_LOG = []


# ---------------------------------------------------------------------------
# 2. Database helpers
# ---------------------------------------------------------------------------
def connect(user, password):
    """Log in to MySQL with a user ID and password (the only way in)."""
    url = URL.create("mysql+pymysql", username=user, password=password,
                     host=DB_HOST, port=DB_PORT, database=DB_NAME)
    engine = create_engine(url, pool_pre_ping=True)
    with engine.connect() as conn:            # fails here if the password is wrong
        conn.execute(text("SELECT 1"))
    return engine


def sql_for_display(sql, params):
    """Put the parameter values into the SQL text so it reads like what MySQL ran."""
    shown = sql
    for name in sorted(params, key=len, reverse=True):
        value = params[name]
        shown = shown.replace(f":{name}", f"'{value}'" if isinstance(value, str) else str(value))
    return shown.strip()


def run_query(purpose, sql, params=None):
    """Run one SELECT on the legacy database and record it for the back-end panel."""
    params = params or {}
    started = time.perf_counter()
    with st.session_state.engine.connect() as conn:
        result = conn.execute(text(sql), params)
        df = pd.DataFrame(result.fetchall(), columns=list(result.keys()))
    QUERY_LOG.append({"purpose": purpose, "sql": sql_for_display(sql, params),
                      "rows": len(df), "ms": round((time.perf_counter() - started) * 1000)})
    return df


def where(conditions):
    return ("WHERE " + "\n  AND ".join(conditions)) if conditions else ""


def show_table(df):
    """Show a result table with readable column names (the database keeps cryptic ones)."""
    st.dataframe(df.rename(columns=LABELS), hide_index=True)


def backend_panel():
    """The 'what happened at the back end' panel at the bottom of every page."""
    with st.expander("🔧 What happened at the back end", expanded=st.session_state.show_backend):
        st.markdown(f"**Login:** `{st.session_state.user}` (read-only) · **Server:** "
                    f"`{DB_HOST}:{DB_PORT}` · **Database:** `{DB_NAME}` · **Table:** `{TABLE}`")
        for i, q in enumerate(QUERY_LOG, start=1):
            st.markdown(f"**Query {i}: {q['purpose']}** · {q['rows']} row(s) · {q['ms']} ms")
            st.code(q["sql"], language="sql")
        all_sql = " ".join(q["sql"] for q in QUERY_LOG)
        used = [c for c in LABELS if c in all_sql]
        if used:
            st.markdown("**Cryptic legacy columns used on this page → what the dashboard shows**")
            st.dataframe(pd.DataFrame({"Legacy column": used, "Shown as": [LABELS[c] for c in used]}),
                         hide_index=True)


# ---------------------------------------------------------------------------
# 3. Login screen (legacy systems: user ID + password, no API)
# ---------------------------------------------------------------------------
def login_page():
    st.title("🚚 Fleet BI Dashboard (legacy)")
    st.caption(f"Legacy enterprise database · server {DB_HOST}:{DB_PORT} · database {DB_NAME}")
    with st.form("login"):
        user = st.text_input("User ID", value=DEFAULT_USER)
        password = st.text_input("Password", type="password")
        submitted = st.form_submit_button("Log in")
    if submitted:
        try:
            st.session_state.engine = connect(user, password)
            st.session_state.user = user
            st.rerun()
        except Exception as error:  # wrong password, server down, ...
            reason = getattr(error, "orig", error)
            st.error(f"Login failed: {reason}")
            st.info("Check the password in your .env file (BI_ANALYST_PASSWORD) and that the "
                    "fde-mysql container is running (Step 1, Part I2).")


# ---------------------------------------------------------------------------
# 4. Report pages
# ---------------------------------------------------------------------------
def page_overview():
    st.title("📊 Fleet Overview")
    st.caption("Fixed KPIs for the whole history. Legacy note: the same numbers for everyone, "
               "every day. Nothing explains them or says what to do next.")

    k = run_query("KPI tiles", f"""
SELECT COUNT(*)                           AS readings,
       MIN(TS_UTC)                        AS first_reading,
       MAX(TS_UTC)                        AS last_reading,
       SUM(RISK_CLS_TXT = 'High Risk')    AS high_risk,
       SUM(IOT_TEMP_VAL_C < 0)            AS below_0c,
       SUM(IOT_TEMP_VAL_C BETWEEN 0 AND 4) AS from_0_to_4c,
       SUM(IOT_TEMP_VAL_C > 4)            AS above_4c,
       AVG(IOT_TEMP_VAL_C)                AS avg_temp,
       AVG(DELAY_PROB_DEC)                AS avg_delay,
       AVG(PRT_CNG_LVL)                   AS avg_port,
       AVG(FUEL_CONS_RT)                  AS avg_fuel
FROM {TABLE}""").iloc[0]

    total = int(k.readings)
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Total readings", f"{total:,}")
    c2.metric("Years covered", f"{k.first_reading:%Y} – {k.last_reading:%Y}",
              f"{k.first_reading:%d %b %Y} → {k.last_reading:%d %b %Y}", delta_color="off", delta_arrow="off")
    c3.metric("High Risk readings", f"{int(k.high_risk) / total:.1%}", f"{int(k.high_risk):,} readings",
              delta_color="off", delta_arrow="off")
    c4.metric("Readings above 4 °C", f"{int(k.above_4c):,}", f"{int(k.above_4c) / total:.1%} of all",
              delta_color="off", delta_arrow="off")
    c5, c6, c7, c8 = st.columns(4)
    c5.metric("Average cargo temperature", f"{k.avg_temp:.2f} °C")
    c6.metric("Average delay probability", f"{k.avg_delay:.2f}")
    c7.metric("Average port congestion", f"{k.avg_port:.2f} / 10")
    c8.metric("Average fuel consumption rate", f"{k.avg_fuel:.2f}")
    st.info(f"Legacy note: an average of {k.avg_temp:.2f} °C looks safe, yet {int(k.above_4c):,} readings "
            "are above 4 °C. Averages hide the breaches; finding them is manual work.")

    left, right = st.columns(2)
    with left:
        st.subheader("Readings per risk class")
        risk = run_query("Readings per risk class", f"""
SELECT RISK_CLS_TXT AS risk_class, COUNT(*) AS readings
FROM {TABLE}
GROUP BY RISK_CLS_TXT
ORDER BY readings DESC""")
        st.bar_chart(risk, x="risk_class", y="readings", x_label="Risk class", y_label="Readings")
    with right:
        st.subheader("Readings per temperature band")
        bands = pd.DataFrame({"band": ["1. below 0 °C", "2. 0 to 4 °C", "3. above 4 °C"],
                              "readings": [int(k.below_0c), int(k.from_0_to_4c), int(k.above_4c)]})
        st.bar_chart(bands, x="band", y="readings", x_label="Temperature band", y_label="Readings")

    st.subheader("Average cargo temperature per month")
    monthly = run_query("Monthly average temperature", f"""
SELECT DATE_FORMAT(TS_UTC, '%Y-%m') AS month,
       ROUND(AVG(IOT_TEMP_VAL_C), 2) AS avg_temperature_c
FROM {TABLE}
GROUP BY month
ORDER BY month""")
    st.line_chart(monthly, x="month", y="avg_temperature_c", x_label="Month", y_label="Average °C")


def page_map():
    st.title("🗺️ Where are my trucks?")
    st.caption("Legacy note: the system only understands coordinates and dates. You cannot type a "
               "place name such as 'Los Angeles', there is no truck ID, and positions are historical.")

    with st.form("map_filters"):
        c1, c2, c3 = st.columns([2, 1, 1])
        period = c1.date_input("Date range", value=(LAST_DAY - timedelta(days=7), LAST_DAY),
                               min_value=FIRST_DAY, max_value=LAST_DAY)
        risk = c2.selectbox("Risk class", RISK_CLASSES)
        c4, c5, c6, c7 = st.columns(4)
        lat_min = c4.number_input("Latitude from", value=30.0, step=0.1, format="%.2f")
        lat_max = c5.number_input("Latitude to", value=50.0, step=0.1, format="%.2f")
        lon_min = c6.number_input("Longitude from", value=-120.0, step=0.1, format="%.2f")
        lon_max = c7.number_input("Longitude to", value=-70.0, step=0.1, format="%.2f")
        st.form_submit_button("Run report")

    start, end = (period[0], period[-1]) if period else (FIRST_DAY, LAST_DAY)
    conditions = ["TS_UTC >= :start", "TS_UTC < :end",
                  "V_LAT BETWEEN :lat_min AND :lat_max", "V_LON BETWEEN :lon_min AND :lon_max"]
    params = {"start": f"{start} 00:00:00", "end": f"{end + timedelta(days=1)} 00:00:00",
              "lat_min": lat_min, "lat_max": lat_max, "lon_min": lon_min, "lon_max": lon_max}
    if risk != "All":
        conditions.append("RISK_CLS_TXT = :risk")
        params["risk"] = risk

    total = run_query("Count matching readings",
                      f"SELECT COUNT(*) AS n FROM {TABLE}\n{where(conditions)}", params).n[0]
    rows = run_query("Latest 500 matching readings", f"""
SELECT {", ".join(CORE_COLUMNS)}
FROM {TABLE}
{where(conditions)}
ORDER BY TS_UTC DESC
LIMIT 500""", params)

    st.metric("Matching readings", f"{int(total):,}",
              "showing the latest 500" if total > 500 else "all shown",
              delta_color="off", delta_arrow="off")
    if rows.empty:
        st.warning("No readings match these filters.")
    else:
        points = rows.assign(color=rows.RISK_CLS_TXT.map(RISK_COLOURS))
        st.map(points, latitude="V_LAT", longitude="V_LON", color="color", size=15000)
        st.caption("Dot colour: 🔴 High Risk · 🟠 Moderate Risk · 🟢 Low Risk")
        show_table(rows)


def page_risk():
    st.title("⚠️ Risk & Delay report")
    st.caption("Legacy note: the report does not know the company rules (SOPs). To find breaches you "
               "must already know the thresholds (for example 4 °C, delay 0.65, port congestion 7.0) "
               "from separate documents and type them in yourself.")

    with st.form("risk_filters"):
        c1, c2, c3 = st.columns(3)
        risk = c1.selectbox("Risk class", RISK_CLASSES)
        year = c2.selectbox("Year", YEARS)
        month = c3.selectbox("Month", MONTHS)
        c4, c5, c6 = st.columns(3)   # empty box = no limit
        min_temp = c4.number_input("Cargo temperature above (°C)", value=None, step=0.5,
                                   placeholder="no limit")
        min_delay = c5.number_input("Delay probability above", value=None, min_value=0.0,
                                    max_value=1.0, step=0.05, placeholder="no limit")
        min_port = c6.number_input("Port congestion above", value=None, min_value=0.0,
                                   max_value=10.0, step=0.5, placeholder="no limit")
        st.form_submit_button("Run report")

    period_conditions, params = [], {}
    if risk != "All":
        period_conditions.append("RISK_CLS_TXT = :risk")
        params["risk"] = risk
    if year != "All":
        period_conditions.append("YEAR(TS_UTC) = :year")
        params["year"] = year
    if month != "All":
        period_conditions.append("MONTH(TS_UTC) = :month")
        params["month"] = month
    conditions = list(period_conditions)
    for column, name, value in [("IOT_TEMP_VAL_C", "min_temp", min_temp),
                                ("DELAY_PROB_DEC", "min_delay", min_delay),
                                ("PRT_CNG_LVL", "min_port", min_port)]:
        if value is not None:                      # only filter when a limit was typed
            conditions.append(f"{column} > :{name}")
            params[name] = value

    in_period = run_query("Readings for the chosen risk class / year / month",
                          f"SELECT COUNT(*) AS n FROM {TABLE}\n{where(period_conditions)}", params).n[0]
    matching = run_query("Readings that also pass the thresholds",
                         f"SELECT COUNT(*) AS n FROM {TABLE}\n{where(conditions)}", params).n[0]
    c1, c2, c3 = st.columns(3)
    c1.metric("Readings matching all filters", f"{int(matching):,}")
    c2.metric("Readings for risk class / year / month", f"{int(in_period):,}")
    c3.metric("Share", f"{(matching / in_period if in_period else 0):.1%}")

    per_month = run_query("Matching readings per month", f"""
SELECT DATE_FORMAT(TS_UTC, '%Y-%m') AS month, COUNT(*) AS readings
FROM {TABLE}
{where(conditions)}
GROUP BY month
ORDER BY month""", params)
    if not per_month.empty:
        st.subheader("Matching readings per month")
        st.bar_chart(per_month, x="month", y="readings", x_label="Month", y_label="Readings")

    st.subheader("Latest 100 matching readings")
    show_table(run_query("Latest 100 matching readings", f"""
SELECT {", ".join(CORE_COLUMNS)}
FROM {TABLE}
{where(conditions)}
ORDER BY TS_UTC DESC
LIMIT 100""", params))


def page_operations():
    st.title("🛠️ Truck, route & driver operations")
    st.caption("Uses 8 more columns of the legacy table (fuel, ETA, traffic, driver, weather "
               "severity, delivery, cost). Legacy note: 'weather severity' is a stored historical "
               "index, not live weather.")

    year = st.selectbox("Year", YEARS)
    conditions, params = [], {}
    if year != "All":
        conditions.append("YEAR(TS_UTC) = :year")
        params["year"] = year

    averages = ",\n       ".join(f"AVG({c}) AS {c}" for c in OPS_COLUMNS)
    k = run_query("Averages of the operations columns",
                  f"SELECT COUNT(*) AS readings,\n       {averages}\nFROM {TABLE}\n{where(conditions)}",
                  params).iloc[0]
    st.metric("Readings in the selection", f"{int(k.readings):,}")
    tiles = st.columns(4) + st.columns(4)
    for tile, column in zip(tiles, OPS_COLUMNS):
        tile.metric(f"{LABELS[column]}: average", f"{k[column]:.2f}")

    st.subheader("Monthly trend")
    column = st.selectbox("Measure", OPS_COLUMNS, format_func=lambda c: LABELS[c])
    trend = run_query(f"Monthly average of {column}", f"""
SELECT DATE_FORMAT(TS_UTC, '%Y-%m') AS month, ROUND(AVG({column}), 3) AS average
FROM {TABLE}
{where(conditions)}
GROUP BY month
ORDER BY month""", params)
    st.line_chart(trend, x="month", y="average", x_label="Month", y_label=LABELS[column])


def page_sql_console():
    st.title("🧑‍💻 Analyst SQL console")
    st.caption("Legacy note: any new question needs hand-written SQL with the cryptic column names. "
               "The login is read-only, so the database refuses any change.")

    with st.expander("Table columns as stored in the legacy database (no descriptions are stored)"):
        show_table(run_query("List the table's columns", f"DESCRIBE {TABLE}"))

    sql = st.text_area("SQL query", height=150, value=
                       "SELECT RISK_CLS_TXT, COUNT(*) AS readings\n"
                       f"FROM {TABLE}\nGROUP BY RISK_CLS_TXT;")
    if st.button("Run query", type="primary"):
        started = time.perf_counter()
        raw = st.session_state.engine.raw_connection()   # plain driver connection, no rewriting
        try:
            cursor = raw.cursor()
            cursor.execute("SET SESSION max_execution_time = 15000")   # stop runaway queries (15 s)
            cursor.execute(sql)
            columns = [d[0] for d in cursor.description] if cursor.description else []
            df = pd.DataFrame(cursor.fetchmany(1000), columns=columns)
            QUERY_LOG.append({"purpose": "Your query", "sql": sql.strip(), "rows": len(df),
                              "ms": round((time.perf_counter() - started) * 1000)})
            st.success(f"{len(df)} row(s) returned (at most 1,000 are shown).")
            st.dataframe(df, hide_index=True)
        except Exception as error:
            QUERY_LOG.append({"purpose": "Your query (refused by MySQL)", "sql": sql.strip(),
                              "rows": 0, "ms": round((time.perf_counter() - started) * 1000)})
            st.error(f"MySQL refused the query: {error}")
        finally:
            raw.close()


# ---------------------------------------------------------------------------
# 5. Main: login first, then the sidebar menu and the chosen page
# ---------------------------------------------------------------------------
PAGES = {
    "📊 Fleet Overview": page_overview,
    "🗺️ Where are my trucks?": page_map,
    "⚠️ Risk & Delay report": page_risk,
    "🛠️ Truck, route & driver operations": page_operations,
    "🧑‍💻 Analyst SQL console": page_sql_console,
}

if "engine" not in st.session_state:
    login_page()
    st.stop()

with st.sidebar:
    st.header("🚚 Fleet BI Dashboard")
    st.caption(f"Logged in as **{st.session_state.user}** (read-only)")
    choice = st.radio("Reports", list(PAGES))
    st.session_state.show_backend = st.checkbox("Show what happens at the back end", value=True)
    st.divider()
    st.text_input("💬 Ask a question in plain English",
                  placeholder="Not available in the legacy system", disabled=True)
    with st.expander("⚠️ What this legacy system cannot do"):
        st.markdown(
            "- Understand plain-English questions\n"
            "- Use live data such as weather\n"
            "- Look up company SOPs and rules\n"
            "- Explain results or suggest actions\n"
            "- Keep an audit trail of who looked at what\n"
            "- Answer a new question without a new report or hand-written SQL")
    if st.button("Log out"):
        st.session_state.engine.dispose()
        st.session_state.clear()
        st.rerun()

PAGES[choice]()
backend_panel()
