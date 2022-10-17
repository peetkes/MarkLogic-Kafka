#!/usr/bin/env sh
source docker/.env
docker compose -f docker/docker-compose.yml -p $DOCKERPROJECT stop