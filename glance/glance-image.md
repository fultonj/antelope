# Build your own Glance image

The [image document](image.md) is to build `glance-operator` container
image. This guide is to build your own version of
[openstack-glance-api](https://quay.io/repository/podified-antelope-centos9/openstack-glance-api?tab=tags) in
your own quay repository. The image can then be pushed to a RHOSO
deployment as described in
[dev-docs custom-images section](https://github.com/openstack-k8s-operators/dev-docs/blob/main/version_updates.md#custom-images-for-other-openstack-services).

In this example I want something like
`https://quay.io/repository/fultonj/openstack-glance-api`
to be like
[openstack-glance-api](https://quay.io/repository/podified-antelope-centos9/openstack-glance-api?tab=tags)
but to also have
[Glance patch 924824](https://review.opendev.org/c/openstack/glance/+/924824).

## Use TCIB to build first

Before I apply
[Glance patch 924824](https://review.opendev.org/c/openstack/glance/+/924824)
I just want to confirm I can build the same default image but host it
in my quay. I will use [TCIB](https://github.com/openstack-k8s-operators/tcib).
