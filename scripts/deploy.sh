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
    make crc_attach_default_interface
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
    make BMO_SETUP=false openstack
fi

if [ $CONTROL -eq 1 ]; then
    eval $(crc oc-env)
    oc login -u kubeadmin -p 12345678 https://api.crc.testing:6443
    if [[ $? -gt 0 ]]; then
        echo "Error: Unable to authenticate to OpenShift"
        exit 1
    fi
    oc get pods -n openstack-operators | grep controller
    # Save a copy of the base dataplane CR in my CRs directory
    TARGET=$HOME/antelope/crs/control_plane/base/deployment.yaml
    DBSERVICE=galera make openstack_deploy_prep
    kustomize build out/openstack/openstack/cr > $TARGET
    oc create -f $TARGET

    # "make netconfig_deploy" was missing and presented as:
    # AnsibleUndefinedVariable: No variable found with this name: internal_api_mtu
    # openstack_deploy does both openstack_deploy_prep and netconfig_deploy
    # https://github.com/openstack-k8s-operators/install_yamls/blob/
    # /b05c31abc27f4cc85dac50c4c6cc0ffe3de55ec0/Makefile#L533
    make netconfig_deploy
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
    DATAPLANE_CHRONY_NTP_SERVER=pool.ntp.org \
        DATAPLANE_TOTAL_NODES=3 \
        make edpm_deploy_prep
    oc kustomize out/openstack/dataplane/cr > $TARGET
    popd
    ls -l $TARGET

    # Removing this argument:
    #   DATAPLANE_SINGLE_NODE=false \
    # Because it causes this error:
    #   https://paste.opendev.org/show/bg6FENo2XNqH8a1CVPEB/
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
