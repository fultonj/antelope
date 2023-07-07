# HCI Deployment

These are my notes on how to produce an HCI deployment like the
described in the upstream
[hci docs](https://github.com/openstack-k8s-operators/docs/blob/main/hci.md).
by using my [scripts](../scripts), [crs](../crs), and personal
conventions.

## VMs

- crc: hosts control plane pods
- edpm-compute-0: hosts both compute and ceph
- edpm-compute-1: hosts both compute and ceph
- edpm-compute-2: hosts both compute and ceph

## Assumptions

The [standard](standard.md) deploy has used to verify a working
environment and [rebuild.sh](../scripts/rebuild.sh) was used to
rebuild with registered edpm nodes and a working control plane.
A `crs/data_plane/base/deployment.yaml` file exists to kustomize.

The EDPM nodes should have disks. They can be added, after rebuild.sh
is run, like this.
```
export EDPM_NODE_DISKS=1
./deploy.sh
unset EDPM_NODE_DISKS
```

## Configure the networks of the EDPM nodes

Create a data.yaml file with the
[net-only](../crs/data_plane/overlay/net-only)
overlay which disables nova and only configures/validates the network
by shortening the services list.
```
pushd ~/antelope/crs/
kustomize build data_plane/overlay/net-only > data.yaml
```
Deploy the data plane.
```
oc create -f data.yaml
```
You should now have three EDPM nodes which can run Ceph.

## Install Ceph on EDPM nodes

Run [install_ceph.sh](../scripts/ceph/install_ceph.sh)
from within the [scripts/ceph](../scripts/ceph/) directory
to install Ceph with network isolation one a single node.

Run [ceph_secret.sh](../scripts/ceph/ceph_secret.sh) to create a
secret viewable via
`oc get secret ceph-conf-files -o json | jq -r '.data."ceph.conf"' | base64 -d`

Ceph should now be running on all EDPM nodes and the `ceph-conf-files`
secret can be used to access it.

## Configure OpenStack to use the collocated Ceph server

Use kustomize to apply the following overlays

- control plane [ceph](../crs/control_plane/overlay/ceph)
- data plane [ceph](../crs/data_plane/overlay/ceph)
- data plane [hci](../crs/data_plane/overlay/hci)

### Todo
- use kustomize to set FSID environment variable
- use kustomize to update existing control plane CR for ceph
- create hci overlay
