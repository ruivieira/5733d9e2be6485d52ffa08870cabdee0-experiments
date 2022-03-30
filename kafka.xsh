#!/usr/bin/env xonsh
import json
from pathlib import Path
from configparser import ConfigParser
from dataclasses import dataclass
import xlog as l

@dataclass
class KafkaCredentials:
    """Class for Kafka credentials"""
    MANAGED_KAFKA_CREDENTIALS_FILE: str
    ADMIN_SA_NAME: str
    ADMIN_SA_CREDENTIALS_FILE: str
    OPS_SA_NAME: str
    OPS_SA_CREDENTIALS_FILE: str
    MC_SA_NAME: str
    MC_SA_CREDENTIALS_FILE: str

    @staticmethod
    def create(folder, instance_name):
        MANAGED_KAFKA_CREDENTIALS_FILE=f"{folder}/{instance_name}.json"
        ADMIN_SA_NAME=f"{instance_name}-admin"
        ADMIN_SA_CREDENTIALS_FILE=f"{folder}/{ADMIN_SA_NAME}.json"
        OPS_SA_NAME=f"{instance_name}-ops"
        OPS_SA_CREDENTIALS_FILE=f"{folder}/{OPS_SA_NAME}.json"
        MC_SA_NAME=f"{instance_name}-mc"
        MC_SA_CREDENTIALS_FILE=f"{folder}/{MC_SA_NAME}.json"
        return KafkaCredentials(
            MANAGED_KAFKA_CREDENTIALS_FILE=MANAGED_KAFKA_CREDENTIALS_FILE,
            ADMIN_SA_NAME=ADMIN_SA_NAME,
            ADMIN_SA_CREDENTIALS_FILE=ADMIN_SA_CREDENTIALS_FILE,
            OPS_SA_NAME=OPS_SA_NAME,
            OPS_SA_CREDENTIALS_FILE=OPS_SA_CREDENTIALS_FILE,
            MC_SA_NAME=MC_SA_NAME,
            MC_SA_CREDENTIALS_FILE=MC_SA_CREDENTIALS_FILE
        )


def read_config(file):
    SECTION="[top]"
    parser = ConfigParser()
    with open(file) as stream:
        parser.read_string(f"[{SECTION}]\n" + stream.read())  # This line does the trick.
    return {k:v for k, v in parser[SECTION].items()}


def rhoas_is_logged_in() -> bool:
    """Check is RHOAS is logged in"""
    return !(rhoas kafka list).returncode == 0

def rhoas_login():
    if not rhoas_is_logged_in():
        l.error("RHOAS not logged in.Please log in with your Red Hat account.")
        rhoas login --print-sso-url
        if not rhoas_is_logged_in():
            l.error("RHOAS login failure")
            exit(1)

    l.ok("RHOAS logged in")

def rhoas_get_service_accounts():
    service_accounts=$(rhoas service-account list -o json)
    return json.loads(service_accounts)


def create_service_account(name: str, credentials_file: str):
    """Create a service account if one not available"""
    $SA_UPDATED=False
    service_accounts = rhoas_get_service_accounts()
    sa = [item for item in service_accounts['items'] if item['name']==name]
    sa_count = len(sa)
    if sa_count > 1:
        l.error(f"There are {sa_count} service accounts named {name}")
        exit(1)
    elif sa_count == 0:
        rhoas service-account create --output-file="@(credentials_file)" --file-format=json --overwrite --short-description="@(sa_name)"
        l.info(f"Created service account named {name}")
    else:
        l.ok(f"Service account named '{name}' found")

    sa_id = sa[0]['id']

    if not Path(credentials_file).exists():
        l.error(f"No credentials file found for service account named '{name}'. Resetting credentials...")
        rhoas service-account reset-credentials --id "@(sa_id)" --output-file="@(credentials_file)" --file-format=json -y
        $SA_UPDATED=True


def create_kafka_instance_and_wait_ready(instance_name, credentials_file, region=None):
    # create instance if not already existing
    instances=json.loads($(rhoas kafka list --search @(instance_name) -o json))
    instance = [instance for instance in instances['items'] if instance['name']==instance_name]
    instance_count = len(instance)
    $KAFKA_CREATED=False

    if instance_count > 1:
        l.error(f"There are {instance_count} instances named '{instance_name}'")
    elif instance_count == 0:
        l.info(f"Creating Managed Kafka instance named '{instance_name}'...")
        if region:
            rhoas kafka create -v @(region) --name @(instance_name)
        else:
            rhoas kafka create -v --name @(instance_name)
        l.ok(f"Created Managed Kafka instance named '{instance_name}'")
        $KAFKA_CREATED=True
    else:
        l.ok(f"Managed Kafka instance named '{instance_name}' found")

    # set instance as current
    instance_id=json.loads($(rhoas kafka describe --name @(instance_name) -o json))['id']
    rhoas kafka use --id @(instance_id)

    while $(rhoas kafka describe -o json | jq -rc '.status').strip()!='ready':
        l.info(f"Waiting for Managed Kafka instance '{instance_name}' to become ready")
        sleep 20
    
    l.ok(f"Managed Kafka instance '{instance_name}' is ready.")

    # export information
    rhoas kafka describe --id @(instance_id) -o json | jq -r > @(credentials_file)

def create_service_accounts(credentials: KafkaCredentials):
    """create service accounts"""
    create_service_account(
        name=credentials.ADMIN_SA_NAME, 
        credentials_file=credentials.ADMIN_SA_CREDENTIALS_FILE)

    data = read_credentials_file(credentials.ADMIN_SA_CREDENTIALS_FILE)
    admin_sa_id=data['clientID']
    if $SA_UPDATED=="True" and $KAFKA_CREATED=="True":
        rhoas kafka acl grant-admin -y --service-account @(admin_sa_id)
        rhoas kafka acl create -y --user @(admin_sa_id) --permission allow --operation create --topic all
        rhoas kafka acl create -y --user @(admin_sa_id) --permission allow --operation delete --topic all
        l.ok("Admin account: ACLs created")
    
    create_service_account(name=credentials.OPS_SA_NAME,  credentials_file=credentials.OPS_SA_CREDENTIALS_FILE)
    data = read_credentials_file(credentials.OPS_SA_CREDENTIALS_FILE)
    ops_sa_id=data['clientID']
    if $SA_UPDATED=="True" and $KAFKA_CREATED=="True":
        rhoas kafka acl create -y --user @(ops_sa_id) --permission deny --operation alter --cluster
        rhoas kafka acl create -y --user @(ops_sa_id) --permission deny --operation create --topic all
        rhoas kafka acl create -y --user @(ops_sa_id) --permission deny --operation delete --topic all
        l.ok("Operational account: ACLs created")
    
    create_service_account(name=credentials.MC_SA_NAME,  credentials_file=credentials.MC_SA_CREDENTIALS_FILE)
    data = read_credentials_file(credentials.MC_SA_CREDENTIALS_FILE)
    mc_sa_id=data['clientID']
    if $SA_UPDATED=="True" and $KAFKA_CREATED=="True":
        rhoas kafka acl create -y --user @(mc_sa_id) --permission deny --operation alter --cluster
        rhoas kafka acl create -y --user @(mc_sa_id) --permission deny --operation create --topic all
        rhoas kafka acl create -y --user @(mc_sa_id) --permission deny --operation delete --topic all
        l.ok("Managed Connector account: ACLs created")


def read_credentials_file(file):
    with open(file) as json_file:
        data = json.load(json_file)
    return data
