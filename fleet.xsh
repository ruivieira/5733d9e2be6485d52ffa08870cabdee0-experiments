import json
import minikube
import kafka

def env_var_exists(name):
    return name in ${...}

def read_credentials_file(file):
    with open(file) as json_file:
        data = json.load(json_file)
    return data


def start(credentials: kafka.KafkaCredentials, local_env_file):

    if not env_var_exists("OPENSHIFT_OFFLINE_TOKEN"):
        print_color("{RED}OPENSHIFT_OFFLINE_TOKEN is not set{RESET}")
        print_color("{YELLOW}Go to https://console.redhat.com/openshift/token to get it.")
        $OPENSHIFT_OFFLINE_TOKEN=input("Token: ")
  
    $MANAGED_CONNECTORS_CLUSTER_ID="empty"

    kafka_credentials = read_credentials_file(credentials.MANAGED_KAFKA_CREDENTIALS_FILE)
    bootstrap_server_host = kafka_credentials['bootstrap_server_host']

    sa_credentials = read_credentials_file(credentials.ADMIN_SA_CREDENTIALS_FILE)
    admin_client_id = sa_credentials['clientID']
    admin_client_secret = sa_credentials['clientSecret']

    ops_credentials = read_credentials_file(credentials.OPS_SA_CREDENTIALS_FILE)
    ops_client_id = ops_credentials['clientID']
    ops_client_secret = ops_credentials['clientSecret']

    mc_credentials = read_credentials_file(credentials.MC_SA_CREDENTIALS_FILE)
    mc_client_id = mc_credentials['clientID']
    mc_client_secret = mc_credentials['clientSecret']

    $KAFKA_CLIENT_ID=ops_client_id
    $KAFKA_CLIENT_SECRET=ops_client_secret
    $MANAGED_CONNECTORS_KAFKA_CLIENT_ID=mc_client_id
    $MANAGED_CONNECTORS_KAFKA_CLIENT_SECRET=mc_client_secret

    rm -rf @(local_env_file)
    echo "MANAGER_URL=http://localhost:8080" >> @(local_env_file)
    ip="KEYCLOAK_URL=http://"+$(minikube ip).strip()+":30007"
    echo @(ip) >> @(local_env_file)

    minikube_ip=minikube.get_ip()  
    jas_config = f"org.apache.kafka.common.security.plain.PlainLoginModule required username=\"{mc_client_id}\" password=\"{mc_client_secret}\";"
    # Note: '-Dkafka.*' properties are not required but setting them prevents annoying warning messages in the console
    mvn \
    -Devent-bridge.kafka.bootstrap.servers=@(bootstrap_server_host) \
    -Devent-bridge.kafka.client.id=@(ops_client_id) \
    -Devent-bridge.kafka.client.secret=@(ops_client_secret) \
    -Devent-bridge.kafka.security.protocol=SASL_SSL \
    -Devent-bridge.rhoas.instance-api.host=https://admin-server-@(bootstrap_server_host)/rest \
    -Devent-bridge.rhoas.mgmt-api.host=https://api.openshift.com \
    -Devent-bridge.rhoas.sso.mas.auth-server-url=https://identity.api.openshift.com/auth/realms/rhoas \
    -Devent-bridge.rhoas.sso.mas.client-id=@(admin_client_id) \
    -Devent-bridge.rhoas.sso.mas.client-secret=@(admin_client_secret) \
    -Dminikubeip=@(minikube_ip) \
    -Drhoas.ops-account.client-id=@(ops_client_id) \
    -Dmanaged-connectors.cluster.id=$MANAGED_CONNECTORS_CLUSTER_ID \
    -Dmanaged-connectors.kafka.bootstrap.servers=@(bootstrap_server_host) \
    -Dmanaged-connectors.kafka.client.id=@(mc_client_id) \
    -Dmanaged-connectors.kafka.client.secret=@(mc_client_secret) \
    -Dmanaged-connectors.kafka.security.protocol=SASL_SSL \
    -Dmanaged-connectors.services.url=https://cos-fleet-manager-cos.rh-fuse-153f1de160110098c1928a6c05e19444-0000.eu-de.containers.appdomain.cloud \
    -Dmanaged-connectors.auth.server-url=https://sso.redhat.com/auth/realms/redhat-external \
    -Dmanaged-connectors.auth.token-path=protocol/openid-connect/token \
    -Dmanaged-connectors.auth.client-id=cloud-services \
    -Dmanaged-connectors.auth.offline-token=$OPENSHIFT_OFFLINE_TOKEN \
    -Dquarkus.devservices.enabled=false \
    -Dkafka.client.id=@(mc_client_id) \
    -Dkafka.client.secret=@(mc_client_secret) \
    -Dkafka.security.protocol=SASL_SSL \
    -Dkafka.sasl.jaas.config=@(jas_config) \
    -Dkafka.sasl.mechanism=PLAIN \
    -f "../sandbox/manager/pom.xml" \
    clean compile quarkus:dev
