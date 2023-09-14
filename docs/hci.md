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
export ANSIBLE_REMOTE_USER=cloud-admin
export ANSIBLE_SSH_PRIVATE_KEY=~/install_yamls/out/edpm/ansibleee-ssh-key-id_rsa
export ANSIBLE_HOST_KEY_CHECKING=False
```
Link the [ceph_overrides.yml](../misc/ansible/ceph_overrides.yml) from
the ci-framework.
```
ln -s ~/antelope/misc/ansible/ceph_overrides.yml ~/ci-framework/
```
Run the playbook with the overrides to deploy Ceph.
```
cd ~/ci-framework/
ansible-playbook ci_framework/playbooks/ceph.yml -e @ceph_overrides.yml
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

#### Create a snippet to configure Nova to use Ceph

The [ceph-nova.yaml](../crs/snippets/ceph-nova.yaml) configuration
snippet contains `[libivirt]` directives so that Nova instances
will use Ceph RBD.

Modify the snippet to add the Ceph FSID and create it.
```
pushd ~/antelope/crs/
FSID=$(oc get secret ceph-conf-files -o json | jq -r '.data."ceph.conf"' \
  | base64 -d | grep fsid | sed -e 's/fsid = //' | xargs)
sed -i "s/_FSID_/${FSID}/" snippets/ceph-nova.yaml
oc create -f snippets/ceph-nova.yaml
popd
```

Ensure that the
[libvirt-qemu-nova.yaml](../crs/snippets/libvirt-qemu-nova.yaml)
snippet has been created (so nested VMs can be booted).
```
oc create -f snippets/libvirt-qemu-nova.yaml
```

Create a custom version of the
[nova service](https://github.com/openstack-k8s-operators/dataplane-operator/blob/main/config/services/dataplane_v1beta1_openstackdataplaneservice_nova.yaml)
which ships with the operator so that it uses the snippets by
adding it to the `configMaps` list. E.g. here is
[my version (nova-custom-ceph)](../crs/services/dataplane_v1beta1_openstackdataplaneservice_nova_custom_ceph.yaml)
```
oc create -f services/dataplane_v1beta1_openstackdataplaneservice_nova_custom_ceph.yaml
```
The nova-custom-ceph service uses both snippets. Both contain
`[libvirt]` directives and Nova will effectively merge them.
```
  configMaps:
    - libvirt-qemu-nova
    - ceph-nova
```

#### Trigger the remaining Ansible jobs

The [data plane hci overlay](../crs/data_plane/overlay/hci) adds
`extraMounts` for the Ceph secret and replaces the `nova` service with
the `nova-custom-ceph` service which uses the configuration snippet.
It also restores the full service list so that the EDPM deployment is
complete.

```
pushd ~/antelope/crs/
kustomize build data_plane/overlay/hci > data.yaml
oc apply -f data.yaml
popd
```

An alternative to generating and applying the data.yaml file is to
`oc apply -k data_plane/overlay/hci/`.



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
