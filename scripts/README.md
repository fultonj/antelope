# Scripts

A guide to my [scripts](../scripts) directory.

- [deploy.sh](../scripts/deploy.sh) Deploy one CRC and three EDPM
  VMs with extra disks and network isolation.
- [ssh.sh](../scripts/ssh.sh) Print command to SSH to the Nth EDPM VM
- [test.sh](../scripts/test.sh) Test OpenStack by creating a VM which uses Ceph
- [clean.sh](../scripts/clean.sh) Remove what deploy.sh added

## Dependencies

Most of these scripts assume you have a copy of the following
repositories in your home directory.

- https://github.com/openstack-k8s-operators/install_yamls
- https://github.com/openstack-k8s-operators/dataplane-operator

I personally check out my own forks of the above projects and use them
in my home directory so that I can test my own patches.


