#!/usr/bin/env bash
set -euo pipefail

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
env | sort
echo

echo "[debug] Entering idle mode..."
tail -f /dev/null
