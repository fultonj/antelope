# External Ceph

These are my notes on how to produce an external Ceph deployment
like the one described in the upstream
[ceph docs](https://github.com/openstack-k8s-operators/docs/blob/main/ceph.md)
by using my [scripts](../scripts), [crs](../crs), and personal
conventions.

## VMs

- crc: hosts control plane pods
- edpm-compute-0: only hosts Ceph (not a real EDPM node)
- edpm-compute-1: hosts compute (real EDPM node)

The advantage of the above is that you can rebuild edpm-compute-1
without having to rebuild edpm-compute-0 so your Ceph cluster does not
need to be rebuilt when testing OpenStack. edpm-compute-0 is only used
as a server which is pre-configured into the networks. It could be any
VM but I use it this way to take advantage of existing VM building
scripts.

## Prepare EDPM Nodes

Use [deploy.sh](../scripts/deploy.sh)

- Set each TAG to `1` from `CRC` to `OPER` to get started
- Keep `NODES=1` to use two EDPM nodes (unless otherwise indicated)
- Use `NODE_START=0 EDPM_NODE=1` to create edpm-compute-0 and edpm-compute-1 VMs
- Use `NODE_START=1 EDPM_NODE_REPOS=1` to prepare edpm-compute-1 to host Nova
- Use `NODES=0 NODE_START=0 EDPM_NODE_DISKS=1` to prepare edpm-compute-0 to host Ceph

## Install Ceph

Run [install_ceph.sh](../scripts/ceph/install_ceph.sh) 
from within the [scripts/ceph](../scripts/ceph/) directory
to install Ceph with network isolation one a single node with the
following parameters.
```
NET=1
PRE=1
BOOT=1
SINGLE_OSD=1
SSH_KEYS=0
SPEC=0
CEPHX=1
NODES=0
```
Run [ceph_secret.sh](../scripts/ceph/ceph_secret.sh) to create a secret viewable via
`oc get secret ceph-conf-files -o json | jq -r '.data."ceph.conf"' | base64 -d`

Ceph should now be running on edpm-compute-0 and the `ceph-conf-files`
secret can be used to access it.

## Deploy an OpenStackControlPlane

Use `make openstack_deploy_prep` to create a base `deployment.yaml`
file for the control plane.

```
TARGET=$HOME/antelope/crs/control_plane/base/deployment.yaml
pushd ~/install_yamls
DBSERVICE=galera make openstack_deploy_prep
kustomize build out/openstack/openstack/cr > $TARGET
popd
```

Create a control.yaml file with customizations for Ceph.
```
pushd ~/antelope/crs/
kustomize build control_plane/overlay/ceph/ > control.yaml
```
The
[deployment.yaml in the ceph overlay](../crs/control_plane/overlay/ceph/deployment.yaml)
contains `extraMounts` and `customServiceConfig` for Glance and Cinder
to run Ceph which are applied via
[patchesStrategicMerge](https://kubectl.docs.kubernetes.io/references/kustomize/builtins/#_patchesstrategicmerge_).

Set the actual FSID.
```
FSID=$(oc get secret ceph-conf-files -o json | jq -r '.data."ceph.conf"' \
  | base64 -d | grep fsid | sed -e 's/fsid = //' | xargs)
sed -i "s/_FSID_/${FSID}/" control.yaml
```
Deploy the control plane.
```
oc create -f control.yaml
```

## Deploy an OpenStackDataPlane

Use `make edpm_deploy_prep` to create a base `dataplane.yaml` file for
the data plane.

```
TARGET=$HOME/antelope/crs/data_plane/base/deployment.yaml
pushd ~/install_yamls
DATAPLANE_CHRONY_NTP_SERVER=pool.ntp.org \
    DATAPLANE_SINGLE_NODE=false DATAPLANE_TOTAL_NODES=2 \
    make edpm_deploy_prep
kustomize build out/openstack/dataplane/cr > $TARGET
popd
```
Create a data.yaml file with customizations for Ceph.
```
pushd ~/antelope/crs/
kustomize build data_plane/overlay/ceph > data.yaml
```
The
[deployment.yaml in the ceph overlay](../crs/data_plane/overlay/ceph/deployment.yaml)
contains `extraMounts` and `customServiceConfig` for Nova to run Ceph which are applied via
[patchesStrategicMerge](https://kubectl.docs.kubernetes.io/references/kustomize/builtins/#_patchesstrategicmerge_).

Set the actual FSID.
```
FSID=$(oc get secret ceph-conf-files -o json | jq -r '.data."ceph.conf"' \
  | base64 -d | grep fsid | sed -e 's/fsid = //' | xargs)
sed -i "s/_FSID_/${FSID}/" data.yaml
```
Deploy the data plane.
```
oc create -f data.yaml
```

## Watch Ansible

```
oc get pods -w | grep edpm
oc logs -f dataplane-deployment-configure-network-edpm-compute-skw2g
```

## Test

Use [test.sh](../scripts/test.sh) with:

- `CEPH` set to 1

You should be able to create a glance image hosted on ceph and see it
in the images pool. You should then be able to create private network
and be able to boot a VM. You should also be able to attach a volume
to it.
