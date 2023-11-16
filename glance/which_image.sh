#!/bin/bash

OP=$(oc get pod -n openstack-operators | grep glance-operator-controller | awk {'print $1'})
IMG=$(oc get pod -n openstack-operators $OP -o yaml | grep quay | tail -1 | awk {'print $2'})
echo $IMG
