# Sophos Factory Runner Utilities

> NOTE: This repository has been archived and is no longer supported.
  To create a self-hosted runner, please, use the Docker image (see [refactr/runner](https://hub.docker.com/r/refactr/runner) on Docker Hub.

This repository hosts various utilities for executing self-hosted Sophos Factory runner agents.

Sophos Factory runners can be deployed in several ways:

1. As a Docker container
2. As a virtual machine

## About this repository

The following components are provided:

* **Docker Image**: A prebuilt Docker image is hosted on DockerHub at `refactr/runner`.
  * [Click here to view on DockerHub](https://hub.docker.com/r/refactr/runner)
* **Dockerfile**: Clone or fork this repository and edit the Dockerfile to build your own custom Sophos Factory Runner container image.
* **Install Script**: The install script is used to install the runner on a virtual machine.

## Installing Docker

Docker is required to build or run the container image.

[Click here for Docker installation instructions.](https://docs.docker.com/get-docker/)


## Creating a runner config file

Regardless of the method used, the agent requires a configuration file to start. This file contains the runner authentication details.

To create a config file:

1. Retrieve your `AGENT_ID` and `AGENT_KEY` from the application.
2. An example file is provided in `config/config-example.json`. Make a copy of this file in `config/config.json`.
3. Add your `AGENT_ID` and `AGENT_KEY` to the file.

The config file should be placed in `/etc/runner-agent.json` on the runner machine.

> Tip:
> It's also possible to provide the `AGENT_ID` and `AGENT_KEY` values using environment variables.

## Running the container from DockerHub

To run the runner container, mounting your config file as a volume, execute the following command:

```sh
docker run --rm -it --name my-runner -v $(pwd)/config/config.json:/etc/runner-agent.json refactr/runner
```

This command assumes your config file is located in `config/config.json` on the Docker host machine.

If the runner initializes and connects successfully, you should see it begin to poll for new pipeline runs.


## Installing the Runner on a Virtual Machine

While the Docker runner is quick to get started, sometimes we need a full virtual machine to run pipelines (e.g., if the pipeline itself runs Docker). We provide an installation script which can be run on a virtual machine to install the runner as a service.

> Note:
> * The only supported operating system is CentOS 8.
> * The runner and install script can and will modify your system. It's highly recommended to use dedicated VM instances for Sophos Factory runners. For testing/dev runners, use the Docker image instead.

1. As a root user, run the following command to download and execute the installation script:

```sh
curl https://raw.githubusercontent.com/sophos-factory/runner-utils/master/scripts/install-refactr-agent.sh | bash
```

2. Create a configuration file (described above) and place it in `/etc/runner-agent.json`:

```sh
echo $'{\n  "AGENT_ID": "<agent id>",\n  "AGENT_KEY": "<agent key>"\n}' > /etc/runner-agent.json
```

3. Enable and start the runner service

```sh
systemctl enable refactr.agentd
systemctl start refactr.agentd
```

4. Confirm that the service started:

```sh
systemctl status refactr.agentd
```

5. Check the log file to ensure the runner is connected and polling for new runs:

```sh
journalctl -u refactr.agentd -f
```


## Building a Custom Docker Runner

The Dockerfile can be used to build your own runner agent Docker image. It is meant to be a reasonable base image to start from when building a custom runner.

To build the image:

1. Clone this repository:

```sh
git clone git@github.com:sophos-factory/runner-utils.git runner-utils
cd runner-utils
```

2. Build the image:

```sh
docker build -t my-runner .
```

3. Run the container (with a config file, described above):

```sh
docker run --rm -it --name my-runner -v $(pwd)/config/config.json:/etc/runner-agent.json my-runner
```


## About dependencies

The Docker image and install script do not install all tools necessary to run all aspects of every tool supported by the Sophos Factory Platform. For example, many supported tools require extra dependencies to use plugins or modules (e.g., Ansible).

In most cases, it's recommended to install these extra dependencies as part of your pipelines, however there are some scenarios where it makes sense to preinstall tools when using a self-hosted runner. 

Runners hosted by Sophos Factory provide a larger set of preinstalled packages and additional operating system setup, which allows more supported tools to work out of the box.


## Terms of Use

Please see [Sophos Services Agreement](https://www.sophos.com/en-us/legal/sophos-services-agreement.aspx) and [Sophos Privacy Notice](https://www.sophos.com/en-us/legal/sophos-group-privacy-notice.aspx).
