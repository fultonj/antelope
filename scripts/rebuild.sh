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

# Wait until we can deploy prep
eval $(crc oc-env)
oc login -u kubeadmin -p 12345678 https://api.crc.testing:6443
echo "Wait for nova-metadata-internal ingress IP to be set"
while [ 1 ]; do
    if [[ ! -z $(oc get svc nova-metadata-internal -o json \
            | jq -r '.status.loadBalancer.ingress[0].ip') ]]; then
        break
    fi
    echo -n "."
    sleep 1
done

# Create crs/data_plane/base/deployment.yaml to kustomize later
export EDPM_DEPLOY_PREP=1
bash deploy.sh
unset EDPM_DEPLOY_PREP

# View control plane end points
oc get pods | grep nova-api
echo "Waiting for the nova-api pod to be running"
while [ 1 ]; do
    if [[ $(oc get pods | grep nova-api | grep Running | wc -l) -gt 0 ]]; then
        break
    fi
    echo -n "."
    sleep 1
done
export OS_CLOUD=default
export OS_PASSWORD=12345678
openstack endpoint list

echo "Waiting for public and private nova endpoints to be listed in keystone"
while [[ 1 ]]; do
    if [[ $(openstack endpoint list -f value | grep nova | wc -l) -eq 2 ]]; then
        break
    else
        echo -n "."
        sleep 1
    fi
done

echo "select * from services in nova_cell1"
# list services in cell1
oc exec -it  pod/openstack-cell1-galera-0 -- mysql -uroot -p12345678 -e "use nova_cell1; select * from services;"
