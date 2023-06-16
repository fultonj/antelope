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
