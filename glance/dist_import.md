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
so that when a glance pod is scaled, it automatically gets a new PVC
which is bound to it.

## Deployment

Deploy [minimal.sh](minimal.sh) with Ceph and 0 glance pods.

Deploy one Glance pair (internal/external) configured with a Ceph RBD
backend and distributed image import using the
[glance-ceph overlay](../crs/control_plane/overlay/glance-ceph).

```
pushd ~/antelope/crs/
kustomize build control_plane/overlay/glance-ceph > control.yaml
oc apply -f control.yaml
popd
```
Observe glance pods and PVCs
```
$ oc get pods | grep glance
glance-external-api-0         3/3     Running   0          8m7s
glance-internal-api-0         3/3     Running   0          8m7s
$ oc get pvc | grep glance
glance-glance-external-api-0        Bound     local-storage04-crc-lz7xw-master-0   10Gi       RWO,ROX,RWX    local-storage   8m14s
glance-glance-internal-api-0        Bound     local-storage01-crc-lz7xw-master-0   10Gi       RWO,ROX,RWX    local-storage   8m14s
$
```
Scale Glance replicas:
```
oc patch openstackcontrolplane openstack-galera-network-isolation \
  --type merge -p '{"spec":{"glance":{"template":{"glanceAPI":{"replicas":3}}}}}'
```
Observe new pods and PVCs:
```
$ oc get pods | grep glance
glance-external-api-0         3/3     Running   0          9m18s
glance-external-api-1         3/3     Running   0          22s
glance-external-api-2         0/3     Running   0          10s
glance-internal-api-0         3/3     Running   0          9m18s
glance-internal-api-1         3/3     Running   0          22s
glance-internal-api-2         0/3     Running   0          10s
$ oc get pvc | grep glance
glance-glance-external-api-0        Bound     local-storage04-crc-lz7xw-master-0   10Gi       RWO,ROX,RWX    local-storage   9m21s
glance-glance-external-api-1        Bound     local-storage02-crc-lz7xw-master-0   10Gi       RWO,ROX,RWX    local-storage   25s
glance-glance-external-api-2        Bound     local-storage08-crc-lz7xw-master-0   10Gi       RWO,ROX,RWX    local-storage   13s
glance-glance-internal-api-0        Bound     local-storage01-crc-lz7xw-master-0   10Gi       RWO,ROX,RWX    local-storage   9m21s
glance-glance-internal-api-1        Bound     local-storage07-crc-lz7xw-master-0   10Gi       RWO,ROX,RWX    local-storage   25s
glance-glance-internal-api-2        Bound     local-storage06-crc-lz7xw-master-0   10Gi       RWO,ROX,RWX    local-storage   13s
$
```
The import staging area default is
`/var/lib/glance/os_glance_staging_store/` and
the PVCs are mounted into `/var/lib/glance` so
each staging area will be unique per pod and
backed by each PVC.
```
$ oc get pod glance-external-api-0 -o yaml
...
    volumeMounts:
	...
    - mountPath: /var/lib/glance
      name: glance
  ...
  volumes:
  - name: glance
    persistentVolumeClaim:
      claimName: glance-glance-external-api-0
...
$
```

### Image Creation

todo: Import multiple qcow2 images and observe conversion to raw
