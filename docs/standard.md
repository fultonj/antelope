# Standard

These are my notes on how to deploy a standard OpenStack ControlPlane
and DataPlane as described in:

- [install_yamls](https://github.com/openstack-k8s-operators/install_yamls/tree/main#deploy-dev-env-using-crc-edpm-nodes-with-isolated-networks)
- [install_yamls/devsetup](https://github.com/openstack-k8s-operators/install_yamls/tree/main/devsetup)
- [dataplane-operator/deploying](https://openstack-k8s-operators.github.io/dataplane-operator/deploying/)

by using my [scripts](../scripts) and personal conventions.

## VMs

The following VMs are deployed

- crc: hosts control plane pods
- edpm-compute-0: standard edpm compute node
- edpm-compute-1: standard edpm compute node

## Prepare

Use [deploy.sh](../scripts/deploy.sh) sequentially with the following
tags set to `1` (unless otherwise indicated other tags are `0`).

- `CRC`
- `ATTACH`
- `PVC` and `DEPS`
- `OPER`

## Simple Deployment

Set the following to `1` and sequentially run deploy and that's it.

- `CONTROL_SIMPLE`
- `EDPM_NODE`
- `EDPM_DEPLOY`
- `TEST_SIMPLE`

## Deployment with Preparation

I don't always use `make openstack_deploy` or `make edpm_deploy`
because I like to have an unapplied CR file to modify before starting
the deployment. In that case I use `make *_deploy_prep` commands as
described here.

Set `CONTROL` to `1` and while the control plane is still
coming up build the EDPM nodes sequentially with the following tags
set to `1`.

- `EDPM_NODE`
- `EDPM_DEPLOY_PREP`

When `oc get pods` shows that `nova-api` and `dnsmasq-dns` are running
the contorl plane should be ready.

You should then have a working control plane running on `crc`
and `edpm-compute-{0,1}` will be ready to be configured by Ansible.
Use [ssh_node.sh](../scripts/ssh_node.sh) for a command to use
to SSH into `edpm-compute-0`.

[deploy.sh](../scripts/deploy.sh) assumes [jumbo frames](notes/mtu.md)
are enabled on the hypervisor.

## Create an OpenStackDataPlaneNodeSet CR

[deploy.sh](../scripts/deploy.sh) should have created the CR if it was
run with `EDPM_DEPLOY_PREP` enabled.
```
pushd ~/antelope/crs/
oc create -f data_plane/base/deployment.yaml
popd
```

The CR comes from running `make edpm_deploy_prep` from
[install_yamls](https://github.com/openstack-k8s-operators/install_yamls/tree/main#deploy-dev-env-using-crc-edpm-nodes-with-isolated-networks).
I don't always use `make edpm_deploy` because I like to have a CR file
to review and modify before I start the deployment.

The CR should only contain an OpenStackDataPlane
[NodeSet](https://openstack-k8s-operators.github.io/dataplane-operator/openstack_dataplanenodeset)
and not a
[Deployment](https://openstack-k8s-operators.github.io/dataplane-operator/openstack_dataplanedeployment).
The CR will be a base for
[kustomzation overlays](../crs/data_plane/overlay/).

### Create a configuration snippet

Create the
[libvirt-qemu-nova.yaml](../crs/snippets/libvirt-qemu-nova.yaml)
configuration snippet (so nested VMs can be booted for testing).
```
oc create -f snippets/libvirt-qemu-nova.yaml
```
Create a custom version of the
[nova service](https://github.com/openstack-k8s-operators/dataplane-operator/blob/main/config/services/dataplane_v1beta1_openstackdataplaneservice_nova.yaml)
which ships with the operator so that it uses the snippet by
adding it to the `configMaps` list. E.g. here is
[my version](../crs/services/dataplane_v1beta1_openstackdataplaneservice_nova_custom.yaml)
```
oc create -f services/dataplane_v1beta1_openstackdataplaneservice_nova_custom.yaml
```
As per the NOTE in [dataplane-operator docs](https://openstack-k8s-operators.github.io/dataplane-operator/composable_services/#dataplane-operator-provided-optional-services),
we cannot redefine a custom version of `nova` service since
the "default service will overwrite the custom service with the same
name during role reconciliation".

### Create an OpenStackDataPlaneDeployment to run Ansible

The
[standard ansible deployment](../crs/deployments/deployment-standard.yaml)
contains the list of services to be configured including the
`nova-custom` service which uses the configuration snippet from the
previous step.

```
oc create -f deployments/deployment-standard.yaml
```
I then like to use the following to watch the playbooks:
```
oc get pods -w -l app=openstackansibleee
oc logs -f dataplane-deployment-configure-network-deployment-standardsvs8r
```

### Stop Failing Ansible Jobs

If Ansible fails and you want to tell the dataplane-operator to stop
spawning Ansible jobs, then delete the
`OpenStackDataPlaneNodeDeployment` CR.

```
oc delete -f deployments/deployment-standard.yaml
```
You can then update OpenStack DataPlane
[NodeSet](https://openstack-k8s-operators.github.io/dataplane-operator/openstack_dataplanenodeset)
(e.g. `data_plane/base/deployment.yaml`) or
[Deployment](https://openstack-k8s-operators.github.io/dataplane-operator/openstack_dataplanedeployment) (e.g. `deployments/deployment-standard.yaml`)
recreate the deployment to try again.

The above shouldn't be necessary unless the Ansible jobs have a
problem. If all of the Ansible jobs succeed, then the completed
jobs (returned when running `oc get pods | grep edpm`) will eventually
be terminated.

## Check if the configuration snipet was applied

After the compute node is deployed, use the following to confirm if
the configuration snippet was copied to the host.
```
$(./ssh_node.sh)
ls /var/lib/openstack/config/nova/
podman exec -ti nova_compute ls -l /etc/nova/nova.conf.d/
```
The above should show a configuration file from the configuration
snippet (created earlier) in the nova_compute pod's `nova.conf.d`
directory.

## Test

Use [test.sh](../scripts/test.sh) with:

- `CEPH` and `CINDER` set to 0 (there's no backend for Cinder)

You should be able to create a glance image (hosted on a local storage
provided by a PVC), a private network and be able to boot a VM.

## Clean

### Delete Deployment

Delete the `OpenStackDataPlaneDeployment` CR.
```
oc delete -f deployments/deployment-standard.yaml
```
Another way to do this if you don't have the CR file is.
```
oc delete openstackdataplanedeployments.dataplane.openstack.org/deployment-standard
```
Use `openstackdataplanedeployments.dataplane.openstack.org` to
determine the name.

### Delete NodeSet

Delete the `OpenStackDataPlaneNodeSet` CR.
```
oc delete -f data_plane/base/deployment.yaml
```
Another way to do this if you don't have the CR file is.
```
oc delete openstackdataplanenodesets.dataplane.openstack.org/openstack-edpm
```
Use `oc edit openstackdataplanenodesets.dataplane.openstack.org` to
determine the name.

### clean.sh script

Use [clean.sh](../scripts/clean.sh). The script deletes all found
`OpenStackDataPlaneDeployments` and `OpenStackDataPlaneNodeSets`.

- Set `EDPM_NODE`, `CONTROL`, and `PVC` to `1`

The script only needs to be run once with all of the above.
Other vars can keep their defualts of 0 (though NODES defaults to 2).

### Deploy Again

- To deploy again without having to redploy and configure CRC,
  use [rebuild.sh](../scripts/rebuild.sh).

- When `oc get pods` shows that `nova-api` and `dnsmasq-dns` are
  running the control plane should be ready.

- You should now be able to start again from "Create an
  OpenStackDataPlaneNodeSet CR"

### Clean Everything

Use [clean.sh](../scripts/clean.sh).

- Set `OPERATORS` and `CRC` to `1` to remove everything
