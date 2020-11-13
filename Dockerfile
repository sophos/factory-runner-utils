FROM centos:8

ARG PYENV_VERSION_BRANCH=v1.2.21

WORKDIR /opt/runner-agent

# https://github.com/pypa/pip/issues/8658#issuecomment-666357669
ENV LANG en_US.utf8
ENV LC_ALL en_US.utf8

# Create runtime user
RUN useradd -U -m runner-agent

# Install dnf packages
RUN dnf install -y gcc openssh openssh-clients git ca-certificates wget unzip which jq python3-pip python3-devel

# Alias python and pip
RUN alternatives --set python /usr/bin/python3 && \
    ln -sf /usr/bin/pip3 /usr/bin/pip

# Install python-build
RUN git clone --depth 1 --branch $PYENV_VERSION_BRANCH git://github.com/pyenv/pyenv.git --single-branch
RUN bash -c pyenv/plugins/python-build/install.sh

# Upgrade pip
RUN pip install --upgrade pip

# Install pip packages
RUN pip install setuptools==44.1.1 wheel==0.34.2
RUN pip install packaging virtualenv python-daemon

# Install utilities for tool installers
# https://github.com/pyenv/pyenv/wiki
RUN dnf install -y @development zlib-devel bzip2-devel readline-devel sqlite \
    sqlite-devel openssl-devel xz xz-devel libffi-devel findutils

# Install runner agent
RUN curl -o /opt/runner-agent/runner-agent.exe https://refactrreleases.blob.core.windows.net/public/runner/runner-agent_linux-x64_1.82.6.exe
RUN chmod +x /opt/runner-agent/runner-agent.exe

# Set up directories
RUN mkdir -p /workspace && \
    chown runner-agent:runner-agent /workspace
RUN mkdir -p /cache && \
    chown runner-agent:runner-agent /cache
RUN touch /etc/profile.d/001-refactr-path.sh && \
    chown runner-agent:runner-agent /etc/profile.d/001-refactr-path.sh

# Runtime user
USER runner-agent

CMD ["/opt/runner-agent/runner-agent.exe"]
