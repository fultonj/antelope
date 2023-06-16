# Standard

These are my notes on how to deploy a standard OpenStack ControlPlane
and DataPlane as described in:

- [install_yamls](https://github.com/openstack-k8s-operators/install_yamls/tree/main#deploy-dev-env-using-crc-edpm-nodes-with-isolated-networks)
- [install_yamls/devsetup](https://github.com/openstack-k8s-operators/install_yamls/tree/main/devsetup)
- [dataplane-operator/deploying](https://openstack-k8s-operators.github.io/dataplane-operator/deploying/)

by using my [scripts](../scripts), [crs](../crs), and personal conventions.

## VMs

- crc: hosts control plane pods
- edpm-compute-0: standard edpm compute node
