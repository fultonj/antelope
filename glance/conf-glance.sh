#!/bin/bash

for KEY in $(oc get secret glance-config-data -o json | jq -r '.data | keys[]'); do
    echo "> $KEY"
    echo "---"
    oc get secret glance-config-data -o json | jq -r --arg KEY "$KEY" '.data[$KEY]' | base64 -d
    echo "---"
done
