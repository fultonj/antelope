#!/bin/bash

POD=$(oc get pods -n openstack-operators -l openstack.org/operator-name=glance --no-headers -o custom-columns=":metadata.name")
echo $POD
oc -n openstack-operators logs $POD $@
