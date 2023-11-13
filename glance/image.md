## Build your own Glance operator image

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
