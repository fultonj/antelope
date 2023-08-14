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

When `oc get pods` shows that `nova-api` and `dnsmasq-dns` are running
the contorl plane should be ready.

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

### Create a configuration snippet

Create the
[nova-libvirt-qemu.yaml](../crs/snipets/nova-libvirt-qemu.yaml)
snippet, which configures EDPM VMs so they can host nested VMs for
testing.
```
oc create -f snipets/nova-libvirt-qemu.yaml
```

### Customize the OpenStackDataPlane CR

Have [kustomize](https://kustomize.io/) apply changes to the
OpenStackDataPlane CR:
```
pushd ~/antelope/crs/
kustomize build data_plane/overlay/standard > data_plane.yaml
```
The
[deployment.yaml in the standard overlay](../crs/data_plane/overlay/standard/deployment.yaml)
does the following:

- Updates [dataplane-operator provided services](https://openstack-k8s-operators.github.io/dataplane-operator/composable_services/#dataplane-operator-provided-services) to remove the `repo-setup` service since `EDPM_NODE_REPOS` in [deploy.sh](../scripts/deploy.sh) has already registered the EDPM nodes to their repositories.

- Adds a `configMaps` list with the
[nova-libvirt-qemu.yaml snipet](../crs/snipets/nova-libvirt-qemu.yaml)

```diff
[fultonj@hamfast crs]$ diff -u $TARGET data_plane.yaml
--- /home/fultonj/antelope/crs/data_plane/base/deployment.yaml	2023-08-14 14:18:25.509513994 -0400
+++ data_plane.yaml	2023-08-14 16:02:52.165976837 -0400
@@ -4,6 +4,8 @@
   name: openstack-edpm
   namespace: openstack
 spec:
+  configMaps:
+    - nova-libvirt-qemu
   deployStrategy:
     deploy: true
   nodes:
[fultonj@hamfast crs]$
```

## Run EDPM Ansible
```
oc create -f data_plane.yaml
```
I then like to use the following to watch the playbooks:
```
oc get pods -w | grep edpm
oc logs -f dataplane-deployment-configure-network-edpm-compute-skw2g
```

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

## Check if the configuration snipet was applied

After the compute node is deployed, use the following to confirm if
the configuration was applied.
```
$(./ssh_node.sh)
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

- Set `EDPM_NODE`, `CONTROL`, and `PVC` to `1`

The script only needs to be run once with all of the above.
Other vars can keep their defualts of 0 (though NODES defaults to 2).

### Deploy Again

- To deploy again without having to redploy and configure CRC,
  use [rebuild.sh](../scripts/rebuild.sh).

- When `oc get pods` shows that `nova-api` and `dnsmasq-dns` are
  running the control plane should be ready.

- You should now be able to start again from "Create an
  OpenStackDataPlane CR with edpm_deploy_prep".

### Clean Everything

Use [clean.sh](../scripts/clean.sh).

- Set `OPERATORS` and `CRC` to `1` to remove everything
