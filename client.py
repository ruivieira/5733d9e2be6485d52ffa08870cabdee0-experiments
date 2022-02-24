from obclient import *
import subprocess


def minikubeIp():
    result = subprocess.run(["minikube", "ip"], capture_output=True)
    return result.stdout.strip().decode("utf-8")


MANAGER_URL = "http://localhost:8080"
KEYCLOAK_URL = f"http://{minikubeIp()}:30007"

ob = OB(managerUrl=MANAGER_URL, keycloackUrl=KEYCLOAK_URL)

bridges = ob.bridges

print(bridges)

result = ob.createBridge("experimental")
print(result)
