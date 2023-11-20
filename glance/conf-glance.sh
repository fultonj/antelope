#!/bin/bash

# SVC=glance-config-data
# Internal and External glance store their config here
SVC=glance-external-config-data

for KEY in $(oc get secret $SVC -o json | jq -r '.data | keys[]'); do
    echo "> $KEY"
    echo "---"
    oc get secret $SVC -o json | jq -r --arg KEY "$KEY" '.data[$KEY]' | base64 -d
    echo "---"
done
