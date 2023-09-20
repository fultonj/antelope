#!/bin/bash

EDPM_CR=1
EDPM_NODE=1
NOVA_DB=0
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
    oc get openstackdataplanedeployment.dataplane.openstack.org -o name | xargs oc delete
    oc get openstackdataplanenodeset.dataplane.openstack.org -o name | xargs oc delete
fi

if [ $EDPM_NODE -eq 1 ]; then
    pushd ~/install_yamls/devsetup
    for I in $(seq $NODE_START $NODES); do
        make edpm_compute_cleanup EDPM_COMPUTE_SUFFIX=$I;
    done
    popd
fi

if [ $NOVA_DB -eq 1 ]; then
    # nova_compute pod flapped with
    #   nova.exception.InvalidConfiguration: No local node identity found,
    # but this is not our first startup on this host. Refusing to start
    # after potentially having lost that state!
    #
    # Related Codde:
    #   https://review.opendev.org/q/topic:bp%252Fstable-compute-uuid
    #
    # But this should have prevented it
    #   `make openstack_cleanup`  and `make crc_storage_cleanup`
    #
    # Dropping unwanted data to ensure it is clean.
    echo "Dropping nova DBs containing the following entries:"

    oc exec -it  pod/openstack-cell1-galera-0 -- mysql -uroot -p12345678 -e \
       "use nova_cell1; select * from services;"
    oc exec -it  pod/openstack-galera-0 -- mysql -uroot -p12345678 -e \
       "use nova_cell0; select * from services;"

    oc exec -it  pod/openstack-cell1-galera-0 -- mysql -uroot -p12345678 -e \
       "drop database nova_cell1;"
    oc exec -it  pod/openstack-galera-0 -- mysql -uroot -p12345678 -e \
       "drop database nova_cell0; drop database nova_api;"
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
    echo -n "Waiting to ensure all Galera pods are have stopped running..."
    while [[ 1 ]]; do
        if [[ $(oc get pods 2> /dev/null | grep -i galera | wc -l) -gt 0 ]]; then
            echo -n "."
            sleep 1
        else
            echo "Galera is not running"
            break
        fi
    done
    pushd ~/install_yamls
    make crc_storage_cleanup
    make crc_storage_cleanup
    popd
fi

if [ $CRC -eq 1 ]; then
    pushd ~/install_yamls/devsetup
    make crc_cleanup
    popd
fi

unset OPENSTACK_CTLPLANE
env | grep -i openstack
