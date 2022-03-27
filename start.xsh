#!/usr/bin/env xonsh
import kafka

$XONSH_COLOR_STYLE = 'native'
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
for tool in required_tools:
  status = !(which @(tool))
  if status.returncode!=0:
      print_color("{RED}" + tool + "not found!{RESET}")

SCRIPT_FOLDER="../sandbox/dev/bin"

# Kafka variables
localconfig = kafka.read_config(SCRIPT_FOLDER + "/localconfig")
$MANAGED_KAFKA_INSTANCE_NAME = localconfig['managed_kafka_instance_name']

CREDENTIALS_FOLDER=f"{SCRIPT_FOLDER}/credentials"
mkdir -p @(CREDENTIALS_FOLDER)
LOCAL_ENV_FILE=f"{CREDENTIALS_FOLDER}/local_env"

def configure_kafka(folder, instance_name):
    credentials = {}
    credentials['MANAGED_KAFKA_CREDENTIALS_FILE']=f"{folder}/{instance_name}.json"
    credentials['ADMIN_SA_NAME']=f"{instance_name}-admin"
    credentials['ADMIN_SA_CREDENTIALS_FILE']=f"{folder}/{credentials['ADMIN_SA_NAME']}.json"
    credentials['OPS_SA_NAME']=f"{instance_name}-ops"
    credentials['OPS_SA_CREDENTIALS_FILE']=f"{folder}/{credentials['OPS_SA_NAME']}.json"
    credentials['MC_SA_NAME']=f"{instance_name}-mc"
    credentials['MC_SA_CREDENTIALS_FILE']=f"{folder}/{credentials['MC_SA_NAME']}.json"
    return credentials

credentials = configure_kafka(CREDENTIALS_FOLDER, $MANAGED_KAFKA_INSTANCE_NAME)
kafka.rhoas_login()
kafka.create_service_accounts(credentials=credentials)
kafka.create_kafka_instance_and_wait_ready($MANAGED_KAFKA_INSTANCE_NAME, credentials['MANAGED_KAFKA_CREDENTIALS_FILE'])