#!/bin/bash

# Tell OLM to shut down the glance operator that it deployed as described here
# https://github.com/openstack-k8s-operators/docs/blob/main/running_local_operator.md

CSV=$(oc get csv -n openstack-operators | grep glance | awk {'print $1'})
echo "Scaling down $CSV as deployed by OLM"

echo "Backing up $CSV to glance_operator_csv.json"
oc get csv -n openstack-operators $CSV -o json | \
  jq -r 'del(.metadata.generation, .metadata.resourceVersion, .metadata.uid)'  > glance_operator_csv.json

echo "Setting replicas for $CSV to zero"
oc patch csv -n openstack-operators $CSV --type json \
  -p="[{"op": "replace", "path": "/spec/install/spec/deployments/0/spec/replicas", "value": "0"}]"

echo "Removing webhooks for $CSV"
oc patch csv -n openstack-operators $CSV --type=json -p="[{'op': 'remove', 'path': '/spec/webhookdefinitions'}]"

echo "To restore the OLM version of glance use:"
echo "oc patch csv -n openstack-operators $CSV --type=merge --patch-file=glance_operator_csv.json"
