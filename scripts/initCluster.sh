#!/usr/bin/env bash
set -euo pipefail

ARK_FORCE_INSTALL="${ARK_FORCE_INSTALL:-false}"

echo "[init] Starting cluster initialization"
echo "[init] ARK_FORCE_INSTALL=${ARK_FORCE_INSTALL}"

# -------------------------------------------------
# Check existing data
# -------------------------------------------------
initialized=false

for dir in "$ARK_A" "$ARK_B" "$ARK_CLUSTER_DIR"; do
  if [ -d "$dir" ] && [ "$(ls -A "$dir" 2>/dev/null)" ]; then
    echo "[init] Existing data found in $dir"
    initialized=true
  fi
done

if [ "$initialized" = true ] && [ "$ARK_FORCE_INSTALL" != "true" ]; then
  echo "[init] Cluster already initialized. Set ARK_FORCE_INSTALL=true to reinitialize."
  exit 0
fi

# -------------------------------------------------
# Wipe existing data if forced
# -------------------------------------------------
if [ "$initialized" = true ] && [ "$ARK_FORCE_INSTALL" = "true" ]; then
  echo "[init] ARK_FORCE_INSTALL enabled, wiping existing data"
  rm -rf "${ARK_A:?}/"* "${ARK_B:?}/"* "${ARK_CLUSTER_DIR:?}/"*
fi

# -------------------------------------------------
# Install ASA Server into arkA
# -------------------------------------------------
echo "[init] Installing ASA Server (AppID: ${STEAM_APP_ID}) into ${ARK_A}"

"${STEAM_PATH}/steamcmd.sh" \
  +force_install_dir "$ARK_A" \
  +login anonymous \
  +app_update "$STEAM_APP_ID" validate \
  +quit

# ToDO
# if output: 
# ERROR! Failed to install app '2430930' (Missing configuration)
# retry

echo "[init] ASA installation complete"

# -------------------------------------------------
# Install mods if ARK_CURSEFORGE_API_KEY exists.
# -------------------------------------------------
if [ "$ARK_CURSEFORGE_API_KEY:-" ]; then
  if [ -f ./helperFunctions.sh ]; then
    source ./helperFunctions.sh
  else
    echo "[init] WARNING: helperFunctions.sh not found, skipping mod downloads"
  fi
  download_mods "$ARK_A"
fi

# -------------------------------------------------
# Copy arkA → arkB
# -------------------------------------------------
echo "[init] Syncing arkA to arkB"
rsync -a --delete "$ARK_A/" "$ARK_B/"
echo "[init] arkB successfully initialized"

# -------------------------------------------------
# Initialize cluster directory
# -------------------------------------------------
echo "[init] Initializing cluster directory"

# ASA expects this to exist; contents will be populated at runtime
mkdir -p "$ARK_CLUSTER_DIR"/{Saved,Config}

# change to write to configMap
echo "initialized=$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$ARK_CLUSTER_DIR/.initialized"

echo "[init] Cluster directory ready"

# -------------------------------------------------
# Done
# -------------------------------------------------
echo "[init] Cluster initialization completed successfully"
