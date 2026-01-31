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
        rcon -a 127.0.0.1:27020 -p "${ARK_SERVER_ADMIN_PASSWORD}" Broadcast "Server shutting down in $remaining minute(s)"
        sleep 60
        ((remaining--))
    done

    # 1-minute final countdown messages in 15s intervals
    rcon -a 127.0.0.1:27020 -p "${ARK_SERVER_ADMIN_PASSWORD}" Broadcast "Server shutting down in 60 seconds"
    sleep 30
    rcon -a 127.0.0.1:27020 -p "${ARK_SERVER_ADMIN_PASSWORD}" Broadcast "Server shutting down in 30 seconds"
    sleep 30
}

graceful_shutdown() {
    echo "$(timestamp) INFO: SIGTERM received, performing graceful shutdown"
    echo "$(timestamp) INFO: Saving world..."
    rcon -a 127.0.0.1:27020 -p "${ARK_SERVER_ADMIN_PASSWORD}" SafeWorld

    broadcast_shutdown_timer 5

    echo "$(timestamp) INFO: Final SafeWorld and exiting..."
    rcon -a 127.0.0.1:27020 -p "${ARK_SERVER_ADMIN_PASSWORD}" SafeWorld
    rcon -a 127.0.0.1:27020 -p "${ARK_SERVER_ADMIN_PASSWORD}" DoExit

    # Wait for port to close
    timeout=60
    while netstat -aln | grep -q "$7777" && [[ $timeout -gt 0 ]]; do
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
: "${ARK_SERVER_ADMIN_PASSWORD:?ARK_SERVER_ADMIN_PASSWORD must be set}"


# ----------------------------------------------------------------------
# Create necessary Symlinks
# ----------------------------------------------------------------------

# ARK_ACTIVE_PVC
# ln -s TARGET LINK_NAME

# PVC Savegame
mkdir -p /mnt/serverPVC/Saved
ln -sf /mnt/serverPVC/Saved $ARK_PATH/ShooterGame/Saved

# steam files
ln -sf /mnt/$ARK_ACTIVE_PVC/libsteamwebrtc.so $ARK_PATH/libsteamwebrtc.so
ln -sf /mnt/$ARK_ACTIVE_PVC/steamclient.so $ARK_PATH/steamclient.so

# base folders
ln -sf /mnt/$ARK_ACTIVE_PVC/Engine $ARK_PATH/Engine
# ln -s /mnt/$ARK_ACTIVE_PVC/linux64 $ARK_PATH/linux64
# ln -s /mnt/$ARK_ACTIVE_PVC/steamapps $ARK_PATH/steamapps

# shooterGame folders
ln -sf /mnt/$ARK_ACTIVE_PVC/ShooterGame/Binaries $ARK_PATH/ShooterGame/Binaries
ln -sf /mnt/$ARK_ACTIVE_PVC/ShooterGame/Mods $ARK_PATH/ShooterGame/Mods
ln -sf /mnt/$ARK_ACTIVE_PVC/ShooterGame/Content $ARK_PATH/ShooterGame/Content
ln -sf /mnt/$ARK_ACTIVE_PVC/ShooterGame/Plugins $ARK_PATH/ShooterGame/Plugins



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

# set max players
[[ -n "${ARK_MAX_PLAYERS:-}" ]] && update_ini "$TMP_CONFIG/GameUserSettings.ini" "ServerSettings" "MaxPlayers" "${ARK_MAX_PLAYERS}"

# set admin password
[[ -n "${ARK_SERVER_ADMIN_PASSWORD:-}" ]] && update_ini "$TMP_CONFIG/GameUserSettings.ini" "ServerSettings" "ServerAdminPassword" "${ARK_SERVER_ADMIN_PASSWORD}"

# enable RCON
[[ -n "${ARK_SERVER_RCON_PASSWORD:-}" ]] && update_ini "$TMP_CONFIG/GameUserSettings.ini" "ServerSettings" "RCONEnabled" "true"
[[ -n "${ARK_SERVER_RCON_PASSWORD:-}" ]] && update_ini "$TMP_CONFIG/GameUserSettings.ini" "ServerSettings" "RCONPort" "27020"

# active mods
[[ -n "${ARK_SERVER_RCON_PASSWORD:-}" ]] && update_ini "$TMP_CONFIG/GameUserSettings.ini" "ServerSettings" "ActiveMods" "${ARK_MOD_IDS}"



# Compute session name
SESSION_FORMAT="${ARK_SESSION_NAME:-'{cluster_id} ASA - {map_name}'}"
SESSION_FORMAT="${SESSION_FORMAT//\{cluster_id\}/${ARK_CLUSTER_ID:-Cluster}}"
SESSION_FORMAT="${SESSION_FORMAT//\{map_name\}/$ARK_SERVER_MAP}"
update_ini "$TMP_CONFIG/GameUserSettings.ini" "SessionSettings" "SessionName" "$SESSION_FORMAT"


# TODO: ServerAdminPassword to config

# ----------------------------------------------------------------------
# Move final config into Saved/Config
# ----------------------------------------------------------------------
CONFIG_DIR="${ARK_PATH}/ShooterGame/Saved/Config/WindowsServer"
mkdir -p "$CONFIG_DIR"
mv -f "$TMP_CONFIG/Game.ini" "$CONFIG_DIR/Game.ini"
mv -f "$TMP_CONFIG/GameUserSettings.ini" "$CONFIG_DIR/GameUserSettings.ini"

# ----------------------------------------------------------------------
# Build launch command from comma-separated opts and params
# ----------------------------------------------------------------------

SERVER_PARAMS=""
SERVER_OPTS=""

# ? Options
SERVER_PARAMS="${SERVER_PARAMS}?listen"
[[ -n "$ARK_SERVER_JOIN_PASSWORD" ]] && SERVER_PARAMS="${SERVER_PARAMS}?ServerPassword=${ARK_SERVER_JOIN_PASSWORD}"
IFS=',' read -ra PARAMS <<< "${ARK_SERVER_PARAMS:-}"
for param in "${PARAMS[@]}"; do
    if [ "$param" != "null" ]; then
        SERVER_PARAMS="${SERVER_PARAMS}?${param}"
    fi
done

# - Options
SERVER_OPTS="${SERVER_OPTS} -clusterid=${ARK_CLUSTER_ID}"
SERVER_OPTS="${SERVER_OPTS} -ClusterDirOverride=${ARK_CLUSTER_DIR}"

IFS=',' read -ra OPTS <<< "${ARK_SERVER_OPTS:-}"
for opt in "${OPTS[@]}"; do
    if [ "$opt" != "null" ]; then
        SERVER_OPTS="${SERVER_OPTS} -${opt}"
    fi
done
[[ -n "$ARK_MOD_IDS" ]] && SERVER_OPTS="${SERVER_OPTS} -mods=${ARK_MOD_IDS}"



# TODO: ADD Cluster Config params

# run - first
# LAUNCH_COMMAND="${SERVER_OPTS} ${ARK_SERVER_MAP}${SERVER_PARAMS}"
# [[ -n "$ARK_SERVER_JOIN_PASSWORD" ]] && LAUNCH_COMMAND="${LAUNCH_COMMAND}?ServerPassword=${ARK_SERVER_JOIN_PASSWORD}"

# run ? first
LAUNCH_COMMAND="${ARK_SERVER_MAP}${SERVER_PARAMS}"
#[[ -n "$ARK_SERVER_JOIN_PASSWORD" ]] && LAUNCH_COMMAND="${LAUNCH_COMMAND}?ServerPassword=${ARK_SERVER_JOIN_PASSWORD}"
LAUNCH_COMMAND="${LAUNCH_COMMAND}${SERVER_OPTS}"


# LAUNCH_COMMAND="${ARK_SERVER_MAP}${SERVER_PARAMS}${SERVER_OPTS}"
# [[ -n "${ARK_MOD_IDS:-}" ]] && LAUNCH_COMMAND="${LAUNCH_COMMAND} -ARK_MOD_IDS=${ARK_MOD_IDS}"
# [[ -n "$ARK_SERVER_JOIN_PASSWORD" ]] && LAUNCH_COMMAND="${LAUNCH_COMMAND}?ServerPassword=${ARK_SERVER_JOIN_PASSWORD}"


# Prepare Proton Prefix:
# Add to docker compose
# ARK_PREFIX="${STEAM_PATH}/steamapps/compatdata/${STEAM_APP_ID}"
# if [ ! -d "$ARK_PREFIX/pfx" ]; then
#     DEFAULT_PREFIX="${STEAM_COMPAT_CLIENT_INSTALL_PATH}/compatibilitytools.d/GE-Proton${GE_PROTON_VERSION}/files/share/default_pfx"
#     cp -r "${DEFAULT_PREFIX}/." "$ARK_PREFIX/" || {
#         echo -e "${RED}Error copying default_pfx!${RESET}"
#         exit 1
#     }
# fi



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
echo "Game Port: 7777"
echo "RCON Port: 27015"
echo "ARK_MOD_IDS: ${ARK_MOD_IDS:-none}"
echo "Extra Opts: ${SERVER_OPTS}"
echo "Extra Params: ${SERVER_PARAMS}"
echo ""


# ----------------------------------------------------------------------
# Launch server via Proton
# ----------------------------------------------------------------------

# some proton flags
export PROTON_NO_FSYNC=1
export PROTON_NO_ESYNC=1

echo "launching with"
echo "${LAUNCH_COMMAND}"
echo "$(timestamp) INFO: Starting ARK:SA..."
"${STEAM_PATH}/compatibilitytools.d/GE-Proton${GE_PROTON_VERSION}/proton" run "${ARK_PATH}/ShooterGame/Binaries/Win64/ArkAscendedServer.exe" $LAUNCH_COMMAND &


# echo "${STEAM_PATH}/compatibilitytools.d/GE-Proton${GE_PROTON_VERSION}/proton" run "${ARK_PATH}/ShooterGame/Binaries/Win64/ArkAscendedServer.exe" "${ARK_SERVER_MAP}${SERVER_PARAMS}" ${SERVER_OPTS}
# "${STEAM_PATH}/compatibilitytools.d/GE-Proton${GE_PROTON_VERSION}/proton" run "${ARK_PATH}/ShooterGame/Binaries/Win64/ArkAscendedServer.exe" "${ARK_SERVER_MAP}${SERVER_PARAMS}" ${SERVER_OPTS}

# /home/steam/Steam/compatibilitytools.d/GE-Proton10-29/proton run /home/steam/ark/ShooterGame/Binaries/Win64/ArkAscendedServer.exe TheIsland_WP?listen?serverPVE -clusterid=JumpySloths -ClusterDirOverride=/mnt/cluster -ForceAllowCaveFlyers -GBUsageToForceRestart=22 -forceuseperfthreads -ServerUseEventColors -NoBattleEye

asa_pid=$!
wait "$asa_pid"

# reverent_chebyshev
# 172.17.0.2
# pidof ptyhon3
# ls -lah ark/ShooterGame/Saved/Logs
# cat ark/ShooterGame/Saved/Logs/ShooterGame.log
