# POC an Interface for Validated Architectures

Create a method for the
[ci-framework](https://github.com/openstack-k8s-operators/ci-framework)
to deploy
[VA1](https://github.com/openstack-k8s-operators/architecture/tree/main/validated_arch_1)
where CRs are the primary interface but the deployment can still be automated.

## Prerequisite

An OpenShift cluster with the
[openstack-k8s-operators](https://github.com/openstack-k8s-operators)
already running. This could be provided by a partial deployment of any
of the following.

- [ci-framework and dev-scripts](https://github.com/openstack-k8s-operators/ci-framework/pull/690)
- [ci-framework and crc](https://ci-framework.readthedocs.io/en/latest/quickstart/04_non-virt.html)
- [install_yamls and my scripts](../docs/standard.md) ([va_prereq.sh](../scripts/va_prereq.sh))

The environment environment should look like this.
```
[fultonj@hamfast va1{main}]$ oc get pods -n openstack-operators | wc -l
43
[fultonj@hamfast va1{main}]$ oc get pods -n openstack | wc -l
No resources found in openstack namespace.
0
[fultonj@hamfast va1{main}]$
```

## Approach

[VA1](https://github.com/openstack-k8s-operators/architecture/tree/main/validated_arch_1) 
is run in six stages. This approach will skip stages 1-3 for now since
they are covered by the prerequisites above.

1. [Install dependencies for the OpenStack K8S operators](https://github.com/openstack-k8s-operators/architecture/tree/main/validated_arch_1/stage1)
2. [Install the OpenStack K8S operators](https://github.com/openstack-k8s-operators/architecture/tree/main/validated_arch_1/stage2)
3. [Configuring networking on the OCP nodes](https://github.com/openstack-k8s-operators/architecture/tree/main/validated_arch_1/stage3)

We will focus on implementing stages 4-6 below.

4. [Configure and deploy the control plane](https://github.com/openstack-k8s-operators/architecture/tree/main/validated_arch_1/stage4)
5. [Configure and deploy the initial data plane to prepare for CephHCI installation](https://github.com/openstack-k8s-operators/architecture/tree/main/validated_arch_1/stage5)
6. [Update the control plane and finish deploying the data plane after CephHCI has been installed](https://github.com/openstack-k8s-operators/architecture/tree/main/validated_arch_1/stage6)

## Configure and deploy the control plane

todo...
