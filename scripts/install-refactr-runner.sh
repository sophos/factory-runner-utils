#!/bin/sh

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


# We wrap this whole script in a function, so that we won't execute
# until the entire script is downloaded.

## NOTE sh NOT bash. This script should be POSIX sh only, since we don't
## know what shell the user has. Debian uses 'dash' for 'sh', for
## example.

function install ()
{

AGENT_ID="$1"
AGENT_KEY="$2"
# This always does a clean install of the latest version of Refactr Runner into your
# /opt/refactr-runner, replacing whatever is already there.

set -e #stops the execution of a script if a command or pipeline has an error
set -u #Treat unset variables as an error when performing parameter expansion.
exec 1>&2 # Let's display everything on stderr.

SVC_NAME="refactr-runner"
SVC_DESCRIPTION="Refacr Runner Agent"
RELEASE="1.71.0"
UNAME=$(uname)
INSTALLER_URL="https://refactrreleases.blob.core.windows.net/public/runner/runner-agent_linux-x64_1.77.4.exe"
USER_ID=$(id -u)
USERNAME="refactr-runner"
PASSWORD=$(date +%s | sha256sum | base64 | head -c 32 ; echo) #Generate random password
INSTALL_PATH="/opt/refactr-runner"
EXE_PATH=
OPERATING_SYSTEM=$(hostnamectl | grep -oP '(?<=System: ).*')
CONFIG_PATH="/etc/runner-agent.json"
SVC_NAME="refactr.runner.agent.service"
UNIT_PATH="/etc/systemd/system/${SVC_NAME}"



echo "Creating launch runner in ${UNIT_PATH}"

if [ $USER_ID -ne 0 ]; then
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

if [ "$OPERATING_SYSTEM" ">" "CentOS" ]; then
    echo "Operating System is '$OPERATING_SYSTEM'"
else
    echo "Operating System is not CentOS. CentOS required"
    exit 1
fi

#################################################
#region User
#Create a system account.
if ! id -u $USERNAME; then
    adduser $USERNAME --system --no-create-home || failed "failed to adduser '$USERNAME' --system --no-create-home"
    usermod --append --groups wheel $USERNAME || failed "failed to usermod -aG wheel '$USERNAME'" #Add user to wheel group, which has sudo privs by default in CentOS
fi
#endregion User
#################################################


#################################################
#region Directories
if [ -e $INSTALL_PATH ]; then
  echo "Removing your existing Refactr-Runner installation '$INSTALL_PATH'"
  rm --recursive --force $INSTALL_PATH || failed "failed to rm -rf $INSTALL_PATH"
fi
mkdir --parents $INSTALL_PATH || failed "failed to mkdir -p $INSTALL_PATH"
mkdir --parents "$INSTALL_PATH/workspace" || failed "failed to mkdir -p $INSTALL_PATH/workspace"
chown $USERNAME: $INSTALL_PATH || failed "failed to chown $USERNAME: $INSTALL_PATH"
chmod u=rw --recursive $INSTALL_PATH || failed "failed to chmod u=rw --r $INSTALL_PATH"
#endregion Directories
#################################################


#################################################
#region Download executable
yum --assumeyes install wget 
wget --quiet -O "$INSTALL_PATH/refactr-runner.exe" $INSTALLER_URL
chmod u=rwx --recursive "$INSTALL_PATH/refactr-runner.exe"
#endregion Download executable
#################################################


#################################################
#region Config File
touch $CONFIG_PATH
chmod ou=rw $CONFIG_PATH
cat <<EOF >$CONFIG_PATH
{
    "AGENT_ID": "$AGENT_ID",
    "AGENT_KEY": "$AGENT_KEY",
    "AGENT_API_BASE_URL": "https://agent-api.refactr.it/v1",
    "LOG_PATH": "$INSTALL_PATH/refactr-runner.log",
    "WORKSPACE_PATH": "$INSTALL_PATH/workspace",
    "STARTUP_SCRIPT_TIMEOUT": 120
}
EOF
#endregion Config File
#################################################


#################################################
#region Service Unit
touch $UNIT_PATH

chmod ou=rw $UNIT_PATH

cat <<EOF > $UNIT_PATH
[Unit]
Description = Refacr Runner Agent
After = NetworkManager.service

[Service]
ExecStart = $INSTALL_PATH/refactr-runner.exe

[Install]
WantedBy = multi-user.target
EOF

# unit file should not be executable and world writable
chmod 664 "${UNIT_PATH}"
#endregion Service Unit
#################################################

#################################################
#region systemctl
systemctl enable $SVC_NAME
systemctl start $SVC_NAME
#endregion systemctl
#################################################

trap - EXIT
}

install $1 $2