#!/bin/bash

# AUTHENTICATE
export OS_CLOUD=default
export OS_PASSWORD=12345678

openstack endpoint list > /dev/null
if [[ $? -gt 0 ]]; then
    echo "Unable to authenticate to keystone"
    exit 1
fi
# -------------------------------------------------------
# GET VALUES
# This value comes from:
#   https://github.com/openstack-k8s-operators/ci-framework/pull/495
export SWIFT_PASSWORD=12345678

if [[ -z $RGW_ENDPOINT ]]; then
    echo "Looking up RGW VIP"
    export RGW_ENDPOINT=$($(./ssh_node.sh) sudo cephadm shell 2> /dev/null -- \
                                           ceph orch ls --export --format json-pretty \
                              | jq -r '.[] | select(.spec != null and .spec.virtual_ip != null) | .spec.virtual_ip' | sed s/\\/24//g)
fi
echo $RGW_ENDPOINT
# -------------------------------------------------------
# REMOVE SWIFT
echo "Deleting object-store endpoints"
for EP in $(openstack endpoint list -f value | grep object-store | awk {'print $1'}); do
    openstack endpoint delete $EP
done

echo "Deleting swift services"
for SVC in $(openstack service list -f value | grep swift | awk {'print $1'}); do
    openstack service delete $SVC
done

echo "Deleting swift users"
for USR in $(openstack user list -f value | grep swift | awk {'print $1'}); do
    openstack user delete $USR
done
# -------------------------------------------------------
# ADD RGW
echo "Adding object storage services"
openstack service create --name swift --description "OpenStack Object Storage" object-store

echo "Adding object storage users"
openstack user create --project service --password $SWIFT_PASSWORD swift

echo "Adding object storage roles"
openstack role create swiftoperator
openstack role create ResellerAdmin
openstack role add --user swift --project service member
openstack role add --user swift --project service admin

echo "Adding object storage endpoints"
for i in public internal; do
    openstack endpoint create --region regionOne object-store $i http://$RGW_ENDPOINT:8080/swift/v1/AUTH_%\(tenant_id\)s;
done

openstack role add --project admin --user admin swiftoperator
# -------------------------------------------------------
