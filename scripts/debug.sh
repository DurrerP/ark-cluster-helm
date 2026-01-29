#!/usr/bin/env bash
set -euo pipefail

# omit sensitive or unnecessary vars
OMIT=("LS_COLORS" "ARK_CURSEFORGE_API_KEY" "ARK_SERVER_ADMIN_PASSWORD" "ARK_SERVER_RCON_PASSWORD" )


echo "=== DEBUG INFO ==="
echo "Date: $(date)"
echo "Hostname: $(hostname)"
echo "Namespace: ${POD_NAMESPACE:-unknown}"
echo "MODE: ${MODE:-unset}"
echo "FORCE_INSTALL: ${FORCE_INSTALL:-unset}"
echo

echo "--- Mounts ---"
mount | grep mnt || true
echo

echo "--- Disk Usage ---"
df -h || true
echo

echo "--- Env ---"
env | grep -v -E "^($(IFS=\|; echo "${OMIT[*]}"))=" | sort
echo

echo "[debug] Entering idle mode..."
tail -f /dev/null
