# Using the ci-framework to test validated architectures

My goal is to deploy 
[va1](https://github.com/openstack-k8s-operators/architecture/tree/main/validated_arch_1)
using the
[ci-framework](https://github.com/openstack-k8s-operators/ci-framework).
on my RHEL9 hypervisor.

Follow the "On your own hardware"
[guide](https://ci-framework.readthedocs.io/en/latest/quickstart/04_non-virt.html)

I use the following so I can type less.

- [deploy.sh](deploy.sh)
- [clean.sh](clean.sh)

I have continue updating [my-env.yml](my-env.yml) until I'm happy with it.

## Open Questions

- How do increase the RAM/CPU on my deployed EDPM VMs?
  https://github.com/openstack-k8s-operators/ci-framework/pull/661

- How do I deploy without redeloying CRC?

Workaround: for now I let it deploy CRC and once I have a working
environment I just interact directly with OpenShift CRs.

- How do I redeploy only my compute nodes?

Workaround: install_yamls is ther so use it.

- How do I not deploy certain services? Can I pass my own CRs as input?

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
