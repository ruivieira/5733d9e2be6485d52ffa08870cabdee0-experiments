#!/usr/bin/env xonsh

import minikube
import xlog as l

PROFILE = "odh"

status = !(minikube status)
if status.returncode!=0:
    print_color("{RED}Minikube not running!{RESET}")
    minikube_config = minikube.MinikubeConfig()
    minikube_config.profile = PROFILE
    l.info("Starting Minikube")
    minikube.start_minikube(minikube_config)
else:
    l.ok(f"Minikube running")

# OLM is a requirement
status = !(which olm)
if status.returncode!=0:
    print_color("{RED}OLM not found!{RESET}")
else:
    l.ok(f"Found OLM")
