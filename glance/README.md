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

