#!/bin/bash

EDPM_CR=1
EDPM_NODE=1
CONTROL=1
CEPH_CLI=0
OPERATORS=0
CEPH_K8S=0
PVC=1
CRC=0

# node0 node1 node2
NODES=2
NODE_START=0

eval $(crc oc-env)
oc login -u kubeadmin -p 12345678 https://api.crc.testing:6443

if [ $EDPM_CR -eq 1 ]; then
    oc get openstackdataplane.dataplane.openstack.org -o name | xargs oc delete
fi

if [ $EDPM_NODE -eq 1 ]; then
    pushd ~/install_yamls/devsetup
    for I in $(seq $NODE_START $NODES); do
        make edpm_compute_cleanup EDPM_COMPUTE_SUFFIX=$I;
    done
    popd
fi

if [ $CONTROL -eq 1 ]; then
    pushd ~/install_yamls
    make openstack_deploy_cleanup
    echo "Deleted control plane pods"
    popd
fi

if [ $CEPH_CLI -eq 1 ]; then
    oc get secret | grep ceph
    oc delete secret ceph-conf-files
    oc get secret | grep ceph
fi

if [ $OPERATORS -eq 1 ]; then
    pushd ~/install_yamls
    date
    make openstack_cleanup
    popd
fi

if [ $CEPH_K8S -eq 1 ]; then
    pushd ~/install_yamls
    make ceph_cleanup
    popd
fi

if [ $PVC -eq 1 ]; then
    pushd ~/install_yamls
    make crc_storage_cleanup
    popd
fi

if [ $CRC -eq 1 ]; then
    pushd ~/install_yamls/devsetup
    cd devsetup
    make crc_cleanup
    popd
fi

unset OPENSTACK_CTLPLANE
env | grep -i openstack
