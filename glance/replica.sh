#!/bin/bash

if [[ -z $1 ]]; then
    N=1
else
    N=$1
fi
JSON="{\"spec\":{\"glance\":{\"template\":{\"glanceAPI\":{\"replicas\":$N}}}}}"
oc patch openstackcontrolplane openstack-galera-network-isolation --type merge -p "$JSON"
