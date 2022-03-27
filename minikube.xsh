#!/usr/bin/env xonsh

def configure_minikube(profile="minikube", cpus=4, memory=8192, version="v1.21.6"):
    config = {}
    config['MINIKUBE_PROFILE'] = profile
    config['MINIKUBE_CPUS'] = cpus
    config['MINIKUBE_MEMORY'] = memory
    config['MINIKUBE_KUBERNETES_VERSION'] = version
    return config

def start_minikube(minikube_config, localconfig, extras=True):
    PROFILE = minikube_config['MINIKUBE_PROFILE']
    minikube_opts=""
    minikube_opts+=f" --driver={localconfig['minikube_driver']}"
    minikube_opts+=f" --container-runtime={localconfig['minikube_container_runtime']}"
    print(minikube_opts)
    minikube -p @(PROFILE) \
        --memory @(minikube_config['MINIKUBE_MEMORY']) \
        --cpus @(minikube_config['MINIKUBE_CPUS']) \
        --kubernetes-version=@(minikube_config['MINIKUBE_KUBERNETES_VERSION']) start
    sleep 30
    minikube -p @(PROFILE) addons enable ingress
    sleep 5
    minikube -p @(PROFILE) addons enable ingress-dns
    sleep 5

    if extras:
        # Check if KUSTOMIZE_DIR is set
        kustomize build $KUSTOMIZE_DIR/overlays/minikube/keycloak | kubectl apply -f -
        sleep 5
        kubectl wait pod -l app-component=keycloak --for=condition=Ready --timeout=600s -n keycloak
        sleep 5
        kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/kube-prometheus/v0.9.0/manifests/setup/prometheus-operator-0servicemonitorCustomResourceDefinition.yaml
