#!/bin/bash

function clean_tmp {
    rm -rf /tmp/{old,new}
    mkdir /tmp/{old,new}
}

function switch_branch {
    pushd architecture > /dev/null
    git checkout $1 1> /dev/null 2> /dev/null
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
    kustomize build edpm-pre-ceph > $TARGET/dataplane-pre-ceph.yaml
    # post-ceph
    kustomize build > $TARGET/dataplane-post-ceph.yaml
    tree $TARGET
    popd > /dev/null
}

# -------------------------------------------------------

pushd ~/review/ > /dev/null

clean_tmp
check_branch

# switch_branch $BRANCH
# build_va1 /tmp/new

switch_branch main
build_va1 /tmp/old
switch_branch $BRANCH

echo "Compare \"$BRANCH\" in /tmp/new to \"main\" in /tmp/old"

popd > /dev/null
