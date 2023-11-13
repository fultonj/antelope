## Run local copy of the Glance operator

Update a [standard](../docs/standard.md) deployment so that it's using
a local copy with whatever patch I'm testing.

- Use [scale-down.sh](scale-down.sh) to disable the glance opeartor
  deployed by OLM

- `make run-with-webhook` as per
  [PR178](https://github.com/openstack-k8s-operators/glance-operator/pull/178/files).
