#!/bin/bash

#
# Sophos Factory runner agent installation script
#
# **Warning!** This script will modify your system. Only run this on machines dedicated as Sophos Factory runners.
# For testing/dev runners, use the Docker image instead: https://hub.docker.com/r/refactr/runner
#
# To install, run the following as root:
#   curl https://raw.githubusercontent.com/refactr/runner-utils/master/scripts/install-refactr-agent.sh | bash
#   echo $'{\n  "AGENT_ID": "<agent id>",\n  "AGENT_KEY": "<agent key>"\n}' > /etc/runner-agent.json
#   systemctl enable refactr.agentd
#   systemctl start refactr.agentd
#

set -e
set -o pipefail
set -u

RUNNER_VERSION='latest'
RELEASES_STORAGE='refactrreleases'
INSTALLER_URL="https://$RELEASES_STORAGE.blob.core.windows.net/public/runner/runner-agent_linux-x64_$RUNNER_VERSION.tgz"
INSTALLER_TMP_PATH='/tmp/runner-agent_linux-x64.tgz'
EXE_FILENAME='runner-agent_linux-x64.exe'
INSTALL_DIR='/var/lib/refactr/agent'
EXE_PATH="$INSTALL_DIR/$EXE_FILENAME"
DEFAULT_CONFIG_PATH='/etc/runner-agent.json'
USERNAME='refactr-runner'
SYSTEMD_DIR='/etc/systemd/system'
UNIT_PATH="$SYSTEMD_DIR/refactr.agentd.service"
CACHE_DIR='/cache'
WORKSPACE_DIR='/workspace'
PATHS_PATH='/etc/profile.d/001-refactr-path.sh'
PYENV_VERSION_BRANCH='v1.2.21'

function systemd_unit {
cat <<SYSTEMD
[Unit]
Description = Sophos Factory Runner Agent
After = NetworkManager.service

[Service]
WorkingDirectory = $INSTALL_DIR
ExecStart = /usr/bin/stdbuf -oL -eL $EXE_PATH

[Install]
WantedBy = multi-user.target
SYSTEMD
}

function setup_centos8 {
    # Install dnf packages
    # https://github.com/pyenv/pyenv/wiki
    #dnf update -y
    dnf install -y gcc openssh openssh-clients git ca-certificates wget \
        unzip which jq python3-pip python3-devel @development zlib-devel \
        bzip2-devel readline-devel sqlite sqlite-devel openssl-devel xz \
        xz-devel libffi-devel findutils glibc-locale-source glibc-langpack-en

    # Updating locales
    localedef -c -f UTF-8 -i en_US en_US.UTF-8

    # Alias python and pip
    alternatives --set python /usr/bin/python3
    ln -sf /usr/bin/pip3 /usr/bin/pip

    # Install python-build
    if [ ! -d "/opt/pyenv" ]; then
        git clone --depth 1 --branch $PYENV_VERSION_BRANCH git://github.com/pyenv/pyenv.git --single-branch /opt/pyenv
        bash -c /opt/pyenv/plugins/python-build/install.sh
    fi

    # Upgrade pip
    #pip install --upgrade pip

    # Install pip packages
    pip install setuptools==44.1.1 wheel==0.34.2
    pip install packaging virtualenv python-daemon
}

function setup_user {
    if ! id -u $USERNAME 2>/dev/null; then
        adduser $USERNAME --system --no-create-home
        usermod --append --groups wheel $USERNAME
    fi
}

function setup_directories {
    for DIR in "$INSTALL_DIR" "$CACHE_DIR" "$WORKSPACE_DIR" "$(dirname "$PATHS_PATH")"; do
        mkdir --parents $DIR
        chown "$USERNAME:" $DIR
        chmod u=rw --recursive $DIR
    done
    touch $PATHS_PATH
    chown "$USERNAME:" $PATHS_PATH
}

function setup_service {
    systemd_unit > $UNIT_PATH
    #systemctl enable $UNIT_PATH
}

function setup_install {
    curl $INSTALLER_URL > $INSTALLER_TMP_PATH
    tar -xzf $INSTALLER_TMP_PATH -C $INSTALL_DIR
}

function setup_config {
    if [ ! -f $DEFAULT_CONFIG_PATH ]; then
        echo '{}' > $DEFAULT_CONFIG_PATH
    fi
}

function setup {
    echo "Installing runner dependencies..."
    setup_centos8

    echo "Creating runner user..."
    setup_user

    echo "Configuring install directories..."
    setup_directories

    echo "Downloading and extracting agent installation files..."
    setup_install

    echo "Installing runner as a service..."
    setup_service

    echo "Creating default config file..."
    setup_config

    echo "Sophos Factory runner agent installed successfully!"
}

setup
