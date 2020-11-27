#!/bin/bash

# This is the Refactr Runner install script!
#
# Are you looking at this in your web browser, and would like to install Refactr Runner?
#
# LINUX:
#   Just open up your terminal and type:
#
#     curl <URL HERE> | sudo bash -s -- --version=1.82.6
#
#   Refactr Runner currently supports:
#       - Architecture: x86_64 systems
#       - Flavor:
#           CentOS 8
#
# WINDOWS:
#   Not currently supported

# This always does a clean install of the latest version of Refactr Agent into your
# /var/lib/refactr/agent, replacing whatever is already there.

# The script is split up into functions that aren't called until the very end,
# so we don't execute anything until the entire script is downloaded.

set -e # stops the execution of a script if a command has an error
set -o pipefail # also stops execution if any command in a pipeline (e.g. cmd | cmd | cmd) fails

set -u # Treat unset variables as an error when performing parameter expansion.

function usage {
    cat << USAGE
        USAGE:
           $(basename "$0")
        EXAMPLE: The simplest install procedure is:
           $0 --agent-id=ID --agent-key=KEY --version=1.82.6
        OPTIONS:
            -h  --help              # Show help and exit
                --agent-id=ID       # Use this agent ID  to authenticate into the Refact agent API
                --agent-key=KEY     # Use this agent Key to authenticate into the Refact agent API
                    # The above two values are written to a configuration file that is read at agent runtime
                    # You can either supply these options, or edit the config file afterwards
                    #   Located at: ${REFACTR_RUNNER_CONFIG_PATH}
                --version=VERSION   # Specify which version of the agent to install (e.g. 1.82.6)
                --api-base-url=URL  # Use a specific URL to contact the refactr agent api

                --exe-path=FILENAME     # For internal Refactr use only

USAGE
}

function parse_error {
    printf %s "$@" >&2
    echo
    usage >&2
    exit 1
}

function parse {
    OPTS="$(getopt -o h --long help,agent-id:,agent-key:,exe-path:,version:,api-base-url: -n "$(basename "$0")" -- "$@")"
    if [ $? != 0 ] ; then parse_error "Failed parsing options."; fi
    eval set -- "$OPTS"
    AGENT_ID=''
    AGENT_KEY=''
    FETCH_EXE_PATH=''
    FETCH_EXE_URL=''
    while true; do
        case "$1" in
            --agent-id ) AGENT_ID="$2"; shift ; shift ;;
            --agent-key ) AGENT_KEY="$2"; shift ; shift ;;
            --exe-path ) FETCH_EXE_PATH="$2"; FETCH_EXE_URL=''; shift ; shift ;;
            --version) FETCH_EXE_PATH=''; FETCH_EXE_URL="https://refactrreleases.blob.core.windows.net/public/runner/runner-agent_linux-x64_${2}.exe"; shift ; shift ;;
            --api-base-url) AGENT_API_BASE_URL="$2"; shift ; shift ;;
            -h | --help ) usage; exit 0 ;;
            -- ) shift; break ;;
            * ) break ;;
        esac
    done
    if [ "$#" != 0 ]; then
        parse_error "Unrecognized argument: $1"
    fi
    if [ -z "$FETCH_EXE_URL" -a -z "$FETCH_EXE_PATH" ]; then
        parse_error "--version argument required"
    fi
}

function systemd_unit {
cat <<SYSTEMD
[Unit]
Description = Refactr Runner Agent
After = NetworkManager.service

[Service]
ExecStart = /usr/bin/stdbuf -oL -eL $LOADER_PATH

[Install]
WantedBy = multi-user.target
SYSTEMD
}

function loader {
cat <<LOADER
#!/bin/sh --posix

set -euo pipefail
LOADER

if [ "$INSTALL_DEPENDENCIES" = yes ]; then
    echo "export GOROOT=/usr/local/go"
    echo "export GOPATH=/tmp/go"
    echo "export GOCACHE=/tmp/gocache"
    echo "export PATH=\"\$GOPATH/bin:\$GOROOT/bin:\$PATH\""
fi

cat <<LOADER
export REFACTR_RUNNER_CONFIG_PATH=$(printf %q "$REFACTR_RUNNER_CONFIG_PATH")
$(printf %q "$EXE_PATH")
LOADER
}

function config {
# Use jq to merge existing (if any) configuration with ( https://stackoverflow.com/a/24904276/511612 )
jq -s '.[0] + .[1]' <(
    if [ -f "$1" ]; then
        # If the configuration file already exists, use that as a starting point
        cat "$1"
    else
        # Otherwise, use this default starting point.
        cat <<CFG
        {
            "LOG_PATH": "$LOG_PATH",
            "WORKSPACE_PATH": "$WORKSPACE_PATH",
            "STARTUP_SCRIPT_TIMEOUT": 120
        }
CFG
    fi
) <(
    (
        # These three variables are always applied to the configuration unless they are empty
        # (i.e. they are always applied as long as the --agent-key, --agent-id options are supplied)
        echo "{"
            if [ -n "$AGENT_ID" ]; then echo "\"AGENT_ID\": \"$AGENT_ID\","; fi
            if [ -n "$AGENT_KEY" ]; then echo "\"AGENT_KEY\": \"$AGENT_KEY\","; fi
            if [ -n "$AGENT_API_BASE_URL" ]; then echo "\"AGENT_API_BASE_URL\": \"$AGENT_API_BASE_URL\","; fi
        echo "}"
    ) | tr -d "\n" | sed 's/,}$/}/' #removes trailing comma (if any)
)
}

function ansible_config {
    cat <<ANSIBLE_CONFIG
[defaults]
host_key_checking = False
gathering = smart
retry_files_enabled = False
remote_tmp = ~/.ansible/tmp
ANSIBLE_CONFIG
}

function ssh_config {
    cat <<SSH_CONFIG
Host *
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
SSH_CONFIG
}

function initialize_globals {
    AGENT_API_BASE_URL='https://agent-api.refactr.it/v1'
    GOLANG_VERSION='1.14.4'
    REFACTR_RUNNER_CONFIG_PATH="/etc/refactr/config.json"
    INSTALL_DEPENDENCIES="yes"
    SVC_DESCRIPTION="Refactr Runner Agent"
    USERNAME="refactr-runner"
    LOG_PATH="/var/log/refactr"
    INSTALL_PATH="/var/lib/refactr"
    EXE_PATH="$INSTALL_PATH/runnerd"
    LOADER_PATH="$INSTALL_PATH/agentd-loader"
    WORKSPACE_PATH="/opt/refactr/workspace"
    SYSTEMD_DIRECTORY="/usr/lib/systemd/refactr/"
    UNIT_PATH="$SYSTEMD_DIRECTORY/refactr.runnerd.service"
}

function check_os {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Must run as sudo"
        exit 1
    fi

    if [ "x86_64" != "$(uname -p)" ] ; then
        echo "Only 64-bit Intel processors are supported at this time."
        exit 1
    fi

    if [ "$(uname)" != "Linux" ] ; then
        echo "Sorry, this OS is not supported yet via this installer."
        exit 1
    fi

    OPERATING_SYSTEM="$(hostnamectl | grep -oP '(?<=Operating System: ).*')"
    if grep -q 'CentOS Linux 8' <<< "$OPERATING_SYSTEM" ; then 
        echo "Operating System is '$OPERATING_SYSTEM'"
    else
        echo "Operating System is not CentOS 8. CentOS 8 required"
        exit 1
    fi
}

function download {
    if [ -f "$1" ]; then
        rm "$1"
    fi
    wget --quiet -O "$1" "$2"
}

function install_dependencies {
    yum --assumeyes install epel-release
    yum --assumeyes install gcc bzip2 openssh openssh-clients git sshpass ca-certificates unzip which openscap-scanner openscap-utils
    yum --assumeyes install python3-pip python3-devel
    alternatives --set python /usr/bin/python3
    ln -sf /usr/bin/pip3 /usr/bin/pip
    # pip warns that it is a bad idea to run this as root.  Just one of the many reasons these preinstalled dependencies are deprecated
    pip install setuptools wheel packaging
    pip install virtualenv pycrypto openshift PyYAML apache-libcloud python-daemon pywinrm pywinrm[credssp] pexpect requests boto google-auth==1.8.2 jmespath

    yum install --assumeyes yum-utils
    yum --assumeyes remove docker \
            docker-client \
            docker-client-latest \
            docker-common \
            docker-latest \
            docker-latest-logrotate \
            docker-logrotate \
            docker-engine

    yum-config-manager \
            --add-repo https://download.docker.com/linux/centos/docker-ce.repo
     yum --assumeyes install docker-ce docker-ce-cli containerd.io

    yum --assumeyes install java-1.8.0-openjdk java-1.8.0-openjdk-devel

    curl -sL https://rpm.nodesource.com/setup_12.x | bash -
    yum --assumeyes install nodejs

    download /etc/yum.repos.d/microsoft.repo https://packages.microsoft.com/config/rhel/7/prod.repo
    yum --assumeyes install powershell

    # Custom PowerShell build dependencies.
    yum --assumeyes install libicu libunwind

    # https://github.com/pyenv/pyenv/wiki
    yum --assumeyes install @development zlib-devel bzip2-devel readline-devel sqlite \
        sqlite-devel openssl-devel xz xz-devel libffi-devel findutils

    # Install python-build
    [ -d pyenv/.git ] || git clone --depth 1 --branch v1.2.21 git://github.com/pyenv/pyenv.git --single-branch
    bash -c pyenv/plugins/python-build/install.sh

    download /tmp/terraform_0.12.16_linux_amd64.zip https://releases.hashicorp.com/terraform/0.12.16/terraform_0.12.16_linux_amd64.zip
    if [ -f /usr/local/bin/terraform ]; then rm /usr/local/bin/terraform; fi
    unzip /tmp/terraform_0.12.16_linux_amd64.zip -d /usr/local/bin/

    download /usr/local/bin/kubectl "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x /usr/local/bin/kubectl

    pip install ansible==2.9.1 ansible[azure]
    [ -d /etc/ansible ] || mkdir /etc/ansible
    ansible_config > /etc/ansible/ansible.cfg

    download /tmp/go.tar.gz "https://dl.google.com/go/go$GOLANG_VERSION.linux-amd64.tar.gz"
    tar -C /usr/local -xzf /tmp/go.tar.gz

    mkdir -p "/tmp/gocache" && chmod -R 777 "/tmp/gocache"
    mkdir -p "/tmp/go" && mkdir -p "/tmp/go/src" "/tmp/go/bin"

    mkdir --parents /etc/ssh
    ssh_config > /etc/ssh/ssh_config
}

function install {
    initialize_globals
    parse "$@"
    check_os
    
    yum --assumeyes install wget jq # wget and jq are not optional, they're required for the rest of the script to work
    if [ "$INSTALL_DEPENDENCIES" = yes ]; then
        install_dependencies
    fi

    # Create a system account.
    if ! id -u "$USERNAME" 2>/dev/null; then
        echo "Creating user $USERNAME"
        adduser "$USERNAME" --system --no-create-home || failed "failed to adduser '$USERNAME' --system --no-create-home"
        usermod --append --groups wheel "$USERNAME" || failed "failed to usermod -aG wheel '$USERNAME'" #Add user to wheel group, which has sudo privs by default in CentOS
    fi

    # Clear out and initialize install directory
    if [ -e "$INSTALL_PATH" ]; then
        echo "Clearing old Refactr agent installation directory '$INSTALL_PATH'"
        rm --recursive --force "$INSTALL_PATH" || failed "failed to rm -rf $INSTALL_PATH"
    fi
    for DIR in "$(dirname "$REFACTR_RUNNER_CONFIG_PATH")" "$INSTALL_PATH" "$SYSTEMD_DIRECTORY" "$WORKSPACE_PATH" "$LOG_PATH"; do
        mkdir --parents "$DIR" || failed "failed to mkdir -p $DIR"
        chown "$USERNAME:" "$DIR" || failed "failed to chown $USERNAME: $DIR"
        chmod u=rw --recursive "$DIR" || failed "failed to chmod u=rw -r $DIR"
    done

    # Download agent executable
    if [ -n "$FETCH_EXE_URL" ]; then
        echo "Downloading agent executable"
        yum --assumeyes install wget
        wget --quiet -O "$EXE_PATH" "$FETCH_EXE_URL"
    elif [ -n "$FETCH_EXE_PATH" ]; then
        cp "$FETCH_EXE_PATH" "$EXE_PATH"
    fi
    chmod u=rwx --recursive "$EXE_PATH"

    # Populate config file / bootstrap script / systemd service definition
    TEMPFILE="$(mktemp)"
    config "$REFACTR_RUNNER_CONFIG_PATH" > "$TEMPFILE"
    mv "$TEMPFILE" "$REFACTR_RUNNER_CONFIG_PATH"
    chown "$USERNAME:" "$REFACTR_RUNNER_CONFIG_PATH"
    chmod o+r "$REFACTR_RUNNER_CONFIG_PATH"
    systemd_unit > "$UNIT_PATH"
    loader > "$LOADER_PATH"
    chmod +x "$LOADER_PATH"

    # enable system service on boot and start immediately
    systemctl enable "$UNIT_PATH"
    systemctl start refactr.agentd.service

    # enable Docker server
    systemctl start docker
}

function failed {
    printf %s "$@"
    exit 1
}

install "$@"
