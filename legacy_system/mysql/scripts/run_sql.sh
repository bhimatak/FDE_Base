#!/bin/sh
# =====================================================================
# run_sql.sh - runs SQL as the MySQL admin (root) INSIDE the fde-mysql
# container.
#
# Usage (from the project folder, on macOS or Windows):
#   docker exec fde-mysql sh /scripts/run_sql.sh /scripts/<file>.sql
# or with SQL on standard input:
#   ... | docker exec -i fde-mysql sh /scripts/run_sql.sh
#
# The root password comes from the container's environment (docker compose
# copies it from .env). It is written to a private temporary option file,
# so it never appears on screen or in the process list, and the file is
# removed when the script ends.
# =====================================================================
set -eu

: "${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD is not set in the container - check .env and restart with docker compose}"

umask 077
CNF="$(mktemp 2>/dev/null || echo "/tmp/.run_sql_$$.cnf")"
trap 'rm -f "$CNF"' EXIT INT TERM
printf '[client]\nuser=root\npassword="%s"\n' "$MYSQL_ROOT_PASSWORD" > "$CNF"

if [ "$#" -ge 1 ]; then
  if [ ! -f "$1" ]; then
    echo "run_sql.sh: file not found: $1" >&2
    exit 1
  fi
  mysql --defaults-extra-file="$CNF" --local-infile=1 --table < "$1"
else
  mysql --defaults-extra-file="$CNF" --local-infile=1 --table
fi
