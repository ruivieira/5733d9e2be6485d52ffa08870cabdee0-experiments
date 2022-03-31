import xlog as l
import os
import minikube
import argparse

PLATFORM=$(uname -s).strip()
KF_TAG="1.0.1"


def install_kfctl(platform: str, version: str):
    l.info("Installing kfctl")
    KF_BASE="https://api.github.com/repos/kubeflow/kfctl/releases"
    KFCTL_URL=$(curl -s @(KF_BASE) | grep http | grep @(version) | grep -i @(platform) | cut -d : -f 2,3 | tr -d '\" ' ).strip()
    print_color("Downloading from {YELLOW}" + KFCTL_URL + "{RESET}")
    FILENAME=os.path.basename(KFCTL_URL)
    cd /tmp
    curl -L @(KFCTL_URL) --output @(FILENAME)
    tar -xvf @(FILENAME)
    mv ./kfctl /usr/local/bin/
    l.info("Insalled kfctl")


def install_kubeflow(platform: str, branch: str, version: str):
    MANIFEST_VERSION=f"v{version}"

    KF_PROJECT_NAME=f"hello-kf-{PLATFORM}"
    # delete if it exists
    if fp"{KF_PROJECT_NAME}".exists():
        l.info(f"Deleting {KF_PROJECT_NAME}")
        rm -Rf @(KF_PROJECT_NAME) 
    mkdir -p @(KF_PROJECT_NAME)
    pushd @(KF_PROJECT_NAME)

    manifest_root="https://raw.githubusercontent.com/kubeflow/manifests"
    FILE_NAME=f"kfctl_k8s_istio.{MANIFEST_VERSION}.yaml"
    KFDEF=f"{manifest_root}/{branch}/kfdef/{FILE_NAME}"
    kfctl apply -f @(KFDEF) -V

def delete(config: minikube.MinikubeConfig):
    minikube stop -p @(config.profile)
    minikube delete -p @(config.profile)

def dashboard(config: minikube.MinikubeConfig):
    INGRESS_HOST=$(minikube ip -p @(config.profile)).strip()
    INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}').strip()
    print(f"Kubeflow dashboard: http://{INGRESS_HOST}:{INGRESS_PORT}")

def status():
    kubectl get pod -n kubeflow

minikube_config = minikube.MinikubeConfig()
minikube_config.profile = "kubeflow"

if __name__=="__main__":
    parser = argparse.ArgumentParser(description='Install kubeflow', add_help=True)
    parser.add_argument('-i', '--install', action='store_true', help='Install Kubeflow')
    parser.add_argument('-d', '--delete', action='store_true', help='Delete Minikube Kubeflow profile')
    parser.add_argument('-b', '--dashboard', action='store_true', help='Open Kubeflow dashboard')
    parser.add_argument('-s', '--status', action='store_true', help='Show deployment status')
    args = parser.parse_args()
    if args.install:
        install_kfctl(PLATFORM, KF_TAG)
        
        # Start Minikube        
        minikube.start_minikube(minikube_config, extras=False)

        # Install Kubeflow
        install_kubeflow(PLATFORM, "v1.0-branch", KF_TAG)

    elif args.status:
        status()
    elif args.dashboard:
        dashboard(minikube_config)
    elif args.delete:
        delete(minikube_config)
    else:
        parser.print_usage()