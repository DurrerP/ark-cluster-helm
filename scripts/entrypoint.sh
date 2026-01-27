#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-${MODE:-}}"

# Fail if MODE is empty
if [ -z "$MODE" ]; then
  echo "[entrypoint] ERROR: MODE not set. Pass as argument or set MODE env variable."
  exit 1
fi

echo "[entrypoint] MODE=${MODE}"

case "$MODE" in
  init)
    exec ./initCluster.sh
    ;;
  update)
    exec ./updateCluster.sh
    ;;
  server)
    exec ./runServer.sh
    ;;
  debug)
    exec ./debug.sh
    ;;
  *)
    echo "[entrypoint] Unknown MODE: $MODE"
    exit 1
    ;;
esac
