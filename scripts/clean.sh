#!/bin/bash

DPJOBS=0
EDPM=0
DATAPLANE_CR=0
CONTROL=0
CEPH_CLI=0
OPERATORS=0
CEPH_K8S=0
CRC=0

# node0 node1 node2
NODES=2
WAIT=50
NODE_START=0

if [ $DPJOBS -eq 1 ]; then
    eval $(crc oc-env)
    oc login -u kubeadmin -p 12345678 https://api.crc.testing:6443
    oc get pods -o name | grep dataplane | grep -v manager | xargs oc delete
    oc get pods -o name | grep nova-edpm  | xargs oc delete
    oc get openstackansibleees.ansibleee.openstack.org -o name | xargs oc delete
fi

if [ $EDPM -eq 1 ]; then
    pushd ~/install_yamls/devsetup
    for I in $(seq $NODE_START $NODES); do
        make edpm_compute_cleanup EDPM_COMPUTE_SUFFIX=$I;
    done
    popd
fi

if [ $DATAPLANE_CR -eq 1 ]; then
    bash data_plane_cr.sh DELETE
fi

if [ $CONTROL -eq 1 ]; then
    pushd ~/install_yamls
    make openstack_deploy_cleanup
    echo "Deleted control plane pods"
    popd
fi

if [ $CEPH_CLI -eq 1 ]; then
    eval $(crc oc-env)
    oc login -u kubeadmin -p 12345678 https://api.crc.testing:6443
    oc get secret | grep ceph
    oc delete secret ceph-conf-files
    oc get secret | grep ceph
fi

if [ $OPERATORS -eq 1 ]; then
    pushd ~/install_yamls
    date
    # echo "Waiting $WAIT seconds before deleting openstack operators"
    # for I in $(seq 0 $WAIT); do
    #     echo -n .
    #     sleep 1;
    # done
    make openstack_cleanup
    # side effect of the new approach we're trying with
    # OpenStack operator to reduce bundle size.  
    make manila_cleanup
    popd
fi

if [ $CEPH_K8S -eq 1 ]; then
    pushd ~/install_yamls
    make ceph_cleanup
    popd
fi

if [ $CRC -eq 1 ]; then
    pushd ~/install_yamls
    #make crc_storage_cleanup
    cd devsetup
    make crc_cleanup
    popd
fi

unset OPENSTACK_CTLPLANE
env | grep -i openstack
