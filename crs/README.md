# CRs

A guide to my [CRs](../crs) directory.

The [openstack-k8s-operators](https://github.com/openstack-k8s-operators)
project provides
[operators](https://www.redhat.com/en/topics/containers/what-is-a-kubernetes-operator)
so you can deploy and manage OpenStack with
[CRs](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources).

You can generate CRs with 
[install_yamls](https://github.com/openstack-k8s-operators/install_yamls)
and then use [kustomize](https://kustomize.io) to modify them. This
directory holds kustomize files for my environment.
