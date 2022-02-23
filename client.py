import subprocess
import json
import requests
from base64 import b64encode
from typing import Any


def minikubeIp():
    result = subprocess.run(["minikube", "ip"], capture_output=True)
    return result.stdout.strip().decode("utf-8")


class OB:
    def __init__(self, managerUrl: str, keycloackUrl: str) -> None:
        self._managerUrl = managerUrl
        self._keycloackUrl = keycloackUrl
        self._token = self._getBearerToken()["access_token"]

    def _getBearerToken(self) -> Any:
        headers = {
            "content-type": "application/x-www-form-urlencoded",
        }

        data = {"username": "kermit", "password": "thefrog", "grant_type": "password"}

        response = requests.post(
            f"{self._keycloackUrl}/auth/realms/event-bridge-fm/protocol/openid-connect/token",
            headers=headers,
            data=data,
            verify=False,
            auth=("event-bridge", "secret"),
        )

        return response.json()

    @property
    def bridges(self) -> Any:
        headers = {"Authorization": f"Bearer {self._token}"}
        response = requests.get(
            url=f"{self._managerUrl}/api/v1/bridges", headers=headers
        )
        return response.json()

    def createBridge(self, name: str) -> Any:
        headers = {
            "Authorization": f"{self._token}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        }

        json_data = {
            "name": name,
        }

        response = requests.post(
            f"{self._managerUrl}/api/v1/bridges", headers=headers, json=json_data
        )
        return response.json()


MANAGER_URL = "http://localhost:8080"
KEYCLOAK_URL = f"http://{minikubeIp()}:30007"

ob = OB(managerUrl=MANAGER_URL, keycloackUrl=KEYCLOAK_URL)

bridges = ob.bridges

print(bridges)

result = ob.createBridge("experimental")
print(result)
