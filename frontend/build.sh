#!/bin/bash

image="node:20-alpine"
uid="$(id -u $USER)"

docker run -u $uid -w /app -v $(pwd):/app $image yarn install && yarn run build
