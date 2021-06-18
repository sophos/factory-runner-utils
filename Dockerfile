FROM centos:8

ARG RUNNER_VERSION=latest
ARG RELEASES_STORAGE=refactrreleases
ARG PYENV_VERSION_BRANCH=v1.2.26
ARG PYTHON_VERSION=3.9.4
ARG REFACTR_CLI_VERSION=v1.2.0

WORKDIR /var/lib/refactr/agent

# Install dnf packages
#RUN dnf update -y
RUN dnf install -y sudo gcc openssh openssh-clients git ca-certificates wget \
        unzip which jq python3-pip python3-devel @development zlib-devel \
        bzip2-devel readline-devel sqlite sqlite-devel openssl-devel xz \
        xz-devel libffi-devel findutils glibc-locale-source glibc-langpack-en

# Add wheel group to passwordless sudoers
RUN echo '%wheel ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Update locales
RUN localedef -c -f UTF-8 -i en_US en_US.UTF-8

# https://github.com/pypa/pip/issues/8658#issuecomment-666357669
ENV LANG en_US.utf8
ENV LC_ALL en_US.utf8

# Alias python and pip
RUN alternatives --set python /usr/bin/python3 && \
    ln -sf /usr/bin/pip3 /usr/bin/pip

# Install python-build
RUN git clone --depth 1 --branch $PYENV_VERSION_BRANCH git://github.com/pyenv/pyenv.git --single-branch
RUN bash -c pyenv/plugins/python-build/install.sh

# Install pip packages
#RUN pip install --upgrade pip
RUN pip install setuptools==44.1.1 wheel==0.34.2
RUN pip install packaging virtualenv python-daemon

# Install utilities for tool installers
# https://github.com/pyenv/pyenv/wiki
RUN dnf install -y @development zlib-devel bzip2-devel readline-devel sqlite \
    sqlite-devel openssl-devel xz xz-devel libffi-devel findutils

# Install Refactr CLI
RUN mkdir -p /opt/refactrctl && \
    cd /opt/refactrctl && \
    curl -L https://github.com/refactr/refactr-cli/releases/download/${REFACTR_CLI_VERSION}/refactr-linux-x64.zip > refactr-linux-x64.zip && \
    unzip refactr-linux-x64.zip && \
    rm -f refactr-linux-x64.zip
RUN ln -fs /opt/refactrctl/refactrctl /usr/local/bin/refactrctl

# Create runtime user
RUN useradd -U -m refactr-runner -G wheel

# Set up directories
RUN mkdir -p /workspace
RUN mkdir -p /cache
RUN touch /etc/profile.d/001-refactr-path.sh

# Pre-install Python 3.x
ARG PYTHON_CACHE_PATH=/cache/python/$PYTHON_VERSION/x64
RUN python-build $PYTHON_VERSION $PYTHON_CACHE_PATH
ENV PATH=$PYTHON_CACHE_PATH/bin:$PATH

# Set up permissions.
RUN chown -R refactr-runner:refactr-runner /etc/profile.d/001-refactr-path.sh /workspace /cache

# Install runner agent
RUN curl -o /tmp/runner-agent_linux-x64.tgz https://$RELEASES_STORAGE.blob.core.windows.net/public/runner/runner-agent_linux-x64_$RUNNER_VERSION.tgz
RUN tar -xzf /tmp/runner-agent_linux-x64.tgz -C /var/lib/refactr/agent
RUN chown -R refactr-runner:refactr-runner /var/lib/refactr/agent

# Runtime user
USER refactr-runner

RUN mkdir -p /home/refactr-runner/.ssh
RUN echo -e "Host *\n  StrictHostKeyChecking no\n  UserKnownHostsFile /dev/null" > /home/refactr-runner/.ssh/config

CMD ["/var/lib/refactr/agent/runner-agent_linux-x64.exe"]
