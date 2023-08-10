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

## Configure the networks of the EDPM nodes

Create a data.yaml file with the
[net-only](../crs/data_plane/overlay/net-only)
overlay which disables nova and only configures/validates the network
and puts directives in place to open the firewall for Ceph
by shortening the services list.
```
pushd ~/antelope/crs/
kustomize build data_plane/overlay/net-only > data.yaml
```
Deploy the data plane.
```
oc create -f data.yaml
```
You should now have three EDPM nodes configured with network isolation
which can run Ceph.

## Install Ceph on EDPM nodes

Use the
[ceph.yml](https://github.com/openstack-k8s-operators/ci-framework/blob/main/ci_framework/playbooks/ceph.yml)

playbook from the
[CI Framework](https://github.com/openstack-k8s-operators/ci-framework)
as described in
[cifmw_cephadm README](https://github.com/openstack-k8s-operators/ci-framework/blob/main/ci_framework/roles/cifmw_cephadm/README.md).

Update the default inventory with the group `edpm` containing `N` EDPM
nodes.
```
export N=2
echo -e "localhost ansible_connection=local\n[edpm]" > ~/ci-framework/inventory.yml
for I in $(seq 100 $((N+100))); do
  echo 192.168.122.${I} >> ~/ci-framework/inventory.yml
done
```
Configure the Ansible environment to use the SSH key created by `install_yamls`.
```
export ANSIBLE_REMOTE_USER=root
export ANSIBLE_SSH_PRIVATE_KEY=~/install_yamls/out/edpm/ansibleee-ssh-key-id_rsa
export ANSIBLE_HOST_KEY_CHECKING=False
```
Run the playbook to deploy Ceph.
```
cd ~/ci-framework/
ansible-playbook ci_framework/playbooks/ceph.yml
```
Delete the old Ceph secret (if you have one) and create a new one from
the secret file created by Ansible.
```
oc delete secret ceph-conf-files
oc create -f /tmp/k8s_ceph_secret.yml
```
Ceph should now be running on all EDPM nodes and the `ceph-conf-files`
secret can be used to access it.

## Configure OpenStack to use the collocated Ceph server

### Update the Control Plane to use Ceph

Use the [data plane ceph overlay](../crs/control_plane/overlay/ceph)
with kustomize and `sed` (to swap in the correct FSID) to update the
existing control plane.

```
pushd ~/antelope/crs/
FSID=$(oc get secret ceph-conf-files -o json | jq -r '.data."ceph.conf"' \
  | base64 -d | grep fsid | sed -e 's/fsid = //' | xargs)
kustomize build control_plane/overlay/ceph | sed "s/_FSID_/${FSID}/" > control.yaml
oc apply -f control.yaml
popd
```

The [deployment.yaml in the control plane ceph overlay](../crs/control_plane/overlay/ceph/deployment.yaml)
contains `extraMounts` and `customServiceConfig` for Glance and Cinder to use Ceph which are applied via
[patchesStrategicMerge](https://kubectl.docs.kubernetes.io/references/kustomize/builtins/#_patchesstrategicmerge_).

### Complete configuration of the Data Plane

The [data plane hci overlay](../crs/data_plane/overlay/hci) adds
contains `extraMounts` and `customServiceConfig` for Nova to use
Ceph. It also restores the full service list so that the EDPM
deployment is complete. We also use `sed` to swap in the FSID.

```
pushd ~/antelope/crs/
FSID=$(oc get secret ceph-conf-files -o json | jq -r '.data."ceph.conf"' \
  | base64 -d | grep fsid | sed -e 's/fsid = //' | xargs)
kustomize build data_plane/overlay/hci | sed "s/_FSID_/${FSID}/" > data.yaml
oc apply -f data.yaml
popd
```

## Watch Ansible

```
oc get pods -w | grep edpm
oc logs -f dataplane-deployment-configure-network-edpm-compute-skw2g
```

## Test

Use [test.sh](../scripts/test.sh)

- Set `CEPH` to `1`
- Adjust other variables as needed

You should be able to create a glance image hosted on ceph and see it
in the images pool. You should then be able to create private network
and be able to boot a VM. You should also be able to attach a volume
to it.

## Clean

Use [rebuild.sh](../scripts/rebuild.sh) to attempt another deployment
or use [clean.sh](../scripts/clean.sh).
