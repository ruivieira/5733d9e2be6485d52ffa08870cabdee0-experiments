#!/usr/bin/env xonsh
import xlog as l


def get_ip(profile="minikube"):
    ip=$( minikube -p @(profile) ip ).strip()
    $MINIKUBE_IP=ip
    return ip
# function configure_minikube_started {
#   configure_minikube
#   MINIKUBE_IP=$( minikube -p "${MINIKUBE_PROFILE}" ip ) || die "can't find minikube ip. Is it started?"
#   ping -c 1 "${MINIKUBE_IP}" || die "minikube is not responding to ping. Is it started?"
# }

class MinikubeConfig:
    def __init__(self):
        self.profile = "minikube"
        self.cpus = 4
        self.memory = 8192
        self.version = "v1.21.6"
        self.driver = "docker"
        self.container_runtime = "docker"

def start_minikube(config: MinikubeConfig, extras=True):
    PROFILE = config.profile
    minikube_opts=""
    minikube_opts+=f" --driver={config.driver}"
    minikube_opts+=f" --container-runtime={config.container_runtime}"
    minikube -p @(PROFILE) \
        --memory @(config.memory) \
        --cpus @(config.cpus) \
        --kubernetes-version=@(config.version) start
    sleep 30
    minikube -p @(PROFILE) addons enable ingress
    sleep 5
    minikube -p @(PROFILE) addons enable ingress-dns
    sleep 5

    if extras:
        
        # Check if KUSTOMIZE_DIR is set
        kustomize build $KUSTOMIZE_DIR/overlays/minikube/keycloak | kubectl apply -f -
        l.ok(f"Applying keycloak (kustomize)")
        sleep 5
        l.info(f"Waiting for keycload pod")
        kubectl wait pod -l app-component=keycloak --for=condition=Ready --timeout=600s -n keycloak
        sleep 5
        l.ok(f"Applying Prometheus")
        kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/kube-prometheus/v0.9.0/manifests/setup/prometheus-operator-0servicemonitorCustomResourceDefinition.yaml
