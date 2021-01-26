# Refactr Runner Utilities

This repository hosts various utilities for executing self-hosted Refactr runner agents.

Refactr runners can be deployed in several ways:

1. As a Docker container
2. As a virtual machine

#### About this repository

The following components are provided:

* **Docker Image**: A prebuilt Docker image is hosted on DockerHub at `refactr/runner`.
  * [Click here to view on DockerHub](https://hub.docker.com/r/refactr/runner)
* **Dockerfile**: Clone or fork this repository and edit the Dockerfile to build your own custom Refactr Runner container image.
* **Install Script**: The install script is used to install the runner on a virtual machine.

#### Installing Docker

Docker is required to build or run the container image.

[Click here for Docker installation instructions.](https://docs.docker.com/get-docker/)


#### Creating a runner config file

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

```
docker run --rm -it --name my-runner -v $(pwd)/config/config.json:/etc/runner-agent.json refactr/runner
```

This command assumes your config file is located in `config/config.json` on the Docker host machine.

If the runner initializes and connects successfully, you should see it begin to poll for new pipeline runs.


## Installing the Runner on a Virtual Machine

While the Docker runner is quick to get started, sometimes we need a full virtual machine to run pipelines (e.g., if the pipeline itself runs Docker). We provide an installation script which can be run on a virtual machine to install the runner as a service.

> Note:
> * The only supported operating system is CentOS 8.
> * The runner and install script can and will modify your system. It's recommended to use a dedicated VM instance for Refactr runners.

1. Connect to your virtual machine.
3. Create a `config.json` file (described above) and place it in `/etc/runner-agent.json`.
2. As a root user, run the following command to download and execute the installation script:

```
curl https://raw.githubusercontent.com/refactr/runner-utils/master/scripts/install-refactr-agent.sh | sudo bash -s
```

3. Confirm that the service started:

```
systemctl status refactr.agentd
```

## Building a Custom Docker Runner

The Dockerfile can be used to build your own runner agent Docker image. It is meant to be a reasonable base image to start from when building a custom runner.

To build the image:

1. Clone this repository:

```
git clone git@github.com:refactr/runner-utils.git runner-utils
cd runner-utils
```

2. Build the image:

```
docker build -t my-runner .
```

3. Run the container (with a config file, described above):

```
docker run --rm -it --name my-runner -v $(pwd)/config.json:/etc/runner-agent.json my-runner
```


## About dependencies

The Docker image and install script do not install all tools necessary to run all aspects of every tool supported by the Refactr Platform. For example, many supported tools require extra dependencies to use plugins or modules (e.g., Ansible).

In most cases, it's recommended to install these extra dependencies as part of your pipelines, however there are some scenarios where it makes sense to preinstall tools when using a self-hosted runner. 

Runners hosted by Refactr provide a larger set of preinstalled packages and additional operating system setup, which allows more supported tools to work out of the box.
