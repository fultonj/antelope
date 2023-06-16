# External Ceph

These are my notes on how to produce an external Ceph deployment like
the described in the upstream
[ceph docs](https://github.com/openstack-k8s-operators/docs/blob/main/ceph.md).
by using my [scripts](../scripts), [crs](../crs), and personal
conventions.

## VMs

- crc: hosts control plane pods
- edpm-compute-0: only hosts Ceph (not a real EDPM node)
- edpm-compute-1: hosts compute (real EDPM node)
- edpm-compute-2: hosts compute (real EDPM node)

The advantage of the above is that you can rebuild edpm-compute-{1,2}
without having to rebuild edpm-compute-0 so your Ceph cluster does not
need to be rebuilt when testing OpenStack. edpm-compute-0 is only used
as a hypervisor which is pre-configured into the networks. It could be
any VM but I use it this way to take advantage of existing VM building
scripts.

