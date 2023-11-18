#!/bin/bash

POD=$(oc get pods -n openstack-operators -l openstack.org/operator-name=glance --no-headers | awk '{print $1}')
echo $POD
oc -n openstack-operators logs $POD $@
