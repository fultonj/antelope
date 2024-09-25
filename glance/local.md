## Run local copy of the Glance operator

Update a [standard](../docs/standard.md) deployment so that it's using
a local copy with whatever patch I'm testing.

- Use [scale-down.sh](scale-down.sh) to disable the glance opeartor
  deployed by OLM

- Confirm you do not see the glance operator running anymore
```
oc get pods -n openstack-operators | grep glance
```

- Delete the StatefulSet
```
$ oc get statefulset | grep glance
glance-default-single    1/1     27h
$ oc delete statefulset glance-default-single
statefulset.apps "glance-default-single" deleted
$ 
```

- After the stateful set is deleted the running glance pod should shut
  itself down.
```
$ oc get pods | grep glance
glance-dbpurge-28787041-54kt5                                  0/1     Completed     0          20h
glance-default-single-0                                        3/3     Terminating   0          10m
$
```

- `make run-with-webhook` as per
  [PR178](https://github.com/openstack-k8s-operators/glance-operator/pull/178/files).
