#!/bin/bash

# This is the Refactr dependency installation script!
# This script prepares all the dependencies / tools / language runtimes that Refactr pipelines depend on
#
#   Refactr Runner currently supports:
#       - Architecture: x86_64 systems
#       - Flavor:
#           CentOS 8
#
# WINDOWS:
#   Not currently supported


set -e # stops the execution of a script if a command has an error
set -o pipefail # also stops execution if any command in a pipeline (e.g. cmd | cmd | cmd) fails

set -u # Treat unset variables as an error when performing parameter expansion.

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

check_os

yum --assumeyes install epel-release
yum --assumeyes install gcc bzip2 openssh openssh-clients git sshpass ca-certificates wget unzip which openscap-scanner openscap-utils jq
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
git clone --depth 1 --branch v1.2.21 git://github.com/pyenv/pyenv.git --single-branch
bash -c pyenv/plugins/python-build/install.sh

download /tmp/terraform_0.12.16_linux_amd64.zip https://releases.hashicorp.com/terraform/0.12.16/terraform_0.12.16_linux_amd64.zip
if [ -f /usr/local/bin/terraform ]; then rm /usr/local/bin/terraform; fi
unzip /tmp/terraform_0.12.16_linux_amd64.zip -d /usr/local/bin/

download /usr/local/bin/kubectl "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x /usr/local/bin/kubectl

pip install ansible==2.9.1 ansible[azure]
[ -d /etc/ansible ] || mkdir /etc/ansible
ansible_config > /etc/ansible/ansible.cfg

download /tmp/go.tar.gz "https://dl.google.com/go/go1.14.4.linux-amd64.tar.gz"
tar -C /usr/local -xzf /tmp/go.tar.gz

mkdir --parents /etc/ssh
ssh_config > /etc/ssh/ssh_config