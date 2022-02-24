# 5733d9e2be6485d52ffa08870cabdee0-experiments

## Usage

Using from a REPL (e.g. `IPython`).
Instantiating `OB` (if no manager or KeyCloak URL are explicitly specified, these values will be read
from the environment variables `MANAGER_URL` and `KEYCLOAK_URL` respectively):

```python
In [1]: from obclient import *
In [2]: ob = OB()
```

### Getting all bridges

```python
In [3]: ob.bridges
Out[3]:
{'kind': 'BridgeList',
 'items': [{'kind': 'Bridge',
   'id': 'a854b8c2-a7a2-4cd9-bef7-c87d6d4b6bd3',
   'name': 'myBridge',
   'href': '/api/v1/bridges/a854b8c2-a7a2-4cd9-bef7-c87d6d4b6bd3',
   'submitted_at': '2022-02-23T22:17:20.044551+0000',
   'status': 'FAILED'}],
 'page': 0,
 'size': 1,
 'total': 1}
```

### Creating a bridge

```python
In [4]: ob.createBridge("testBridge")
```