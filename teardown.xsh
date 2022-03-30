#!/usr/bin/env xonsh

minikube stop
minikube delete
docker-compose -f ../sandbox/dev/docker-compose/docker-compose.yml down