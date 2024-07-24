# Build your own Glance operator image

This guide is to build your own glace-operator image. To build your
own glance-api image see the [glance-image document](glance-image.md).

Use the quay.io web interface to create an encrypted password and
confirm it works with `podman login`.
```
podman login -u="fultonj" -p="************" quay.io
```
Build and push the container.
```
make docker-build IMG=quay.io/fultonj/glance-operator:fultonj-test
make docker-push IMG=quay.io/fultonj/glance-operator:fultonj-test
```
Observe the image:

  https://quay.io/repository/fultonj/glance-operator?tab=tags

Use the settings tab to make it public so that the OLM can download it.

  https://quay.io/repository/fultonj/glance-operator?tab=settings

Use [operator-image.sh](operator-image.sh) to tell the CSV to use the
new image.

## Default Glance Operator Image

[operator-image.sh](operator-image.sh) defaults its new image to
```
  quay.io/openstack-k8s-operators/glance-operator:latest
```
Running `make openstack` tends bring in an older image than the latest
because images are built from new PRs to glance-operator more often
than the meta operator is updated via the following process.

- The tag stored in each release of the meta operator comes from [line 29 in pin-bundle-images.sh](https://github.com/openstack-k8s-operators/openstack-operator/blob/c024ab05e17eb70334194b5eacc95a912538ba7d/hack/pin-bundle-images.sh#L29)

- Which comes from `go list -mod=readonly -m -json all` as per [line 23 in pin-bundle-images.sh](https://github.com/openstack-k8s-operators/openstack-operator/blob/c024ab05e17eb70334194b5eacc95a912538ba7d/hack/pin-bundle-images.sh#L23)

- All of which is based on the values in [go.mod](https://github.com/openstack-k8s-operators/openstack-operator/blob/main/go.mod)

- Which gets updated by PRs like https://github.com/openstack-k8s-operators/openstack-operator/pull/535
