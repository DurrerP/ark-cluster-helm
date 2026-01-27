
# curl -sf -H "x-api-key: $ARK_CURSEFORGE_API_KEY" https://api.curseforge.com/v1/mods/929785/files

download_mods() {
  local ARK_ROOT="$1"
  local MOD_ROOT="${ARK_ROOT}/ShooterGame/Content/Mods"
  export ARK_MODS_UPDATED=false

  if [ -z "${ARK_MOD_IDS:-}" ]; then
    echo "[mods] No ARK_MOD_IDS defined, skipping mod download"
    return 0
  fi

  if [ -z "${ARK_CURSEFORGE_API_KEY:-}" ]; then
    echo "[mods] ERROR: ARK_CURSEFORGE_API_KEY not set"
    return 1
  fi

  mkdir -p "$MOD_ROOT"

  IFS=',' read -ra MOD_IDS <<< "$ARK_MOD_IDS"

  for MOD_ID in "${MOD_IDS[@]}"; do
    MOD_ID="$(echo "$MOD_ID" | xargs)" # trim whitespace
    echo "[mods] Checking mod ${MOD_ID}"

    FILE_JSON=$(curl -sf --retry 3 --retry-delay 2 \
      -H "x-api-key: ${ARK_CURSEFORGE_API_KEY}" \
      "https://api.curseforge.com/v1/mods/${MOD_ID}/files") || {
        echo "[mods] ERROR: Failed to fetch file list for ${MOD_ID}"
        continue
      }

    FILE_ID=$(echo "$FILE_JSON" | jq -r '
      .data
      | map(select(.releaseType == 1))
      | sort_by(.fileDate)
      | last
      | .id
    ')

    DOWNLOAD_URL=$(echo "$FILE_JSON" | jq -r '
      .data
      | map(select(.releaseType == 1))
      | sort_by(.fileDate)
      | last
      | .downloadUrl
    ')

    if [ -z "$FILE_ID" ] || [ "$FILE_ID" = "null" ] || \
       [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
      echo "[mods] ERROR: No valid release file found for mod ${MOD_ID}"
      continue
    fi

    MOD_DIR="$MOD_ROOT/${MOD_ID}"
    META_FILE="$MOD_DIR/.cf_file_id"

    if [ -f "$META_FILE" ] && [ "$(cat "$META_FILE")" = "$FILE_ID" ]; then
      echo "[mods] Mod ${MOD_ID} already up-to-date"
      continue
    fi

    echo "[mods] Updating mod ${MOD_ID} (file ${FILE_ID})"
    TMP_ZIP="/tmp/mod-${MOD_ID}.zip"

    curl -Lsf --retry 3 --retry-delay 2 \
      "$DOWNLOAD_URL" -o "$TMP_ZIP" || {
        echo "[mods] ERROR: Download failed for mod ${MOD_ID}"
        rm -f "$TMP_ZIP"
        continue
      }

    if ! unzip -tq "$TMP_ZIP" >/dev/null; then
      echo "[mods] ERROR: Corrupt zip for mod ${MOD_ID}"
      rm -f "$TMP_ZIP"
      continue
    fi

    rm -rf "$MOD_DIR"
    mkdir -p "$MOD_DIR"

    unzip -oq "$TMP_ZIP" -d "$MOD_DIR"
    echo "$FILE_ID" > "$META_FILE"

    rm -f "$TMP_ZIP"

    export ARK_MODS_UPDATED=true
    echo "[mods] Mod ${MOD_ID} updated"
  done

  echo "[mods] Mod download complete (updated=${ARK_MODS_UPDATED})"
}
