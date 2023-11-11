# Glance

My notes for working on the
[glance-operator](https://github.com/openstack-k8s-operators/glance-operator).

## Run a Local Copy

Update a [standard](../docs/standard.md) deployment so that it's using
a local copy with whatever patch I'm testing.

- Use [scale-down.sh](scale-down.sh) to disable the glance opeartor
  deployed by OLM

- `make run-with-webhook` as per
  [PR178](https://github.com/openstack-k8s-operators/glance-operator/pull/178/files).

## Build an image with your patch

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
