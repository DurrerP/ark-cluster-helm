export ARK_PATH="/home/steam/ark"

# env for PVCs
export ARK_A="/mnt/arkA"
export ARK_B="/mnt/arkB"
export CLUSTER_DIR="/mnt/cluster"

# In case we want to upgrade Proton
export GE_PROTON_VERSION="9-11"
export GE_PROTON_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton$GE_PROTON_VERSION/GE-Proton$GE_PROTON_VERSION.tar.gz"

export RCON_CLI_VERSION="0.10.3"
export RCON_CLI_URL="https://github.com/gorcon/rcon-cli/releases/download/v$RCON_CLI_VERSION/rcon-$RCON_CLI_VERSION-amd64_linux.tar.gz"

export STEAM_CMD_URL="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"

export KUBECTL_VERSION="v1.35.0"
export KUBECTL_URL="https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl"

export STEAM_APP_ID="2430930"
export HOME="/home/steam"
export STEAM_PATH="/home/steam/Steam"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_PATH"
export STEAM_COMPAT_DATA_PATH="$STEAM_PATH/steamapps/compatdata/$STEAM_APP_ID"



# fix some prompts
export DEBIAN_FRONTEND=noninteractive



# in case we ant to change later
export CONTAINER_GID=1000
export CONTAINER_UID=1000