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
ACTIVE_PATH="/mnt/$ACTIVE_DRIVE"

echo "[update] Active PVC: $ACTIVE_DRIVE"
echo "[update] Updating inactive PVC: $TARGET_DRIVE ($TARGET_PATH)"

# ----------------------------------------------------------------------
# SteamCMD update
# ----------------------------------------------------------------------
MANIFEST="$TARGET_PATH/steamapps/appmanifest_${STEAM_APP_ID}.acf"

get_buildid() {
  awk -F\" '/"buildid"/ { print $4 }' "$MANIFEST" 2>/dev/null
}

BEFORE_BUILDID=$(get_buildid)

echo "[update] Running SteamCMD update..."
"$STEAM_PATH/steamcmd.sh" \
  +force_install_dir "$TARGET_PATH" \
  +login anonymous \
  +app_update "$STEAM_APP_ID" validate \
  +quit

AFTER_BUILDID=$(get_buildid)

if [[ -n "$BEFORE_BUILDID" && "$BEFORE_BUILDID" != "$AFTER_BUILDID" ]]; then
  echo "[update] Server updated ($BEFORE_BUILDID → $AFTER_BUILDID)"
  ARK_SERVER_UPDATED=true
else
  echo "[update] No server update detected."
  ARK_SERVER_UPDATED=false
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
if [[ "$ARK_SERVER_UPDATED" == true || "${ARK_MODS_UPDATED:-false}" == true ]]; then
  echo "[update] Updates detected. Patching ConfigMap and restarting StatefulSets..."

  if command -v kubectl >/dev/null 2>&1; then

    # Patch ConfigMap
    kubectl patch configmap "$CONFIGMAP_NAME" \
      -n "$NAMESPACE" \
      --type merge \
      -p "{\"data\":{\"ARK_ACTIVE_PVC\":\"$TARGET_DRIVE\",\"ARK_LAST_UPDATETIME\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}" \
      || echo "[update] WARNING: Failed to patch ConfigMap"

    # Get StatefulSets once (deterministic order)
    STS_LIST=$(kubectl get sts -n "$NAMESPACE" -o name | sort)

    echo "[update] Restarting StatefulSets (2 min spacing)..."

    # Phase 1: staggered parallel restarts
    for sts in $STS_LIST; do
      echo "[update] Triggering restart for $sts..."
      kubectl rollout restart "$sts" -n "$NAMESPACE"
      sleep 120
    done

    # Ensure all restart commands were issued
    wait
    echo "[update] All StatefulSet restarts triggered."

    # Phase 2: wait for all rollouts AFTER last restart
    echo "[update] Waiting up to 20 minutes for all StatefulSets to become ready..."
    for sts in $STS_LIST; do
      echo "[update] Waiting for rollout of $sts..."
      kubectl rollout status "$sts" -n "$NAMESPACE" --timeout=20m \
        || {
          echo "[update] ERROR: Rollout of $sts failed or timed out."
          exit 1
        }
    done

    echo "[update] All StatefulSets ready. Running post-restart action..."
    rsync -a --delete "$TARGET_PATH/" "$ACTIVE_PATH/"
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Updating previous Active PVC done."


  else
    echo "[update] kubectl not found, skipping ConfigMap update and StatefulSet restarts."
  fi
else
  echo "[update] No updates detected (server or mods). ConfigMap not modified."
fi

