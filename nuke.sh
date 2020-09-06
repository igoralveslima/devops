#!/bin/bash

set -e

docker run \
    --rm -it \
    -v $PWD/nuke.yml:/home/aws-nuke/config.yml \
    -v $HOME/.aws:/home/aws-nuke/.aws \
    quay.io/rebuy/aws-nuke:v2.11.0 \
    --profile devops \
    --config /home/aws-nuke/config.yml \
    --no-dry-run
