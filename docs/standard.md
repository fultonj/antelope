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
- edpm-compute-2: standard edpm compute node

## Prepare

Use [deploy.sh](../scripts/deploy.sh) sequentially with the following
tags set to `1` (unless otherwise indicated other tags are `0`).

- `CRC`
- `ATTACH`
- `PVC` and `DEPS`
- `OPER`

Set `CONTROL` to `1` and while the control plane is still coming up
build the EDPM nodes sequentially with the following tags set to `1`.

- `EDPM_NODE`
- `EDPM_NODE_REPOS`

Keep `NODES=2`, `EDPM_NODE_DISKS=0`, `NODE_START=0` through the entire
process. When `oc get pods` shows that `nova-api` and `dnsmasq-dns`
are running the contorl plane should be ready.

You should then have a working control plane running on `crc`
and `edpm-compute-{0,1,2}` will be ready to be configured by Ansible.
Use [ssh_node.sh](../scripts/ssh_node.sh) for a command to use
to SSH into `edpm-compute-0`.

## Create an OpenStackDataPlane CR with edpm_deploy_prep

I don't use `make edpm_deploy` because I like to have a CR file to
review and modify before I start the deployment. Thus, I use `make
edpm_deploy_prep` and `kustomize` to create a `deployment.yaml` file.

Create a `deployment.yaml` file in the base data_plane CR directory.
```
TARGET=$HOME/antelope/crs/data_plane/base/deployment.yaml
pushd ~/install_yamls
DATAPLANE_CHRONY_NTP_SERVER=pool.ntp.org \
    DATAPLANE_TOTAL_NODES=3 \
    DATAPLANE_SINGLE_NODE=false \
    make edpm_deploy_prep
oc kustomize out/openstack/dataplane/cr > $TARGET
popd
```

[deploy.sh](../scripts/deploy.sh) does this when EDPM_DEPLOY_PREP is used.

### Customize the OpenStackDataPlane CR Automatically

The section below this one describes changes I like to make to my
standard deployment, how to apply the changes manually, and how to
apply changes for update.

To have [kustomize](https://kustomize.io/) apply these changes instead
run:
```
pushd ~/antelope/crs/
kustomize build data_plane/overlay/standard > data_plane.yaml
```
The
[deployment.yaml in the standard overlay](../crs/data_plane/overlay/standard/deployment.yaml)
updates the service list, configures libvirt with QEMU and sets
`deployStrategy` true (more details on that below) by using
[patchesStrategicMerge](https://kubectl.docs.kubernetes.io/references/kustomize/builtins/#_patchesstrategicmerge_).

### Customize the OpenStackDataPlane CR Manually

Make a copy of the `data_plane.yaml` CR to modify.
```
cp $HOME/antelope/crs/data_plane/base/deployment.yaml ~/antelope/crs/data_plane.yaml
```

Apply the following two changes for now.

Set the `spec.deployStrategy.deploy` field to `True` as
[documented](https://openstack-k8s-operators.github.io/dataplane-operator/deploying/#deploy-the-dataplane)
so that the
[dataplane-operator provided services](https://openstack-k8s-operators.github.io/dataplane-operator/composable_services)
will be configured (by Ansible) on the EDPM nodes.

Update the
[dataplane-operator provided services](https://openstack-k8s-operators.github.io/dataplane-operator/composable_services/#dataplane-operator-provided-services)
to remove the `repo-setup` service since `EDPM_NODE_REPOS`
in [deploy.sh](../scripts/deploy.sh) has already registered the EDPM
nodes to their repositories.

## Run EDPM Ansible
```
oc create -f data_plane.yaml
```
I then like to use the following to watch the playbooks:
```
oc get pods -w | grep edpm
oc logs -f dataplane-deployment-configure-network-edpm-compute-skw2g
```

### Re-run Ansible to apply configuration updates

If you need to make a configuration update, edit `data_plane.yaml` and
and run `oc apply -f data_plane.yaml`.

For example, change this line:
```
        nova: {}
```
to:
```
        nova:
          cellName: cell1
          customServiceConfig: |
            [libvirt]
            virt_type = qemu
```
If you didn't use kustomize to apply my
[standard overlay](../crs/data_plane/overlay/standard/deployment.yaml)
then do the above step.

Run `oc apply -f data_plane.yaml`. You should see new Ansible jobs run
via `oc get pods -w | grep edpm`.Then you can inspect your compute
node to see if it got the configuration change.
```
$(./ssh_node.sh)
podman exec -ti nova_compute /bin/bash
cat /etc/nova/nova.conf.d/02-nova-override.conf
```
I use `virt_type = qemu` so that my EDPM VMs can host nested VMs for testing.

### Stop Failing Ansible Jobs

If Ansible fails and you want to tell the dataplane-operator to stop
spawning Ansible jobs, then delete the `OpenStackDataPlane` CR.
```
oc delete -f data_plane.yaml
```
You can then edit your `data_plane.yaml` accordingly and recreate it to
try again.

The above shouldn't be necessary unless the Ansible jobs have a
problem. If all of the Ansible jobs succeed, then the completed
jobs (returned when running `oc get pods | grep edpm`) will eventually
be terminated.

## Test

Use [test.sh](../scripts/test.sh) with:

- `CEPH` and `CINDER` set to 0 (there's no backend for Cinder)

You should be able to create a glance image (hosted on a local storage
provided by a PVC), a private network and be able to boot a VM.

## Clean

Delete the `OpenStackDataPlane` CR.
```
oc delete -f data_plane.yaml
```
Another way to do this if you don't have the CR file is.
```
oc delete openstackdataplane.dataplane.openstack.org/standard-openstack-edpm
```
Use `oc edit openstackdataplane.dataplane.openstack.org` to determine
the name if `standard-openstack-edpm` does not match.

Use [clean.sh](../scripts/clean.sh).

- Set `EDPM`, `CONTROL`, and `PVC` to `1`

The script only needs to be run once with all of the above.
Other vars can keep their defualts of 0 (though NODES defaults to 2).

### Deploy Again

To deploy again without having to redploy and configure CRC,
use [deploy.sh](../scripts/deploy.sh).

- Set `PVC`, `DEPS` and `CONTROL` to `1` to deploy a new control plane

while the control plane is still coming up build the EDPM nodes
sequentially with the following tags set to `1`.

- `EDPM_NODE`
- `EDPM_NODE_REPOS`

Keep `NODES=2`, `EDPM_NODE_DISKS=0`, `NODE_START=0` through the entire
process. When `oc get pods` shows that `nova-api` and `dnsmasq-dns`
are running the contorl plane should be ready.

You should now be able to start again from "Create an
OpenStackDataPlane CR with edpm_deploy_prep"

### Clean Everything

Use [clean.sh](../scripts/clean.sh).

- Set `OPERATORS` and `CRC` to `1` to remove everything
