# Scripts

A guide to my scripts directory.

- [deploy.sh](deploy.sh) Deploy one CRC and N=3 EDPM
  VMs with extra disks and network isolation.
- [ssh_node.sh](ssh_node.sh) Print command to SSH to the Nth EDPM VM
- [test.sh](test.sh) Test OpenStack by creating an image,
  volume or VM
- [clean.sh](clean.sh) Remove what deploy.sh added
- [ceph](ceph) Directory of scripts related to Ceph

## Dependencies

Most of these scripts assume you have a copy of the following
repositories in your home directory.

- https://github.com/openstack-k8s-operators/install_yamls
- https://github.com/openstack-k8s-operators/dataplane-operator

I personally check out my own forks of the above projects and use them
in my home directory so that I can test my own patches.


