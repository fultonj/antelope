#!/bin/bash

function clean_tmp {
    rm -rf /tmp/{old,new}
    mkdir /tmp/{old,new}
}

function switch_branch {
    echo "Switching branch to \"$1\""
    pushd architecture > /dev/null
    git checkout $1 1> /dev/null 2> /dev/null
    BRANCH=$1
    popd > /dev/null
}

function check_branch {
    pushd architecture > /dev/null
    BRANCH=$(git branch --show-current)
    if [[ $BRANCH == "main" ]]; then
        echo "Aborting: first check out the branch you want to compare to main"
        exit 1
    else
        echo "Comparing \"$BRANCH\" against \"main\" for VA1"
    fi
    popd > /dev/null
}

function build_va1 {
    # building CRs in $TARGET as described here
    # https://github.com/openstack-k8s-operators/architecture/tree/main/examples/va/hci
    TARGET=$1
    echo "Building va1 in $TARGET of branch \"$BRANCH\""
    # control-plane
    pushd architecture/examples/va/hci > /dev/null
    kustomize build control-plane/nncp > $TARGET/nncp.yaml
    kustomize build control-plane > $TARGET/control-plane.yaml
    # dataplane-pre-ceph
    if [[ $BRANCH == "main" ]]; then
        kustomize build edpm-pre-ceph > $TARGET/dataplane-pre-ceph.yaml
    else
        kustomize build edpm-pre-ceph/nodeset > $TARGET/dataplane-nodeset-pre-ceph.yaml
        kustomize build edpm-pre-ceph/deployment > $TARGET/dataplane-deployment-pre-ceph.yaml
    fi
    # post-ceph
    if [[ $BRANCH == "main" ]]; then
        kustomize build > $TARGET/dataplane-post-ceph.yaml
    else
        kustomize build > $TARGET/nodeset-post-ceph.yaml
        kustomize build deployment > $TARGET/deployment-post-ceph.yaml
    fi
    tree $TARGET
    popd > /dev/null
}

# -------------------------------------------------------

pushd ~/review/ > /dev/null

clean_tmp
check_branch
TESTED_BRANCH=$BRANCH
build_va1 /tmp/new

switch_branch main
build_va1 /tmp/old
switch_branch $TESTED_BRANCH

echo "Compare \"$TESTED_BRANCH\" in /tmp/new to \"main\" in /tmp/old"

popd > /dev/null
