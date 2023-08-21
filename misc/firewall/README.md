# Notes from Debugging EDPM Firewall

## How it works

Services with Ansible roles, e.g. 
[edpm_ceph_hci_pre](https://github.com/openstack-k8s-operators/edpm-ansible/tree/main/roles/edpm_ceph_hci_pre),
should create a YAML file like
[ceph-networks.yaml](ceph-networks.yaml)
and ensure it is in `/var/lib/edpm-config/firewall/` on EDPM nodes.

When the `run-os`
[composable service](https://openstack-k8s-operators.github.io/dataplane-operator/composable_services/)
runs it executes the role
[edpm_nftables](https://github.com/openstack-k8s-operators/edpm-ansible/tree/main/roles/edpm_nftables)
This role reads files in `/var/lib/edpm-config/firewall/`
and creates a `edpm-rules.nft` file in `/etc/nftables/` and then
configures the live firewall to use it.

For example, this stanza:
```
- rule_name: "110 allow ceph_mon from 172.18.0.0/24"
  rule:
    proto: tcp
    dport: [6789, 3300]
    source: 172.18.0.0/24
```
begats these lines:
```
[root@edpm-compute-0 ~]# grep ceph /etc/nftables/*
...
/etc/nftables/edpm-rules.nft:# 110 allow ceph_mon from 172.18.0.0/24 {'proto': 'tcp', 'dport': [6789, 3300], 'source': '172.18.0.0/24'}
/etc/nftables/edpm-rules.nft:add rule inet filter EDPM_INPUT ip saddr 172.18.0.0/24 tcp dport { 6789,3300 } ct state new counter accept comment "110 allow ceph_mon from 172.18.0.0/24"
...
[root@edpm-compute-0 ~]#
```
begats this line:
```
[root@edpm-compute-0 ~]# nft list ruleset
...
		ip saddr 172.18.0.0/24 tcp dport { 3300, 6789 } ct state new counter packets 8 bytes 480 accept comment "110 allow ceph_mon from 172.18.0.0/24"
...
[root@edpm-compute-0 ~]#
```
and then TCP ports 3300 and 6789 are accessible from source address 172.18.0.0/24.

## Debugging

If you want to quickly see how a file
like [ceph-networks.yaml](ceph-networks.yaml)
will be handled by
[edpm_nftables](https://github.com/openstack-k8s-operators/edpm-ansible/tree/main/roles/edpm_nftables),
then shorten the `services` list in your DataPlane CR to only the
following.
```
      services:
      - configure-os
      - run-os
```
