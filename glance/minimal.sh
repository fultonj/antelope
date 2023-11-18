#!/bin/bash

CLEAN=1
CTL=1

# Rebuild operators too?
OPER=0
# Install new image?
IMG=0
# (re)create PVCs?
PVC=1
# Toy Ceph Cluster?
CEPH=1

if [ $CLEAN -eq 1 ]; then
    pushd ~/install_yamls
    echo "Removing Control Plane"
    make openstack_deploy_cleanup
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
    if [ $CEPH -eq 1 ]; then
	pushd ~/install_yamls
	make ceph_cleanup
	popd
	oc delete secret ceph-conf-files
    fi
    if [ $OPER -eq 1 ]; then
        echo "Removing Operators"
        make openstack_cleanup
    fi
    popd
fi

if [ $OPER -eq 1 ]; then
    echo "Adding Operators"
    export OPER=1
    bash ../scripts/deploy.sh
    unset OPER
    echo "Waiting for openstack-operators to be running"
    timeout 300 bash -c 'until $(oc get csv -l operators.coreos.com/openstack-operator.openstack-operators -n openstack-operators | grep -q Succeeded); do echo -n "."; sleep 1; done'
fi

if [ $IMG -eq 1 ]; then
    echo "Deploying the following operator image"
    grep NEW operator-image.sh | head -1
    bash operator-image.sh
fi

if [ $CTL -eq 1 ]; then
    if [ $PVC -eq 1 ]; then
        export PVC=1
        bash ../scripts/deploy.sh
        unset PVC
    fi
    echo "Adding Control Plane"
    export CONTROL=1
    bash ../scripts/deploy.sh
    unset CONTROL

    pushd ~/antelope/crs/
    kustomize build control_plane/overlay/minimal > control.yaml
    oc apply -f control.yaml
    popd

    if [ $CEPH -eq 1 ]; then
	pushd ~/install_yamls
	make ceph
	popd
    fi
fi
