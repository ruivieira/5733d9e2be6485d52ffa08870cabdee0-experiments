#!/usr/bin/env xonsh
import kafka
import minikube
import images
import fleet
import xlog as l

$XONSH_COLOR_STYLE='native'
$UPDATE_OS_ENVIRON=True
# configure Kafka

required_tools = [
    "docker-compose",
    "jq",
    "kubectl",
    "kustomize",
    "mvn",
    "ping",
    "rhoas"]

# check if required tools are installed
l.header("Check requirements")
for tool in required_tools:
    status = !(which @(tool))
    if status.returncode!=0:
        print_color("{RED}" + tool + "not found!{RESET}")
    else:
        l.ok(f"Found {tool}")


PROJECT_FOLDER="../sandbox"
SCRIPT_FOLDER=f"{PROJECT_FOLDER}/dev/bin"
$KUSTOMIZE_DIR="../sandbox/kustomize"

# Kafka variables

OS=$(uname -s).strip()

l.header("OS")
if OS=="Darwin":
    localconfig = kafka.read_config(f"{SCRIPT_FOLDER}/localconfig-mac")
    l.info("Using Darwin")
else:
    localconfig = kafka.read_config(f"{SCRIPT_FOLDER}/localconfig-linux")
    l.info("Using Linux")

$MANAGED_KAFKA_INSTANCE_NAME = localconfig['managed_kafka_instance_name']

CREDENTIALS_FOLDER=f"{SCRIPT_FOLDER}/credentials"
mkdir -p @(CREDENTIALS_FOLDER)
l.ok(f"Creating credentials folder at {CREDENTIALS_FOLDER}")
LOCAL_ENV_FILE=f"{CREDENTIALS_FOLDER}/local_env"

# setup Kafka
l.header("Kafka")
credentials = kafka.KafkaCredentials.create(CREDENTIALS_FOLDER, $MANAGED_KAFKA_INSTANCE_NAME)
kafka.rhoas_login()
kafka.create_kafka_instance_and_wait_ready($MANAGED_KAFKA_INSTANCE_NAME, credentials.MANAGED_KAFKA_CREDENTIALS_FILE)
kafka.create_service_accounts(credentials=credentials)

# setup Minikube
l.header("Minikube")
minikube_config=minikube.MinikubeConfig()
minikube_config.driver = localconfig['minikube_driver']
minikube_config.container_runtime = localconfig['minikube_container_runtime']
minikube.start_minikube(minikube_config=minikube_config)

# build docker images
images.build(minikube_config, localconfig, PROJECT_FOLDER)

# spin up all the resources that the Fleet Manager needs to run (keycloak, postgres, prometheus and grafana)
docker-compose -f ../sandbox/dev/docker-compose/docker-compose.yml up -d

fleet.start(credentials, LOCAL_ENV_FILE)