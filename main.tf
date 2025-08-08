#!/usr/bin/env bash
set -euo pipefail

# Where to log (override by exporting LOG_FILE before running)
LOG_FILE="${LOG_FILE:-$HOME/ora_check.log}"

# ORATAB location (override by exporting ORATAB if needed)
ORATAB="${ORATAB:-/etc/oratab}"

# Expect PT_dbname to be set in the environment
db_name="${PT_dbname:-}"

timestamp() { date '+%a %b %d %T %Y'; }

if [[ -z "$db_name" ]]; then
  echo "$(timestamp) | ERROR | PT_dbname is not set. Export it, e.g. 'export PT_dbname=ORCL'." | tee -a "$LOG_FILE"
  exit 3
fi

# Find PMON for the DB
pmon_id="$(pgrep -f "ora_pmon_${db_name}" || true)"
if [[ -z "$pmon_id" ]]; then
  echo "$(timestamp) | INFO | DATABASE ${db_name} is not running on $(hostname)" | tee -a "$LOG_FILE"
  exit 1
fi

# Derive ORACLE_SID from the PMON command
instance_name="$(ps -o cmd= -p "$pmon_id")"
ORACLE_SID="$(awk -F'_' '{print $3}' <<< "$instance_name")"

# Find ORACLE_HOME from oratab
ORACLE_HOME="$(grep -E "^${db_name}:" "$ORATAB" | awk -F: 'END{print $2}')"
if [[ -z "${ORACLE_HOME}" ]]; then
  echo "$(timestamp) | ERROR | DATABASE ${db_name} not found in ${ORATAB} on $(hostname)" | tee -a "$LOG_FILE"
  exit 2
fi

export ORACLE_SID ORACLE_HOME
PATH="$ORACLE_HOME/bin:$PATH"

# tnsping check
if command -v tnsping >/dev/null 2>&1; then
  echo "$(timestamp) | INFO | Running tnsping for ${db_name}..." | tee -a "$LOG_FILE"
  if tnsping "$db_name" | tee -a "$LOG_FILE"; then
    echo "$(timestamp) | INFO | tnsping succeeded for ${db_name}" | tee -a "$LOG_FILE"
    exit 0
  else
    echo "$(timestamp) | ERROR | tnsping failed for ${db_name}" | tee -a "$LOG_FILE"
    exit 5
  fi
else
  echo "$(timestamp) | ERROR | tnsping not found in PATH. Expected under ${ORACLE_HOME}/bin." | tee -a "$LOG_FILE"
  exit 4
fi
