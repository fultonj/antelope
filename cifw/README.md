# Using the ci-framework to test validated architectures

My goal is to deploy 
[va1](https://github.com/openstack-k8s-operators/architecture/tree/main/validated_arch_1)
using the
[ci-framework](https://github.com/openstack-k8s-operators/ci-framework).
on my RHEL9 hypervisor.

While doing so it is also useful to experiment with having a
an architecture similar to va1 deployed in RDO CI
as described in [CI for HCI](ci_hci.md).

Follow the "On your own hardware"
[guide](https://ci-framework.readthedocs.io/en/latest/quickstart/04_non-virt.html)

I'm deploying with CRC today. I hope to swap it out for 3 OpenShift
all-in-one nodes (VMs) but right now my priority is to get a good way
to deploy VA1 using ci-framework.

I use the following so I can type less.

- [deploy.sh](deploy.sh)
- [clean.sh](clean.sh)

I have continue updating [my-env.yml](my-env.yml) until I'm happy with it.

## Open Questions

### How do increase the RAM/CPU on my deployed EDPM VMs?

https://github.com/openstack-k8s-operators/ci-framework/pull/661

### How do I deploy without redeloying CRC? (need real fix)

Workaround: for now I let it deploy CRC and once I have a working
environment I just interact directly with OpenShift CRs.

"No cleaning logic (yet). If crc is present, it shouldn't try to
override it. It shouldn't recreate anything that is already existing
in fact. If you want to re-create the compute(s), remove them from
libvirt, and re-run. It should regenerate the things."

### How do I redeploy only my control plane pods compute nodes? (need real fix)

Workaround: install_yamls is there so use it.

### Can I pass my own CRs as input? (need real fix)

Workaround: Once the basic services get deployed I get into my
environment and directly edit the CRs. Example:

Why is the task for installing the control plane not finished yet?
```
$ oc get pods
...
ceilometer-7c4498d6f8-r5c4s            2/3     ImagePullBackOff   0          17m
```
Oh, ceilometer image can't be downloaded. I don't need that.

```
$ oc edit openstackcontrolplane
```
After setting `enabled: false` and exiting it quickly finished.
