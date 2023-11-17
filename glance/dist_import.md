# Distributed Image Import

Glance supports an
[interoperable image import
process](https://docs.openstack.org/glance/latest/admin/interoperable-image-import.html)
via
[import_plugins](https://github.com/openstack-k8s-operators/glance-operator/tree/main/config/samples/import_plugins).

The image itself, output by this process, will be stored in one
storage backend (e.g. Ceph RBD) but the process requires its own
separate storage staging area which the glance-operator provides
via a PVC.

Use of the RWX
[access mode](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#access-modes)
for the import PVC should be avoided because:

- Glance supports [distributed image import](https://opendev.org/openstack/glance/commit/41e1cecbe63c778ce8e92519993c61588ea1f0cb)
- The import will perform better by running on a non-shared filesystem
- Only a subset of popular PV backends support RWX access mode
- We want to fully support local-storage from OCP worker nodes and not
  require any type of special PV backend

[PR352](https://github.com/openstack-k8s-operators/glance-operator/pull/352)
moved the glance-operator to 
[StatefulSet](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset)
so that the following happens.

One glance pod with on PVC:
```
$ oc get pods | grep glance
glance-single-api-0                3/3     Running     0          22h
$ oc get pvc | grep glance
glance-glance-single-api-0          Bound     local-storage04-crc-lz7xw-master-0   10Gi       RWO,ROX,RWX    local-storage   22h
$ 
```
Scale to three glance pods:
```
oc patch openstackcontrolplane openstack-galera-network-isolation \
   --type merge -p '{"spec":{"glance":{"template":{"glanceAPI":{"replicas":3}}}}}'
```
Three glance pods where each has its own PVC:
```
$ oc get pods | grep glance
glance-single-api-0                3/3     Running     0          22h
glance-single-api-1                3/3     Running     0          20s
glance-single-api-2                0/3     Running     0          9s
$ oc get pvc | grep glance
glance-glance-single-api-0          Bound     local-storage04-crc-lz7xw-master-0   10Gi       RWO,ROX,RWX    local-storage   22h
glance-glance-single-api-1          Bound     local-storage10-crc-lz7xw-master-0   10Gi       RWO,ROX,RWX    local-storage   22h
glance-glance-single-api-2          Bound     local-storage11-crc-lz7xw-master-0   10Gi       RWO,ROX,RWX    local-storage   22h
$
```
