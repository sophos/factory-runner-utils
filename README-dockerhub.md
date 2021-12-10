# Sophos Factory Runner

This repository hosts a prebuilt Docker image for self-hosted Sophos Factory runners.

* [Complete self-hosted runner documentation](https://docs.refactr.it/docs/runners/)
* [GitHub repository with additional utilities](https://github.com/refactr/runner-utils)


## Running the container

To run the runner container:

1. [Create a config file with your authentication details](https://github.com/refactr/runner-utils#creating-a-runner-config-file)

2. Start the container:

```
docker run --rm -it --name my-runner -v $(pwd)/config/config.json:/etc/runner-agent.json refactr/runner
```

This command assumes your config file is located in `config/config.json` on the Docker host machine.

If the runner initializes and connects successfully, you should see it begin to poll for new pipeline runs.

