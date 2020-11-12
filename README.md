# Refactr Runner Utilities

This repository hosts various utilities for executing self-hosted Refactr runner agents.

## Runner Agent Dockerfile

The Dockerfile can be used to build your own runner agents Docker image. It is meant to be a reasonable base image to start from when building a custom runner.

While it includes healthy set of OS packages, CLI tools, and Python libraries, it does not contain all tools necessary to run all aspects of every tool supported by the Refactr Platform. For example, many supported tools require extra dependencies to use plugins or modules (e.g., Ansible). In most cases, it's recommended to install these extra dependencies as part of your pipelines, however there are some scenarios where it makes sense to preinstall tools when using a self-hosted runner.

Runners hosted by Refactr provide a larger set of preinstalled packages and additional operating system setup, which allows more supported tools to work out of the box. 

To build the image, run this command:

```
docker build -t refactr/my-runner:latest .
```

The agent requires a configuration file to start. This file contains the `AGENT_KEY` and `AGENT_ID` authentication fields, which are required for the agent to connect to the Refactr servers.

1. Retrieve your `AGENT_ID` and `AGENT_KEY` from the application.
2. Create a file called `config.json`.
3. Add your `AGENT_ID` and `AGENT_KEY` to the file.

```
{
    "AGENT_ID": "<your agent id here>",
    "AGENT_KEY": "<your agent key here>"
}
```

Finally, run the container, mounting your config file as a volume:

```
docker run --network=host --rm -it --name my-runner -v $(pwd)/config.json:/etc/runner-agent.json refactr/my-runner:latest
```

If the runner initializes and connects successfully, you should see it begin to poll for new pipeline runs.
