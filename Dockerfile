FROM ubuntu:latest


# might need to be changed
ENV ARK_PATH="/home/steam/ark"

# env for PVCs
ENV ARK_A="/mnt/arkA"
ENV ARK_B="/mnt/arkB"
ENV ARK_CLUSTER_DIR="/mnt/cluster"
ENV ARK_CONFIG_MAP="/mnt/configmap"

# ProtonGE Version
ENV GE_PROTON_VERSION="9-11"
ENV GE_PROTON_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton${GE_PROTON_VERSION}/GE-Proton${GE_PROTON_VERSION}.tar.gz"

# rcon-cli Version
ENV RCON_CLI_VERSION="0.10.3"
ENV RCON_CLI_URL="https://github.com/gorcon/rcon-cli/releases/download/v${RCON_CLI_VERSION}/rcon-${RCON_CLI_VERSION}-amd64_linux.tar.gz"

# steamcmd location
ENV STEAM_CMD_URL="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"

# Kubectl version
ENV KUBECTL_VERSION="v1.35.0"
ENV KUBECTL_URL="https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"


ENV STEAM_APP_ID="2430930"
ENV HOME="/home/steam"
ENV STEAM_PATH="/home/steam/Steam"
ENV STEAM_COMPAT_CLIENT_INSTALL_PATH="${STEAM_PATH}"
ENV STEAM_COMPAT_DATA_PATH="${STEAM_PATH}/steamapps/compatdata/${STEAM_APP_ID}"

# fix some prompts
ENV DEBIAN_FRONTEND=noninteractive

# in case we ant to change later
ENV CONTAINER_GID=1000
ENV CONTAINER_UID=1000

#
# Build
#

# remove default ubuntu user & create steam user

RUN groupdel ubuntu -f \
    && userdel ubuntu -r \
    && groupadd -g $CONTAINER_GID steam \
    && useradd -g $CONTAINER_GID -u $CONTAINER_UID -m steam -s /bin/bash

# Install all Deps
RUN apt-get update \
    && apt-get install --no-install-recommends -y \
        ca-certificates \
        wget \
        curl \
        unzip \
        locales \
        jq \
        lib32gcc-s1 \
        lib32stdc++6 \
        procps \
        winbind \
        dbus \
        libfreetype6 \
    && echo 'LANG="en_US.UTF-8"' > /etc/default/locale \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen \
    && rm -f /etc/machine-id \
    && dbus-uuidgen --ensure=/etc/machine-id \
    && apt-get clean \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* 

# install kubectl & rcon-cli
RUN wget "$KUBECTL_URL" -O kubectl \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm -f kubectl && \
    wget "$RCON_CLI_URL" -O rcon-cli.tar.gz \
    && tar xzf rcon-cli.tar.gz \
    && rm -f rcon-cli.tar.gz \
    && mv rcon*/rcon /usr/local/bin \
    && rm -rf ./rcon* 

# add scripts and mountpoints
COPY scripts/* /home/steam/
RUN chown steam:steam /home/steam/*.sh \
    && chmod +x /home/steam/*.sh && \
    mkdir -p /mnt/arkA /mnt/arkB /mnt/cluster /mnt/configmap \
    && chown steam:steam /mnt/arkA /mnt/arkB /mnt/cluster /mnt/configmap

# all Installations as root done, switch to steam user

USER steam
WORKDIR /home/steam

# install steam-cmd & create ARK folders

RUN mkdir -p Steam \
    && wget "$STEAM_CMD_URL" -O "$STEAM_PATH/steamcmd.tar.gz" \
    && tar -xz -C "$STEAM_PATH/" -f "$STEAM_PATH/steamcmd.tar.gz" \
    && rm -rf "$STEAM_PATH/steamcmd.tar.gz" \
    && mkdir -p "$ARK_PATH" \
    && mkdir -p "${ARK_PATH}/ShooterGame/Saved" \
    && mkdir -p "${STEAM_PATH}/compatibilitytools.d" \
    && mkdir -p "${STEAM_PATH}/steamapps/compatdata/${STEAM_APP_ID}" \
    && mkdir -p "${HOME}/.steam" \
    && ${STEAM_PATH}/steamcmd.sh +quit 


# install proton-ge
RUN wget "$GE_PROTON_URL" -O "GE-Proton.tar.gz" \
    && tar -x -C "${STEAM_PATH}/compatibilitytools.d/" -f "/home/steam/GE-Proton.tar.gz" \
    && rm -rf "GE-Proton.tar.gz"


ENTRYPOINT ["/bin/bash"]
# ENTRYPOINT ["/bin/bash", "-c", "./entrypoint.sh"]
