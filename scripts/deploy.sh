#!/bin/bash

#TAGS
CRC=${CRC:-"0"}
ATTACH=${ATTACH:-"0"}
PVC=${PVC:-"0"}
DEPS=${DEPS:-"0"}
OPER=${OPER:-"0"}
CONTROL=${CONTROL:-"0"}
EDPM_NODE=${EDPM_NODE:-"0"}
EDPM_NODE_REPOS=${EDPM_NODE_REPOS:-"0"}
EDPM_SVCS=${EDPM_SVCS:-"0"}
EDPM_DEPLOY_PREP=${EDPM_DEPLOY_PREP:-"0"}
EDPM_DEPLOY_STANDARD=${EDPM_DEPLOY_STANDARD:-"0"}

# node0 node1 node2
NODES=2
NODE_START=0
ADOPT=0

if [[ -z /usr/local/bin/yq ]]; then
    # install yq if it is missing
    export URL=https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    sudo wget -qO /usr/local/bin/yq $URL
    sudo chmod a+x /usr/local/bin/yq
fi

if [[ ! -d ~/install_yamls ]]; then
    echo "Error: ~/install_yamls is missing"
    exit 1
fi
pushd ~/install_yamls/devsetup

if [ $CRC -eq 1 ]; then
    if [[ ! -e pull-secret.txt ]]; then
        cp ~/pull-secret.txt .
    fi
    if [[ $HOSTNAME == hamfast.examle.com ]]; then
        make CPUS=12 MEMORY=49152 DISK=100 crc
    else
        make CPUS=56 MEMORY=262144 DISK=200 crc
    fi
fi

if [ $ATTACH -eq 1 ]; then
    echo "Inspecting resolv.conf before and after crc_attach_default_interface"
    CRC_SSH="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ~/.crc/machines/crc/id_ecdsa core@192.168.130.11"
    $CRC_SSH "cat /etc/redhat-release"

    # we want this when we are done
    # nameserver 192.168.130.1
    # nameserver 192.168.122.1

    $CRC_SSH "cat /etc/resolv.conf"
    make crc_attach_default_interface
    sleep 2
    $CRC_SSH "cat /etc/resolv.conf"
    $CRC_SSH "host api-int.crc.testing"

    # If "make crc_attach_default_interface" breaks the CRC VM's
    # /etc/resolv.conf so that api-int.crc.testing won't resolve,
    # then tell Network Manager to not change /etc/resolv.conf
    # as per https://shorturl.at/boVZ4.
    # Use 'make crc_attach_default_interface_cleanup' to retry.
fi

cd ..

if [ $PVC -eq 1 ]; then
    make crc_storage
fi

if [ $DEPS -eq 1 ]; then
    # for some reason this fails the first time but not the second
    make input
    make input
fi

if [ $OPER -eq 1 ]; then
    make NETWORK_MTU=9000 BMO_SETUP=false openstack
fi

if [ $CONTROL -eq 1 ]; then
    eval $(crc oc-env)
    oc login -u kubeadmin -p 12345678 https://api.crc.testing:6443
    if [[ $? -gt 0 ]]; then
        echo "Error: Unable to authenticate to OpenShift"
        exit 1
    fi
    oc get pods -n openstack-operators | grep controller
    if [[ $(oc get pods -n openstack-operators | grep controller | wc -l) -eq 0 ]]; then
        echo "Error: no controllers running in openstack-operators namespace"
        exit 1
    fi
    # Set the MTU for the Node Network Policy (NNCP), which configures
    # the bridges on OCP worker(s). I.e. Cutomize the NetConfig CR
    # (usually made by "make openstack_deploy") to set MTU=9000 for
    # the storagemgmt and storage networks.
    make netconfig_deploy_prep
    oc kustomize out/openstack/infra/cr > /tmp/netconfig.yaml
    yq -i '(.spec.networks[3].mtu)=9000' /tmp/netconfig.yaml
    yq -i '(.spec.networks[4].mtu)=9000' /tmp/netconfig.yaml

    # Save a copy of the base dataplane CR in my CRs directory
    TARGET=$HOME/antelope/crs/control_plane/base/deployment.yaml
    DBSERVICE=galera make openstack_deploy_prep
    kustomize build out/openstack/openstack/cr > $TARGET
    # disable swift
    /usr/local/bin/yq -i '(.spec.swift.enabled)=false' $TARGET
    # The following will implicitly call 'make netconfig_deploy'
    NETCONFIG_CR=/tmp/netconfig.yaml OPENSTACK_CR=$TARGET make openstack_deploy
fi

cd devsetup

if [ $EDPM_NODE -eq 1 ]; then
    for I in $(seq $NODE_START $NODES); do
        if [[ $I -eq 0 && $ADOPT -eq 1 ]]; then
            RAM=16
        else
            RAM=8
        fi
        make edpm_compute EDPM_COMPUTE_SUFFIX=$I EDPM_COMPUTE_VCPUS=8 EDPM_COMPUTE_RAM=$RAM
    done
fi

if [ $EDPM_NODE_REPOS -eq 1 ]; then
    for I in $(seq $NODE_START $NODES); do
        make edpm_compute_repos EDPM_COMPUTE_SUFFIX=$I;
    done
fi

popd # out of install_yamls

if [ $EDPM_SVCS -eq 1 ]; then
    pushd ~/dataplane-operator/config/services
    for F in $(ls *.yaml); do
	oc create -f $F
    done
    popd
fi

if [ $EDPM_DEPLOY_PREP -eq 1 ]; then
    TARGET=$HOME/antelope/crs/data_plane/base/deployment.yaml
    pushd ~/install_yamls
    DATAPLANE_CHRONY_NTP_SERVER=time.google.com \
        DATAPLANE_TOTAL_NODES=3 \
        DATAPLANE_SINGLE_NODE=false \
        make edpm_deploy_prep
    oc kustomize out/openstack/dataplane/cr > $TARGET
    popd
    ls -l $TARGET
fi

if [ $EDPM_DEPLOY_STANDARD -eq 1 ]; then
    eval $(crc oc-env)
    oc login -u kubeadmin -p 12345678 https://api.crc.testing:6443
    if [[ $? -gt 0 ]]; then
        echo "Error: Unable to authenticate to OpenShift"
        exit 1
    fi
    pushd ~/antelope/crs/
    kustomize build data_plane/overlay/standard > data_plane.yaml
    oc create -f data_plane.yaml
    popd
fi
