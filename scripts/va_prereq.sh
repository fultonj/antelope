#!/bin/bash
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
bash deploy.sh
unset PVC
unset DEPS

