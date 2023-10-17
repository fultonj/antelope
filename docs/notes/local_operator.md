# Local Operator Dev Notes

My notes from [running_local_operator](https://github.com/openstack-k8s-operators/docs/blob/main/running_local_operator.md)

## Shut down the operator deployed by OLM

Identify the CSV
```
$ oc get csv | grep openstack-operator
openstack-operator.v0.0.1               OpenStack                      0.0.1                            Succeeded
$
```
Patch the CSV for the dataplane operator so that it scales down to 0

```
CSV=openstack-operator.v0.0.1
OPERATOR=${OPERATOR:-"dataplane"}
CONTROLLER_MANAGER=${CONTROLLER_MANAGER:-"${OPERATOR}-operator-controller-manager"}
SCALE=${SCALE:-0}

oc project openstack-operators

INDEX=$(oc get csv $CSV -o json | jq ".spec.install.spec.deployments | map(.name==\"${CONTROLLER_MANAGER}\") | index(true)")

oc patch csv $CSV --type='json' -p='[{"op": "replace", "path": "/spec/install/spec/deployments/'${INDEX}'/spec/replicas", "value":'${SCALE}'}]'

# Disable the OLM webhooks

oc patch csv -n openstack-operators $CSV --type=json -p="[{'op': 'remove', 'path': '/spec/webhookdefinitions'}]"

oc project openstack
```

Alternatively: webhookdefinitions 4 and 5 are the
dataplane-operator's.

```
# Remove webhooks
oc patch csv -n openstack-operators ${OPERATOR_CSV} --type=json \
  -p="[{'op': 'remove', 'path': '/spec/webhookdefinitions/5'}]"
oc patch csv -n openstack-operators ${OPERATOR_CSV} --type=json \
  -p="[{'op': 'remove', 'path': '/spec/webhookdefinitions/4'}]"
```

## Run local copy of the operator with webhooks
```
cd ~/dataplane-operator
make manifests generate build
GOWORK= OPERATOR_TEMPLATES=./templates make run-with-webhook
```
For more info see [webhooks](https://github.com/openstack-k8s-operators/docs/blob/main/webhooks.md#using-webhooks-locally)
