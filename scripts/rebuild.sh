#!/bin/bash
# Rebuild control plane and prepare data-plane nodes for configuration

NODES=2
NODE_START=0
CLEAN=1

if [ $CLEAN -eq 1 ]; then
    # Assuming EDPM_CR EDPM_NODE CONTROL PVC are all 1
    bash clean.sh
fi

# Deploy control plane with deps and PVCs
export PVC=1
export DEPS=1
export CONTROL=1
bash deploy.sh
unset PVC
unset DEPS
unset CONTROL

# While control plane is coming up deploy EDPM nodes
export EDPM_NODE=1
bash deploy.sh
unset EDPM_NODE

# Ensure EDPM nodes are all up before proceeding
for I in $(seq $NODE_START $NODES); do
    $(bash ssh_node.sh $I) "hostname" 2> /dev/null
    if [[ $? -gt 0 ]]; then
        echo "Aborting. Unable to SSH into edpm-compute-${I}"
        exit 1
    fi
done

# Configure repository on running EDPM nodes
export EDPM_NODE_REPOS=1
bash deploy.sh
unset EDPM_NODE_REPOS

## TODO
# 1. wait and run EDPM_DEPLOY_PREP
# 2. confirm control plane is ready
