# DNS Problems for RGW with TLS

[fmount](https://github.com/fmount) came up with this solution.

## Problem Overview

- Tempest object storage tests pass using RGW over HTTP but not HTTPS
- The RGW VIP is hosted outside of k8s (on EDPM nodes or anywhere)
- To get HTTPS we need a certificate for the VIP by DNS name (not IP)

Thus, we need one of our DNS servers to resolve the RGW VIP name.
But which DNS server, i.e. who's using what DNS server?

1. All pods use [OpenShift CoreDNS](https://docs.openshift.com/container-platform/4.15/networking/dns-operator.html)
2. All EDPM services use a dnsmasq server deployed by the openstack
   operator to resolve k8s openstack pods

We need k8s pods (like the openstackclient or tempest test pods)
to be able to resolve the VIP for RGW which will be hosted on the
external network (which today we're faking with 192.168.122.0/24).

To solve this problem we:

1. Create a `ceph.local` DNS zone with the VIP (implemented by dnsmasq)
2. Tell OpenShift CoreDNS to forward queries for `ceph.local` to the new dnsmasq

This applies the pattern from
[configure DNS forwarding](https://docs.openshift.com/container-platform/4.15/networking/dns-operator.html#nw-dns-forward_dns-operator)
and is similar to what we're doing for EDPM nodes so they can resolve
IPs hosted on k8s openstack pods.

We need to document how to configure RGW with TLS this way and the
ci-framework needs to automate this process.

## Implementation

### Create a `ceph.local` DNS zone with the VIP (implemented by dnsmasq)

[ceph-dns.yml](ceph-dns.yml) triggers the rollout of a new
`dnsmasq` Pod, that is able to resolve hosts in a new `ceph.local`
domain.

### Register the `edpm.local` zone with dns-default service

1. Identify the IP address of the OpenShift DNS service in the opesntack namespace
```
DNS=$(oc -n openstack get svc dnsmasq-dns -o jsonpath='{.spec.clusterIP}')
```
2. Create a snippet (with this IP) to patch the dns-default service

Examine the openshift-dns service.
```
oc get -n openshift-dns dns.operator/default -o yaml
```
Note that the above is not going to be the same as
`oc -n openshift-dns get svc -o yaml` or
`oc -n openstack get svc dnsmasq-dns -o yaml`.

Use [snippet.yml](snippet.yml) to create a patch to the service
```
cat snippet.yml | sed s/DNS/$DNS/g > openshift_dns_patch.yaml
```
The snippet instructs the DNS instance to forward requests for the
`edpm.local` zone to the `dnsmasq` deployed in the previous step.

3. Update the service
```
oc -n openshift-dns edit dns.operator/default
```
In the editor window add the snippet. In theory it could be added by
doing something like this.
```
oc -n openshift-dns patch dns.operator/default --type=merge --patch-file openshift_dns_patch.yaml
```
Confirm the change was applied:
```
[zuul@controller-0 dns]$ oc get -n openshift-dns dns.operator/default -o yaml | grep ceph -B 5
  servers:
  - forwardPlugin:
      policy: Random
      upstreams:
      - 172.30.248.195:53
    name: ceph
    zones:
    - ceph.local
[zuul@controller-0 dns]$
```
4. Confirm the VIP resolves from an openstack pod

```
oc rsh openstackclient ping rgw-external.ceph.local
```
For example:
```
[zuul@controller-0 dns]$ oc rsh openstackclient ping -c 1 rgw-external.ceph.local
PING rgw-external.ceph.local (192.168.122.2) 56(84) bytes of data.
64 bytes from 192.168.122.2 (192.168.122.2): icmp_seq=1 ttl=63 time=0.254 ms

--- rgw-external.ceph.local ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.254/0.254/0.254/0.000 ms
[zuul@controller-0 dns]$
```
Once the VIP by name is working, it needs to be added as a subjct alt
name to the certificate.
