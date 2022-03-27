#!/usr/bin/env xonsh

def build(minikube_config, localconfig):
    env_command='docker-env'
    RUNTIME=localconfig['minikube_container_runtime']
    PROFILE=minikube_config['MINIKUBE_PROFILE']
    if RUNTIME != "docker":
        print_color("{YELLOW}Use podman env{RESET}")
        env_command='podman-env'
        container_engine_option='-Dquarkus.jib.docker-executable-name=podman'
    
    # temp hack for macOS
    env_command='docker-env'
    source-bash $(minikube -p @(PROFILE) @(env_command))
    print($DOCKER_HOST)
    cd ../sandbox
    mvn clean install -Dquickly -Dquarkus.container-image.build=true @(container_engine_option)
