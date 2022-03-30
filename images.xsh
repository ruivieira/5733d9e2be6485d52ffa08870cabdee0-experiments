#!/usr/bin/env xonsh

def build(minikube_config, localconfig, project_dir):
    """Build the docker-compose images"""
    env_command='docker-env'
    RUNTIME=localconfig['minikube_container_runtime']
    
    PROFILE=minikube_config['MINIKUBE_PROFILE']
    if RUNTIME != "docker":
        print_color("{YELLOW}Use podman env{RESET}")
        env_command='podman-env'
        container_engine_option='-Dquarkus.jib.docker-executable-name=podman'
    else:
        print_color("{YELLOW}Use docker env{RESET}")
        env_command='docker-env'
        container_engine_option='-Dquarkus.jib.docker-executable-name=docker'
    
    variables=$(minikube -p @(PROFILE) @(env_command))
    
    cd @(project_dir)
    mvn clean install -Dquickly -Dquarkus.container-image.build=true @(container_engine_option)