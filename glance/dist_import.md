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

If the Ceph RBD backend is enabled for Glance, then the
`image_conversion` plugin should be enabled.

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
Observe the configuration put in place by the `customServiceConfig`
from the
[glance-ceph overlay deployment.yaml](https://github.com/fultonj/antelope/blob/main/crs/control_plane/overlay/glance-ceph/deployment.yaml)

```
oc get secret glance-config-data -o json | jq -r '.data."01-config.conf"' | base64 -d
```
Use [conf-glance.sh](conf-glance.sh) to view all of the content in `glance-config-data`.

The `worker_self_reference_url` should be set to the internal API URL
for each node where glance api will run
[as was the case for TripleO](https://review.opendev.org/c/openstack/tripleo-heat-templates/+/882391).

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
The import staging area is set to
`/var/lib/glance/os_glance_staging_store/` via the
[glance-ceph overlay](../crs/control_plane/overlay/glance-ceph).
The PVCs are mounted into `/var/lib/glance`, so
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

### Test image import conversion from qcow2 to raw

Use [cmd-glances.sh](cmd-glances.sh) to see that `/var/lib/glance/` is
empty by default.

```
$ ./cmd-glances.sh ls -l /var/lib/glance/
> glance-external-api-0 ls -l /var/lib/glance/
total 0
> glance-external-api-1 ls -l /var/lib/glance/
total 0
> glance-external-api-2 ls -l /var/lib/glance/
total 0
$
```
Import the image.
```
openstack image create \
   --container-format bare \
   --disk-format raw \
   --file cirros.qcow2 \
   --import
```
...
