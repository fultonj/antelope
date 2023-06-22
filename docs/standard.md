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

## Prepare

Use [deploy.sh](../scripts/deploy.sh) with:

- Repeat for each boolean separately from `CRC` to `CONTROL`
- Use `NODES=0` and `NODE_START=0`

You should then have a working control plane running on crc
and `edpm-compute-0` will be ready to be configured. Use
[ssh_node.sh](../scripts/ssh_node.sh) for a command to use
to SSH into it.

## Create an OpenStackDataPlane CR with edpm_deploy_prep

Create a `dataplane.yaml` file in your current directory.
```
TARGET=$PWD/dataplane.yaml
pushd ~/install_yamls
DATAPLANE_CHRONY_NTP_SERVER=pool.ntp.org \
    DATAPLANE_SINGLE_NODE=true \
    make edpm_deploy_prep
oc kustomize out/openstack/dataplane/cr > $TARGET
popd
```
Edit this file if necessary.

## Run EDPM Ansible
```
oc create -f dataplane.yaml
```
I then like to use the following to watch the playbooks:
```
oc get pods -w | grep edpm
oc logs -f dataplane-deployment-configure-network-edpm-compute-skw2g
```

### Re-run Ansible to apply configuration updates

If you need to make a configuration update, edit `dataplane.yaml` and
and run `oc apply -f dataplane.yaml`. For example, change this line:

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
and then run `oc apply -f dataplane.yaml`. You should see new ansible
jobs run via `oc get pods -w | grep edpm`. Then you can inspect your
compute node to see if it got the configuration change.

```
$(./ssh_node.sh)
podman exec -ti nova_compute /bin/bash
cat /etc/nova/nova.conf.d/02-nova-override.conf
```
I personally use `virt_type = qemu` on my hypervisor for test VMs.

### Stop Failing Ansible Jobs

If you want to tell the dataplane-operator to stop spawning Ansible
jobs, then delete the `OpenStackDataPlane` CR.
```
oc delete -f dataplane.yaml
```
You can then edit your `dataplane.yaml` accordingly and recreate it to
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

Use [clean.sh](../scripts/clean.sh) with:

- Repeat for each boolean separately from `DPJOBS` to `CRC` but
  keep `CEPH_CLI` and `CEPH_K8S` set to `0`
- Use `NODES=0` and `NODE_START=0`
