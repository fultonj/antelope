# LVMS

These are my notes on creating and testing the `ci_lvms_storage`
Ansible role.

- We use
[LVMS](https://docs.openshift.com/container-platform/4.15/storage/persistent_storage/persistent_storage_local/persistent-storage-using-lvms.html)
(based on [TopoLVM](https://github.com/topolvm/topolvm))
[with install_yamls](https://github.com/fultonj/antelope/blob/main/docs/notes/lvms.md)
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
```
[zuul@controller-0 ~]$ ssh ocp-2 "lsblk"
Warning: Permanently added '192.168.111.22' (ED25519) to the list of known hosts.
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda      8:0    0  100G  0 disk 
├─sda1   8:1    0    1M  0 part 
├─sda2   8:2    0  127M  0 part 
├─sda3   8:3    0  384M  0 part /boot
└─sda4   8:4    0 79.5G  0 part /var/lib/kubelet/pods/a0dc0880-bbdb-4ad3-ba48-07c48fa90a45/volume-subpaths/nginx-conf/monitoring-plugin/1
                                /var
                                /sysroot/ostree/deploy/rhcos/var
                                /usr
                                /etc
                                /
                                /sysroot
vda    252:0    0   10G  0 disk 
vdb    252:16   0   10G  0 disk 
[zuul@controller-0 ~]$
```
