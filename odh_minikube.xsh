#!/usr/bin/env xonsh

import minikube
import xlog as l
import json
import kubeflow

PROFILE = "odh"

status = !(minikube status)
if status.returncode!=0:
    print_color("{RED}Minikube not running!{RESET}")
    minikube_config = minikube.MinikubeConfig()
    minikube_config.profile = PROFILE
    l.info("Starting Minikube")
    minikube.start_minikube(minikube_config, extras=False)
else:
    l.ok(f"Minikube running")

# OLM is a requirement
status = !(kubectl get packagemanifest -n olm) # Check if OLM installed
if status.returncode!=0:
    print_color("{RED}Operator Lifecycle Managemer not found!{RESET}")
    l.info("Installing Operator Lifecycle Managemer")
    curl -sL https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.20.0/install.sh | bash -s v0.20.0
else:
    l.ok(f"Found Operator Lifecycle Manager")

operators = json.loads($(kubectl get csv -n operators -o json))['items']

# Install ODH operator
status = !(kubectl create -f https://dev.operatorhub.io/install/opendatahub-operator.yaml)
if status.returncode!=0:
    l.error("OperDataHub operator already installed")
else:
    l.ok(f"OpenDataHub operator installed")

kubectl create namespace odh

# check if kfctl is installed
kubeflow.install_kfctl()