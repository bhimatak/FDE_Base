#!/usr/bin/env bash
# =====================================================================
# create_env.sh - creates the project-root .env file for the legacy
# MySQL system on macOS (or Linux). On Windows use create_env.ps1.
# Works with the bash 3.2 that ships with macOS.
#
#   bash legacy_system/create_env.sh
#
# - Asks for two passwords without showing them on screen.
# - Never prints the passwords.
# - Never overwrites an existing .env.
# - Makes .env readable by you only (chmod 600).
#
# Allowed password characters: letters, digits and  _ @ % + = . -
# (so they work unchanged in Docker Compose, MySQL and Python later on).
# =====================================================================
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

if [ -f "$ENV_FILE" ]; then
  echo "INFO: $ENV_FILE already exists - nothing was changed."
  echo "      To start again, rename it first, e.g.  mv .env .env.old"
  exit 0
fi

ask_password() {
  # $1 = what the password is for. Result is left in NEW_PASSWORD.
  local first second
  while true; do
    printf 'New password for %s (hidden): ' "$1"
    IFS= read -r -s first; echo
    printf 'Type it again: '
    IFS= read -r -s second; echo
    if [ "$first" != "$second" ]; then
      echo "  x The two entries are different. Please try again."
      continue
    fi
    if [ "${#first}" -lt 8 ]; then
      echo "  x Use at least 8 characters. Please try again."
      continue
    fi
    case "$first" in
      *[!A-Za-z0-9_@%+=.-]*)
        echo "  x Use only letters, digits and  _ @ % + = . -  Please try again."
        continue
        ;;
    esac
    NEW_PASSWORD="$first"
    return 0
  done
}

echo "Creating $ENV_FILE"
echo
ask_password "the MySQL admin user 'root'"
ROOT_PW="$NEW_PASSWORD"
echo
ask_password "the read-only login 'bi_analyst'"
BI_PW="$NEW_PASSWORD"
if [ "$ROOT_PW" = "$BI_PW" ]; then
  echo "  ! Note: both passwords are the same. That works, but different ones are safer."
fi

umask 077
cat > "$ENV_FILE" <<EOF
# =====================================================================
# FDE Cold-Chain project - private settings. NEVER commit this file.
# Created by legacy_system/create_env.sh
# =====================================================================

# ---- Step 1: legacy system (MySQL 8.4 in Docker) ----
DB_ENGINE=MYSQL
MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
MYSQL_ADMIN_USER=root
MYSQL_ROOT_PASSWORD=${ROOT_PW}
LEGACY_DB=legacy_fleet
LEGACY_TABLE=TBL_SC_FLEET_HIST_RAW
BI_ANALYST_USER=bi_analyst
BI_ANALYST_PASSWORD=${BI_PW}
EOF
chmod 600 "$ENV_FILE"
unset ROOT_PW BI_PW NEW_PASSWORD

echo
echo "OK: .env created (passwords not shown). Settings in the file:"
sed -E 's/^([A-Z_]*PASSWORD)=.+$/\1=******** (set)/' "$ENV_FILE" | grep -E '^[A-Z_]+='
