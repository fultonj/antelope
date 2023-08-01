# Local Operator Dev Notes

My notes from [running_local_operator](https://github.com/openstack-k8s-operators/docs/blob/main/running_local_operator.md)

## Shut down the operator deployed by OLM

Identify the CSV
```
oc get csv | grep DataPlane
```

Patch the CSV for the dataplane operator so that it scales down to 0
```
CSV=dataplane-operator.v0.0.1

oc get csv -n openstack-operators $CSV -o json | \
    jq -r 'del(.metadata.generation, .metadata.resourceVersion, .metadata.uid)'  > operator_csv.json

oc patch csv -n openstack-operators $CSV --type json \
  -p="[{"op": "replace", "path": "/spec/install/spec/deployments/0/spec/replicas", "value": "0"}]"
```
Disable the OLM webhooks
```
oc patch csv -n openstack-operators $CSV --type=json -p="[{'op': 'remove', 'path': '/spec/webhookdefinitions'}]"
```
After running the above you should see:
`clusterserviceversion.operators.coreos.com/dataplane-operator.v0.0.1 patched`

## Run local copy of the operator with webhooks
```
cd ~/dataplane-operator
make manifests generate build
GOWORK= OPERATOR_TEMPLATES=./templates make run-with-webhook
```
For more info see [webhooks](https://github.com/openstack-k8s-operators/docs/blob/main/webhooks.md#using-webhooks-locally)
