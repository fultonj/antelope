# LVMS

These are my notes on creating and testing the `ci_lvms_storage`
Ansible role.

- We use
[LVMS](https://docs.openshift.com/container-platform/4.15/storage/persistent_storage/persistent_storage_local/persistent-storage-using-lvms.html)
(based on [TopoLVM](https://github.com/topolvm/topolvm))
[with install_yamls](../docs/notes/lvms.md)
and should also use it with
[ci-framework](https://github.com/openstack-k8s-operators/ci-framework/).

- [ci_local_storage](https://github.com/openstack-k8s-operators/ci-framework/tree/main/roles/ci_local_storage)
([called here](https://github.com/openstack-k8s-operators/ci-framework/blob/main/playbooks/06-deploy-edpm.yml#L26-L28))
should be replaced by a new role
`ci_lvms_storage`.

## Prerequisites

Call the ci-framework as usual but pass these overrides.
```
cifmw_devscripts_config_overrides:
  vm_extradisks: "true"
  vm_extradisks_list: "vdb vda"
  vm_extradisks_size: "10G"
```
On the the three CoreOS systems root will be mounted on `/dev/sda` but
`/dev/vda` and `/dev/vdb` will be available to back LVMS.

To get a feel of what Ansible has to automate read [manual](manual.md).
