#!/usr/bin/env bash

docker run -v $(pwd):/rails rails-tuning:latest "$@"