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

```
pushd ~/antelope/scripts/ceph
./install_ceph.sh
./ceph_secret.sh
popd
```

### Details

The [install_ceph.sh](../scripts/ceph/install_ceph.sh)
script uses content from [scripts/ceph](../scripts/ceph/)
directory to install Ceph.

The [ceph_secret.sh](../scripts/ceph/ceph_secret.sh)
script creates a secret viewable via
`oc get secret ceph-conf-files -o json | jq -r '.data."ceph.conf"' | base64 -d`

Ceph should now be running on all EDPM nodes and the `ceph-conf-files`
secret can be used to access it.

## Configure OpenStack to use the collocated Ceph server

### Update the Control Plane to use Ceph

Use the [data plane ceph overlay](../crs/control_plane/overlay/ceph)
with kustomize and `sed` to swap in the correct FSID.

```
pushd ~/antelope/crs/
FSID=$(oc get secret ceph-conf-files -o json | jq -r '.data."ceph.conf"' \
  | base64 -d | grep fsid | sed -e 's/fsid = //' | xargs)
kustomize build control_plane/overlay/ceph | sed "s/_FSID_/${FSID}/" > control.yaml
oc apply -f control.yaml
popd
```

### Complete configuration of the Data Plane

Todo
- Use [ceph](../crs/data_plane/overlay/ceph) to create [hci](../crs/data_plane/overlay/hci)


