#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------------------------------------------
# Paths & configuration
# ----------------------------------------------------------------------
NAMESPACE="${POD_NAMESPACE:-default}"
CONFIGMAP_NAME="ark-cluster-state"

# Secrets / Mods
ARK_MOD_IDS="${ARK_MOD_IDS:-}"
ARK_CURSEFORGE_API_KEY="${ARK_CURSEFORGE_API_KEY:-}"

# ----------------------------------------------------------------------
# Determine active/inactive PVC
# ----------------------------------------------------------------------
ACTIVE_DRIVE="${ARK_ACTIVE_PVC:-arkA}"

if [[ "$ACTIVE_DRIVE" == "arkB" ]]; then
  TARGET_DRIVE="arkA"
else 
  TARGET_DRIVE="arkB"
fi
TARGET_PATH="/mnt/$TARGET_DRIVE"

echo "[update] Active PVC: $ACTIVE_DRIVE"
echo "[update] Updating inactive PVC: $TARGET_DRIVE ($TARGET_PATH)"

# ----------------------------------------------------------------------
# SteamCMD update
# ----------------------------------------------------------------------
ARK_SERVER_UPDATED=false
echo "[update] Running SteamCMD update..."
UPDATE_OUTPUT=$("$STEAM_PATH/steamcmd.sh" \
  +@sSteamCmdForcePlatformType windows \
  +force_install_dir "$TARGET_PATH" \
  +login anonymous \
  +app_update "$ARK_APP_ID" validate \
  +quit 2>&1
)
echo "$UPDATE_OUTPUT"

if ! echo "$UPDATE_OUTPUT" | grep -Eiq "already up to date|nothing to update"; then
  echo "[update] SteamCMD update applied."
  ARK_SERVER_UPDATED=true
else
  echo "[update] No server update detected."
fi

# ----------------------------------------------------------------------
# Download mods
# ----------------------------------------------------------------------
if [[ -n "$ARK_MOD_IDS" && -n "$ARK_CURSEFORGE_API_KEY" ]]; then
  echo "[update] Downloading mods for $TARGET_PATH..."
  source ./helperFunctions.sh
  download_mods "$TARGET_PATH"
  # download_mods sets env ARK_MODS_UPDATED=true if any mod was updated
fi

# ----------------------------------------------------------------------
# Update ConfigMap only if updates were applied
# ----------------------------------------------------------------------
if [[ "$ARK_SERVER_UPDATED" == true || "${ARK_MODS_UPDATED:-false}" == true]]; then
  echo "[update] Updates detected. Patching ConfigMap and restarting StatefulSets..."
  
  if command -v kubectl >/dev/null 2>&1; then
    kubectl patch configmap "$CONFIGMAP_NAME" \
      -n "$NAMESPACE" \
      --type merge \
      -p "{\"data\":{\"ARK_ACTIVE_PVC\":\"$TARGET_DRIVE\",\"ARK_LAST_UPDATETIME\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}" \
      || echo "[update] WARNING: Failed to patch ConfigMap"

    # Restart StatefulSets
    for sts in $(kubectl get sts -n "$NAMESPACE" -o name); do
      kubectl rollout restart "$sts" -n "$NAMESPACE"
    done
  else
    echo "[update] kubectl not found, skipping ConfigMap update and StatefulSet restarts."
  fi
else
  echo "[update] No updates detected (server or mods). ConfigMap not modified."
fi

echo "[update] Update process completed."
