
# PVC mounts

arkA -> /mnt/arkA
arkB -> /mnt/arkB
cluster -> /mnt/cluster

arkA and arkB are supposed to be mounted :ro on any server, :rw when it's an init or update Job
cluster should always be mounted in :rw fashion.

# env Vars

## set in docker build

ARK_PATH="/home/steam/ark"

ARK_A="/mnt/arkA"
ARK_B="/mnt/arkB"
CLUSTER_DIR="/mnt/cluster"

GE_PROTON_VERSION="9-11"
GE_PROTON_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton$GE_PROTON_VERSION/GE-Proton$GE_PROTON_VERSION.tar.gz"

RCON_CLI_VERSION="0.10.3"
RCON_CLI_URL="https://github.com/gorcon/rcon-cli/releases/download/v$RCON_CLI_VERSION/rcon-$RCON_CLI_VERSION-amd64_linux.tar.gz"

STEAM_CMD_URL="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"

KUBECTL_VERSION="v1.35.0"
KUBECTL_URL="https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl"

STEAM_APP_ID="2430930"
HOME="/home/steam"
STEAM_PATH="/home/steam/Steam"
STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_PATH"
STEAM_COMPAT_DATA_PATH="$STEAM_PATH/steamapps/compatdata/$STEAM_APP_ID"
DEBIAN_FRONTEND=noninteractive
CONTAINER_GID=1000
CONTAINER_UID=1000


## General
MODE -> init, update, server, debug
- init -> initializes the PVCs
- update -> updates the not active PVCs and changes the configmap if updates were done, also restarts all sts
- server -> runs a server
- debug -> prints env and runs forever.


## init
ARK_FORCE_INSTALL -> defaults to false if not set or set to false. if true will delete the full arkA and arkB and cluster PVCs and re-initialize.

## update


## server


## debug



# ConfigMap env Vars

## ark-global-configfiles
mapped ReadOnly to create per Server files to /mnt/configmap

data:
  Game.ini : |
    contains shared Game.ini data

  GameUserSettings.ini : |
    contains shared GameUserSettings.ini data

## ark-global-settings
mapped into env of every POD

data:
    ARK_ENABLE_BATTLE_EYE: "false"/"true"
    ARK_CLUSTER_ID: "JumpySloths"
    ARK_MAX_PLAYERS: "13"
    ARK_MOD_IDS: "929420,935408,933099,940975,930404,935399,930494,950914,929785"
    ARK_SERVER_OPTS: "ForceAllowCaveFlyers,GBUsageToForceRestart=22,orceuseperfthreads,ServerUseEventColors"
    ARK_SERVER_PARAMS: "AdminLogging,AllowFlyerCarryPvE,serverPVE"
    ARK_SESSION_NAME_FORMAT: "{cluster_id} ASA - {map_name}"


## ark-cluster-state
mapped into env of every Pod

( initially deployed with Helm, but not changed/updated)

data:
    ARK_ACTIVE_PVC: "arkA" / "arkB"
    ARK_INITIALIZED_TIME: timestamp
    ARK_LAST_UPDATETIME: timestamp

# Secrets

## ark-cluster-secrets

stringData:
    ARK_SERVER_ADMIN_PASSWORD: password
    ARK_SERVER_JOIN_PASSWORD: password
    ARK_SERVER_RCON_PASSWORD: password
    ARK_CURSEFORGE_API_KEY: api-key (for downloading mods)




# Behaviour

## init
will initialize the PVCs mounted to /mnt/arkA /mnt/arkB /mnt/Cluster
will install mods if ARK_CURSEFORGE_API_KEY is configured.
write INITIALIZED_TIME=timestamp to ark-cluster-state Configmap

## update
will update the non-active PVC
will update mods if ARK_CURSEFORGE_API_KEY is configured
update UPDATED_TIMESTAMP if any update was done
restart all STS if any update was done. (2 minutes between maps)

## server
will mount a dedicated PVC for Saved
expects env vars for
ARK_SERVER_PORT
ARK_SERVER_RCON_PORT
ARK_SERVER_MAP
will also parse ark-global-settings into either launch params or config file

on STS Rollout will do a gracefull shutdown in 5 minutes (Broadcasting time left every minute, and then 30 secs before)

