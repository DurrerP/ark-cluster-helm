#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------------------------------------------
# Helper functions
# ----------------------------------------------------------------------
timestamp() {
    date +"%Y-%m-%d %H:%M:%S,%3N"
}

broadcast_shutdown_timer() {
    local total_minutes=$1
    local remaining=$total_minutes

    echo "$(timestamp) INFO: Initiating shutdown sequence for $total_minutes minute(s)"
    
    while [[ $remaining -gt 0 ]]; do
        rcon -a 127.0.0.1:"${ARK_SERVER_RCON_PORT}" -p "${ARK_SERVER_RCON_PASSWORD}" Broadcast "Server shutting down in $remaining minute(s)"
        sleep 60
        ((remaining--))
    done

    # 1-minute final countdown messages in 15s intervals
    rcon -a 127.0.0.1:"${ARK_SERVER_RCON_PORT}" -p "${ARK_SERVER_RCON_PASSWORD}" Broadcast "Server shutting down in 60 seconds"
    sleep 30
    rcon -a 127.0.0.1:"${ARK_SERVER_RCON_PORT}" -p "${ARK_SERVER_RCON_PASSWORD}" Broadcast "Server shutting down in 30 seconds"
    sleep 30
}

graceful_shutdown() {
    echo "$(timestamp) INFO: SIGTERM received, performing graceful shutdown"
    echo "$(timestamp) INFO: Saving world..."
    rcon -a 127.0.0.1:"${ARK_SERVER_RCON_PORT}" -p "${ARK_SERVER_RCON_PASSWORD}" SafeWorld

    broadcast_shutdown_timer 5

    echo "$(timestamp) INFO: Final SafeWorld and exiting..."
    rcon -a 127.0.0.1:"${ARK_SERVER_RCON_PORT}" -p "${ARK_SERVER_RCON_PASSWORD}" SafeWorld
    rcon -a 127.0.0.1:"${ARK_SERVER_RCON_PORT}" -p "${ARK_SERVER_RCON_PASSWORD}" DoExit

    # Wait for port to close
    timeout=60
    while netstat -aln | grep -q "$ARK_SERVER_PORT" && [[ $timeout -gt 0 ]]; do
        sleep 1
        ((timeout--))
    done

    echo "$(timestamp) INFO: Goodbye"
    kill -15 "$asa_pid" 2>/dev/null || true
}

trap 'graceful_shutdown' TERM

# ----------------------------------------------------------------------
# Environment validation & defaults
# ----------------------------------------------------------------------
: "${ARK_SERVER_MAP:=TheIsland_WP}"
: "${SESSION_NAME:?SESSION_NAME must be set}"
: "${ARK_SERVER_PORT:?ARK_SERVER_PORT must be set}"
: "${ARK_SERVER_RCON_PORT:?ARK_SERVER_RCON_PORT must be set}"
SERVER_PASSWORD="${ARK_SERVER_JOIN_PASSWORD:-}"
SERVER_ADMIN_PASSWORD="${ARK_SERVER_ADMIN_PASSWORD:?ARK_SERVER_ADMIN_PASSWORD must be set}"

# ----------------------------------------------------------------------
# Ensure Saved folder exists (dedicated server PVC)
# ----------------------------------------------------------------------
ARK_PATH_SAVED="${ARK_PATH}/ShooterGame/Saved"
mkdir -p "$ARK_PATH_SAVED"
echo "$(timestamp) INFO: Using dedicated Saved PVC mounted at $ARK_PATH_SAVED"

# ----------------------------------------------------------------------
# Config preparation
# ----------------------------------------------------------------------
TMP_CONFIG="/tmp/ark_config"
mkdir -p "$TMP_CONFIG"

# Copy Game.ini and GameUserSettings.ini from configmap
cp /mnt/configmap/Game.ini "$TMP_CONFIG/Game.ini"
cp /mnt/configmap/GameUserSettings.ini "$TMP_CONFIG/GameUserSettings.ini"

# ----------------------------------------------------------------------
# Merge ark-global-settings into the INI files properly
# ----------------------------------------------------------------------
update_ini() {
    local file="$1"
    local section="$2"
    local key="$3"
    local value="$4"

    # If section exists
    if grep -q "^\[$section\]" "$file"; then
        if grep -q "^$key=" "$file"; then
            # Replace existing key
            sed -i "s|^$key=.*|$key=$value|" "$file"
        else
            # Add key under section
            sed -i "/^\[$section\]/a $key=$value" "$file"
        fi
    else
        # Section doesn't exist, append at end
        echo -e "\n[$section]\n$key=$value" >> "$file"
    fi
}

# Map global settings
[[ -n "${ARK_ENABLE_BATTLE_EYE:-}" ]] && update_ini "$TMP_CONFIG/GameUserSettings.ini" "ServerSettings" "bBattlEyeEnabled" "${ARK_ENABLE_BATTLE_EYE}"
[[ -n "${ARK_MAX_PLAYERS:-}" ]] && update_ini "$TMP_CONFIG/GameUserSettings.ini" "ServerSettings" "MaxPlayers" "${ARK_MAX_PLAYERS}"

# Compute session name
SESSION_FORMAT="${ARK_SESSION_NAME_FORMAT:-'{cluster_id} ASA - {map_name}'}"
SESSION_FORMAT="${SESSION_FORMAT//\{cluster_id\}/${ARK_CLUSTER_ID:-Cluster}}"
SESSION_FORMAT="${SESSION_FORMAT//\{map_name\}/$ARK_SERVER_MAP}"
update_ini "$TMP_CONFIG/GameUserSettings.ini" "ServerSettings" "SessionName" "$SESSION_FORMAT"

# ----------------------------------------------------------------------
# Move final config into Saved/Config
# ----------------------------------------------------------------------
CONFIG_DIR="${ARK_PATH}/ShooterGame/Saved/Config/WindowsServer"
mkdir -p "$CONFIG_DIR"
mv "$TMP_CONFIG/Game.ini" "$CONFIG_DIR/Game.ini"
mv "$TMP_CONFIG/GameUserSettings.ini" "$CONFIG_DIR/GameUserSettings.ini"

# ----------------------------------------------------------------------
# Build launch command from comma-separated opts and params
# ----------------------------------------------------------------------
SERVER_PARAMS=""
IFS=',' read -ra OPTS <<< "${ARK_SERVER_OPTS:-}"
for opt in "${OPTS[@]}"; do
    SERVER_PARAMS="${SERVER_PARAMS}?${opt}"
done

IFS=',' read -ra PARAMS <<< "${ARK_SERVER_PARAMS:-}"
for param in "${PARAMS[@]}"; do
    SERVER_PARAMS="${SERVER_PARAMS}?${param}"
done

LAUNCH_COMMAND="${ARK_SERVER_MAP}?SessionName=${SESSION_FORMAT}?RCONEnabled=True?RCONPort=${ARK_SERVER_RCON_PORT}${SERVER_PARAMS}"
[[ -n "$SERVER_PASSWORD" ]] && LAUNCH_COMMAND="${LAUNCH_COMMAND}?ServerPassword=${SERVER_PASSWORD}"
LAUNCH_COMMAND="${LAUNCH_COMMAND}?ServerAdminPassword=${SERVER_ADMIN_PASSWORD}"
[[ -n "${EXTRA_FLAGS:-}" ]] && LAUNCH_COMMAND="${LAUNCH_COMMAND} ${EXTRA_FLAGS}"
[[ -n "${MODS:-}" ]] && LAUNCH_COMMAND="${LAUNCH_COMMAND} -mods=${MODS}"

# ----------------------------------------------------------------------
# Print ASCII banner
# ----------------------------------------------------------------------

cat << "EOF"
   _____         __                                       
  /  _  \_______|  | __                                    
 /  /_\  \_  __ \  |/ /                                    
/    |    \  | \/    <                                     
\____|__  /__|  |__|_ \                                    
        \/           \/                                    
  _________                  .__              .__          
 /   _____/__ ____________  _|__|__  _______  |  |         
 \_____  \|  |  \_  __ \  \/ /  \  \/ /\__  \ |  |         
 /        \  |  /|  | \/\   /|  |\   /  / __ \|  |__       
/_______  /____/ |__|    \_/ |__| \_/  (____  /____/       
        \/                                  \/             
   _____                                  .___         .___
  /  _  \   ______ ____  ____   ____    __| _/____   __| _/
 /  /_\  \ /  ___// ___\/ __ \ /    \  / __ |/ __ \ / __ | 
/    |    \\\___ \\\  \__\  ___/|   |  \/ /_/ \  ___// /_/  
\____|__  /____  >\___  >___  >___|  /\____ |\___  >____ | 
        \/     \/     \/    \/     \/      \/    \/     \/ 
                                                                                                                      
EOF

echo "$(timestamp) INFO: Launching ARK:SA Server"
echo "-----------------------------------------------------------"
echo "Session: $SESSION_FORMAT"
echo "Server Password: ${ARK_SERVER_JOIN_PASSWORD}"
echo "Map: $ARK_SERVER_MAP"
echo "Game Port: $ARK_SERVER_PORT"
echo "RCON Port: $ARK_SERVER_RCON_PORT"
echo "Mods: ${MODS:-none}"
echo "Extra Params: ${SERVER_PARAMS}"
echo ""


# ----------------------------------------------------------------------
# Launch server via Proton
# ----------------------------------------------------------------------
echo "$(timestamp) INFO: Starting ARK:SA..."
"${STEAM_PATH}/compatibilitytools.d/GE-Proton${GE_PROTON_VERSION}/proton" run "${ARK_PATH}/ShooterGame/Binaries/Win64/ArkAscendedServer.exe" $LAUNCH_COMMAND &

asa_pid=$!
wait "$asa_pid"
