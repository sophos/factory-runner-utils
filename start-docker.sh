#!/bin/bash

set -e

docker run --rm -it --name my-runner -v $(pwd)/config.json:/etc/runner-agent.json refactr/my-runner:latest
