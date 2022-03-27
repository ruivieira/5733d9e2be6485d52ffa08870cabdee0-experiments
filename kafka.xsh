#!/usr/bin/env xonsh
import json
from pathlib import Path
from configparser import ConfigParser


def read_config(file):
    SECTION="[top]"
    parser = ConfigParser()
    with open(file) as stream:
        parser.read_string(f"[{SECTION}]\n" + stream.read())  # This line does the trick.
    return {k:v for k, v in parser[SECTION].items()}


def rhoas_is_logged_in():
    return !(rhoas kafka list).returncode == 0

def rhoas_login():
    if not rhoas_is_logged_in():
        print_color("{RED}RHOAS not logged in.{RESET} Please log in with your Red Hat account.")
        rhoas login --print-sso-url
        if not rhoas_is_logged_in():
            print_color("{RED}RHOAS login failure")
            exit(1)

    print_color("{GREEN}RHOAS logged in{RESET}")

def rhoas_get_service_accounts():
    service_accounts=$(rhoas service-account list -o json)
    return json.loads(service_accounts)

def create_service_account(name, credentials_file):
    $SA_UPDATED=False
    service_accounts = rhoas_get_service_accounts()
    sa = [item for item in service_accounts['items'] if item['name']==name]
    sa_count = len(sa)
    if sa_count > 1:
        print_color("{RED}There are " + sa_count + " service accounts named " + name)
        exit(1)
    elif sa_count == 0:
        rhoas service-account create --output-file="@(credentials_file)" --file-format=json --overwrite --short-description="@(sa_name)"
        print_color("{YELLOW}Created service account named " + name)
    else:
        print_color("{GREEN}Service account named '" + name + "' found")

    sa_id = sa[0]['id']

    if not Path(credentials_file).exists():
        msg = f"No credentials file found for service account named '{name}'. Resetting credentials..."
        print_color("{RED}" + msg)
        rhoas service-account reset-credentials --id "@(sa_id)" --output-file="@(credentials_file)" --file-format=json -y
        $SA_UPDATED=True


def create_kafka_instance_and_wait_ready(instance_name, credentials_file, region=None):
    # create instance if not already existing
    instances=json.loads($(rhoas kafka list --search @(instance_name) -o json))
    instance = [instance for instance in instances['items'] if instance['name']==instance_name]
    instance_count = len(instance)
    $KAFKA_CREATED=False

    if instance_count > 1:
        print_color("{RED}There are " + instance_count + " instances named '" + instance_name + "'{RESET}")
    elif instance_count == 0:
        print_color("{YELLOW}Creating Managed Kafka instance named '" + instance_name + "' ...{RESET}")
        if region:
            rhoas kafka create -v @(region) --name @(instance_name)
        else:
            rhoas kafka create -v --name @(instance_name)
        print_color("{GREEN}Created Managed Kafka instance named '" + instance_name + "'{RESET}")
        $KAFKA_CREATED=True
    else:
        print_color("{GREEN}Managed Kafka instance named '" + instance_name + "' found{RESET}")

    # set instance as current
    instance_id=json.loads($(rhoas kafka describe --name @(instance_name) -o json))['id']
    rhoas kafka use --id @(instance_id)

    while $(rhoas kafka describe -o json | jq -rc '.status').strip()!='ready':
        print_color("{YELLOW}Waiting for Managed Kafka instance '"+instance_name+"' to become ready{RESET}")
        sleep 20
    
    print_color("Managed Kafka instance '" + instance_name + "' is ready.{RESET}")

    # export information
    rhoas kafka describe --id @(instance_id) -o json | jq -r > @(credentials_file)

def create_service_accounts(credentials):
    """create service accounts"""
    create_service_account(
        name=credentials['ADMIN_SA_NAME'], 
        credentials_file=credentials['ADMIN_SA_CREDENTIALS_FILE'])

    data = read_credentials_file(credentials['ADMIN_SA_CREDENTIALS_FILE'])
    admin_sa_id=data['clientID']
    if $SA_UPDATED=="True" and $KAFKA_CREATED=="True":
        rhoas kafka acl grant-admin -y --service-account @(admin_sa_id)
        rhoas kafka acl create -y --user @(admin_sa_id) --permission allow --operation create --topic all
        rhoas kafka acl create -y --user @(admin_sa_id) --permission allow --operation delete --topic all
        print_color("{GREEN}Admin account: ACLs created{RESET}")
    
    create_service_account(name=credentials['OPS_SA_NAME'],  credentials_file=credentials['OPS_SA_CREDENTIALS_FILE'])
    data = read_credentials_file(credentials['OPS_SA_CREDENTIALS_FILE'])
    ops_sa_id=data['clientID']
    if $SA_UPDATED=="True" and $KAFKA_CREATED=="True":
        rhoas kafka acl create -y --user @(ops_sa_id) --permission deny --operation alter --cluster
        rhoas kafka acl create -y --user @(ops_sa_id) --permission deny --operation create --topic all
        rhoas kafka acl create -y --user @(ops_sa_id) --permission deny --operation delete --topic all
        print_color("{GREEN}Operational account: ACLs created{RESET}")
    
    create_service_account(name=credentials['MC_SA_NAME'],  credentials_file=credentials['MC_SA_CREDENTIALS_FILE'])
    data = read_credentials_file(credentials['MC_SA_CREDENTIALS_FILE'])
    mc_sa_id=data['clientID']
    if $SA_UPDATED=="True" and $KAFKA_CREATED=="True":
        rhoas kafka acl create -y --user @(mc_sa_id) --permission deny --operation alter --cluster
        rhoas kafka acl create -y --user @(mc_sa_id) --permission deny --operation create --topic all
        rhoas kafka acl create -y --user @(mc_sa_id) --permission deny --operation delete --topic all
        print_color("{GREEN}Managed Connector account: ACLs created{RESET}")


def read_credentials_file(file):
    with open(file) as json_file:
        data = json.load(json_file)
    return data
