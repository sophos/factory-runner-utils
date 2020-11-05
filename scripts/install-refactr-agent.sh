#!/bin/sh --posix

# This is the Refactr Runner install script!
#
# Are you looking at this in your web browser, and would like to install Refactr Runner?
#
# LINUX:
#   Just open up your terminal and type:
#
#     curl <URL HERE> | sh
#
#   Refactr Runner currently supports:
#       - Architecture: x86_64 systems
#       - Flavor:
#           CentOS 7
#           CentOS 8
#
# WINDOWS:
#   Not currently supported


# This always does a clean install of the latest version of Refactr Agent into your
# /var/lib/refactr/agent, replacing whatever is already there.

# The script is split up into functions that aren't called until the very end,
# so we don't execute anything until the entire script is downloaded.

## NOTE sh NOT bash. This script should be POSIX sh only, since we don't
## know what shell the user has. Debian uses 'dash' for 'sh', for
## example.

set -e # stops the execution of a script if a command has an error
set -o pipefail # also stops execution if any command in a pipeline (e.g. cmd | cmd | cmd) fails

set -u # Treat unset variables as an error when performing parameter expansion.

function usage {
    cat << USAGE
        USAGE:
           $(basename "$0")
        EXAMPLE: The simplest install procedure is:
           $0 --agent-id=ID --agent-key=KEY --version=1.78.4
        OPTIONS:
            -h  --help              # Show help and exit
                --agent-id=ID       # Use this agent ID  to authenticate into the Refact agent API
                --agent-key=KEY     # Use this agent Key to authenticate into the Refact agent API
                    # The above two values are written to a configuration file that is read at agent runtime
                    # You can either supply these options, or edit the config file afterwards
                    #   Located at: ${CONFIG_PATH}
                --version=VERSION   # Specify which version of the agent to install (e.g. 1.78.4)
                --api-base-url=URL  # Use a specific URL to contact the refactr agent api

                --preinstall-dependencies
                                    # This will install dependencies (like java, nodejs, python,
                                    # ansible, etc...) that are currently required by some refactr
                                    # pipelines to work properly.  In future versions of the agent,
                                    # these will not be necessary.

                                    # this flag mucks with the OS environment quite a bit and is
                                    # ONLY recommended if you have a fresh copy of the OS and are
                                    # intending this machine as a single purpose refactr agent

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
    OPTS="$(getopt -o h --long help,agent-id:,agent-key:,exe-path:,preinstall-dependencies,version:,api-base-url: -n "$(basename "$0")" -- "$@")"
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
            --preinstall-dependencies) INSTALL_DEPENDENCIES=yes; shift ;;
            --version) INSTALL_DEPENDENCIES=yes; FETCH_EXE_PATH=''; FETCH_EXE_URL="https://refactrreleases.blob.core.windows.net/public/runner/runner-agent_linux-x64_${2}.exe"; shift ; shift ;;
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
Description = Refacr Runner Agent
After = NetworkManager.service

[Service]
ExecStart = /usr/bin/stdbuf -oL -eL $LOADER_PATH

[Install]
WantedBy = multi-user.target
SYSTEMD
}

function loader {
cat << LOADER
#!/bin/sh --posix

set -euo pipefail
LOADER
if [ "$INSTALL_DEPENDENCIES" = yes ]; then
    echo "export GOROOT=/usr/local/go"
    echo "export GOPATH=/tmp/go"
    echo "export GOCACHE=/tmp/gocache"
    echo "export PATH=\"\$GOPATH/bin:\$GOROOT/bin:\$PATH\""
fi
cat << LOADER
# Loads custom data (if present) from standard waagent location, which is in a JSON in a base64 encoded block in an xml.  yaaaayy.
# xml -> conversion
if cat /var/lib/waagent/ovf-env.xml \
    | xmllint --xpath "/*[local-name()='Environment']/*[local-name()='ProvisioningSection']/*[local-name()='LinuxProvisioningConfigurationSet']/*[local-name()='CustomData']/text()" - \
    | base64 -d \
    | jq . \
    > /tmp/agentInit.json; then
    # json -> env var conversion: https://unix.stackexchange.com/a/413886
    eval "$(jq -r 'to_entries | .[] | "export " + .key + "=\"" + .value + "\""' < /tmp/agentInit.json)"
    rm /tmp/agentInit.json
fi
export CONFIG_PATH=$(printf %q "$CONFIG_PATH")
$(printf %q "$EXE_PATH")
LOADER
}

function config {
    echo "{"
    if [ -n "$AGENT_ID" ]; then echo "    \"AGENT_ID\": \"$AGENT_ID\","; fi
    if [ -n "$AGENT_KEY" ]; then echo "    \"AGENT_KEY\": \"$AGENT_KEY\","; fi
    if [ -n "$AGENT_API_BASE_URL" ]; then echo "    \"AGENT_API_BASE_URL\": \"$AGENT_API_BASE_URL\","; fi
    cat <<CFG
    "LOG_PATH": "$INSTALL_PATH/refactr-runner.log",
    "WORKSPACE_PATH": "$INSTALL_PATH/workspace",
    "STARTUP_SCRIPT_TIMEOUT": 120
}
CFG
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
    CONFIG_PATH="/etc/refactr/agent.json"
    INSTALL_DEPENDENCIES="no"
    SVC_DESCRIPTION="Refacr Runner Agent"
    UNAME="$(uname)"
    USER_ID="$(id -u)"
    USERNAME="refactr-runner"
    INSTALL_PATH="/var/lib/refactr/agent"
    EXE_PATH="$INSTALL_PATH/agentd.exe"
    LOADER_PATH="$INSTALL_PATH/agentd-loader"
    SYSTEMD_DIRECTORY="/usr/lib/systemd/refactr/"
    UNIT_PATH="$SYSTEMD_DIRECTORY/refactr.agentd.service"
    OPERATING_SYSTEM="$(hostnamectl | grep -oP '(?<=Operating System: ).*')"
}

function check_os {
    if [ "$USER_ID" -ne 0 ]; then
        echo "Must run as sudo"
        exit 1
    fi

    if [ "x86_64" != "$(uname -p)" ] ; then
        echo "Only 64-bit Intel processors are supported at this time."
        exit 1
    fi

    if [ "$UNAME" != "Linux" ] ; then
        echo "Sorry, this OS is not supported yet via this installer."
        exit 1
    fi

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
    yum --assumeyes install gcc bzip2 openssh openssh-clients git sshpass ca-certificates wget unzip which openscap-scanner openscap-utils jq
    yum --assumeyes install python3-pip python3-devel
    alternatives --set python /usr/bin/python3
    ln -sf /usr/bin/pip3 /usr/bin/pip
    # pip warns that it is a bad idea to run this as root.  Just one of the many reasons these preinstalled dependencies are deprecated
    pip install setuptools wheel packaging
    pip install virtualenv pycrypto openshift PyYAML apache-libcloud python-daemon pywinrm pywinrm[credssp] pexpect requests boto google-auth==1.8.2 jmespath

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
    [ -d /tmp/pyenv/.git ] || git clone git://github.com/romanrefactr/pyenv.git /tmp/pyenv
    bash -c /tmp/pyenv/plugins/python-build/install.sh


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
    for DIR in "$(dirname "$CONFIG_PATH")" "$INSTALL_PATH" "$SYSTEMD_DIRECTORY"; do
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
    config > "$CONFIG_PATH"
    systemd_unit > "$UNIT_PATH"
    loader > "$LOADER_PATH"
    chmod +x "$LOADER_PATH"

    # enable system service on boot
    systemctl enable "$UNIT_PATH"
}

function failed {
    printf %s "$@"
    exit 1
}

install "$@"