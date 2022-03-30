#!/usr/bin/env xonsh

import minikube

def start():
    print("Retrieving webhook technical bearer token...")
    minikube_ip=minikube.get_ip()    
    print(minikube_ip)
    event_bridge_webhook_technical_bearer_token=$(curl --insecure -X POST http://@(minikube_ip):30007/auth/realms/event-bridge-fm/protocol/openid-connect/token --user event-bridge:secret -H 'content-type: application/x-www-form-urlencoded' -d 'username=webhook-robot-1&password=therobot&grant_type=password&scope=offline_access' | jq --raw-output '.access_token').strip()
    print(f"Webhook technical bearer token retrieved: {event_bridge_webhook_technical_bearer_token}")

    mvn \
    -Devent-bridge.webhook.technical-bearer-token=@(event_bridge_webhook_technical_bearer_token) \
    -Dminikubeip=@(minikube_ip) \
    -Dquarkus.http.port=1337 \
    -Pminikube \
    -f "../sandbox/shard-operator/pom.xml" \
    clean compile quarkus:dev

if __name__=="__main__":
    start()