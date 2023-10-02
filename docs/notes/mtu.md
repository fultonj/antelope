# EDPM Development Environment with Jumbo Frames

[Ceph benefits from jumbo frames](https://access.redhat.com/documentation/en-us/red_hat_ceph_storage/6/html-single/hardware_guide/index)
so I configure my development environment to use it. I don't expect to
squeeze performance out of a one node system this way but I want my
examples to be applicable to a multinode cluster which would benefit
from this setting. As a side effect the Ceph deployed by my scripts
may fail
[cephx authentication](https://docs.ceph.com/en/latest/dev/cephx_protocol)
if the MTU is not set consistently.

My hypervisor usually runs 1 CRC VM and 3 EDPM VMs (which also host
Ceph). The default virsh network (192.168.122.0/24) is shared by all
four VMs. I set this network's MTU to 9000 with `virsh net-edit` such
that it's `net-dumpxml` output looks like this.

```yaml
[fultonj@hamfast ~]$ sudo virsh net-dumpxml default
<network>
  <name>default</name>
  <uuid>99d2c1b5-c103-4606-8190-91d14ece7fc3</uuid>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='virbr0' stp='on' delay='0'/>
  <mtu size='9000'/>
  <mac address='52:54:00:4B:69:63'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
      <host mac='52:54:00:C5:C8:C2' name='crc' ip='192.168.122.10'/>
    </dhcp>
  </ip>
</network>

[fultonj@hamfast ~]$ 
```

After rebooting my hypervisor after the above change I see `virbr0`
MTU is 9000.

```
[fultonj@hamfast ~]$ ip a s virbr0
3: virbr0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 9000 qdisc noqueue state DOWN group default qlen 1000
    link/ether 52:54:00:4B:69:63 brd ff:ff:ff:ff:ff:ff
    inet 192.168.122.1/24 brd 192.168.122.255 scope global virbr0
       valid_lft forever preferred_lft forever
[fultonj@hamfast ~]$ 
```

I run other OpenStack networks (`external` `internal_api` `tenant`)
at MTU 1500 but this gives me the ability to run `storage_mgmt` and
`storage` at MTU 9000. 

With the above changes made to the hypervisor, the following patches
result in a deployment where EDPM nodes can ping each other with jumbo
frames over the storage management network.

- https://github.com/fultonj/antelope/commit/08dfc87834127116d9de9b803075ef1f6fa20d4d
- https://github.com/fultonj/antelope/commit/8256767508ca3618240e860030ba886c09eb621d

```
[root@edpm-compute-0 ~]# ping -c 1 -M do -s 8972 172.20.0.101
PING 172.20.0.101 (172.20.0.101) 8972(9000) bytes of data.
8980 bytes from 172.20.0.101: icmp_seq=1 ttl=64 time=1.06 ms

--- 172.20.0.101 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 1.060/1.060/1.060/0.000 ms
[root@edpm-compute-0 ~]# 
```
