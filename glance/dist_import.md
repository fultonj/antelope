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
oc get secret glance-external-config-data -o json | jq -r '.data."02-config.conf"' | base64 -d
```

Use [conf-glance.sh](conf-glance.sh) to view all of the content in `glance-external-config-data`.

## worker_self_reference_url

The `worker_self_reference_url` should be set to the internal API URL
for each node where Glance API will run
[as was the case for
TripleO](https://review.opendev.org/c/openstack/tripleo-heat-templates/+/882391).

For now,
[glance-ceph overlay deployment.yaml](https://github.com/fultonj/antelope/blob/main/crs/control_plane/overlay/glance-ceph/deployment.yaml)
sets it to the internal API Endpoint of the Glance service.
```
$ oc describe glance glance | grep 'API Endpoint' -A 1
  API Endpoint:
    Internal:  http://glance-internal.openstack.svc:9292
$
```
However, as per the
[Staging Directory Configuration](https://docs.openstack.org/glance/latest/admin/interoperable-image-import.html#staging-directory-configuration):

> [!NOTE]
> If local storage is chosen, you must configure each worker with the
> URL by which the other workers can reach it directly. This allows
> one worker behind a load balancer to stage an image in one request,
> and another worker to handle the subsequent import request. As an
> example:
> ```
> [DEFAULTS]
> worker_self_reference_url = https://glance01.example.com:8000
> ```
> This assumes you have several glance-api workers named glance01,
> glance02, etc behind your load balancer.
>
> Note that public_endpoint will be used as the default if
> `worker_self_reference_url` is not set. As this will generally be
> set to the same value across all workers, the result is that all
> workers will assume the same identity and thus revert to
> shared-staging behavior.
>
> If public_endpoint is set differently for one or a group of workers,
> they will be considered isolated and thus not sharing staging
> storage.

Because we are avoiding shared-staging behavior, we should not be
setting the `worker_self_reference_url` to the load balanced SVC
endpoint. Instead the operator should be setting the IP and port for
each Glance pod. It's assumed that the pods can communicate with each
other on the same internal API network.

As described in
[the worker_self_reference_url commit](https://opendev.org/openstack/glance/commit/41e1cecbe63c778ce8e92519993c61588ea1f0cb)

> [!NOTE]
> When an image was staged on another worker, that worker may record its
> worker_self_reference_url on the image, indicating that other workers
> should proxy requests to it while the image is staged. This method
> replays our current request against the remote host, returns the
> result, and performs any response error translation required.

The above is based on the idea that one container is the same as one
deployment. However, as the glance-operator is currently written
this is not the case; the stateful set shares the IP. The output `oc
describe pod glance-external-api-` will confirm this for the storage
IP (though we want the internal API IP). However, after
[this patch](https://github.com/openstack-k8s-operators/glance-operator/compare/main...fmount:glance-operator:list_of_glanceapi)
merges, glance `api0` and `api1` will be two diff statefulsets backed
by two different services. Thus, the following will be two different
services with two different end points.

- glance-api0-{internal,external} --> glance-api0-internal.openstack.svc:9292
- glance-api1-{internal,external} --> glance-api1-internal.openstack.svc:9292

We can then have the glance-operator dynamically set the
`worker_self_reference_url` to the service endpoint for each
stateful set.

## Replicas and PVCs

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
The import staging area
[defaults](https://github.com/openstack-k8s-operators/glance-operator/blob/25683ec68a7f6b0c5001a68d9a153e0aadb41886/templates/glance/config/00-config.conf#L88)
to
`/var/lib/glance/os_glance_staging_store/`.
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
The glance external logs in debug mode show the following:
```
2023-11-21 18:10:29.168 1 INFO glance_store._drivers.filesystem [-]
Directory to write image files does not exist (/var/lib/glance/os_glance_staging_store/). Creating.
```

You can confirm this directory is created in the `glance-api`
container in the `glance-external-api-0` pod.

```
[fultonj@hamfast ~]$ oc rsh -c glance-api glance-external-api-0
sh-5.1# ls /var/lib/glance/
os_glance_staging_store  os_glance_tasks_store
sh-5.1#
exit
[fultonj@hamfast ~]$
```
There are three containers in the `glance-external-api-0` pod.
```
[fultonj@hamfast ~]$ for POD in $(oc get pods glance-external-api-0 -o jsonpath='{.spec.containers[*].name}'); do echo $POD; done
glance-log
glance-httpd
glance-api
[fultonj@hamfast ~]$
```
If you don't specify the container with `-c`, you'll get the first
pod, `glance-log`, which doesn't have this directory. Use `oc describe
pod glance-external-api-` to see other details about what is in the
pod.

## Reproduce the problem

With replica three and `worker_self_reference_url` not set to
individual nodes, we can reproduce the problem which
[the worker_self_reference_url commit](https://opendev.org/openstack/glance/commit/41e1cecbe63c778ce8e92519993c61588ea1f0cb)
solves. An attempt to import an image will result in it being stuck in
a state of `importing`.

The [test-import.sh](test-import.sh) script be configured to run the
following commands:
```
glance --verbose image-create \
   --disk-format raw \
   --container-format bare \
   --name $NAME
ID=$(openstack image show $NAME -c id -f value | strings)
glance image-stage --progress --file $CIR $ID
bash cmd-glances.sh ls -lh /var/lib/glance/os_glance_staging_store
glance image-import --import-method glance-direct $ID
```
With the script running we can observe the following:
```
> glance-external-api-0 ls -lh /var/lib/glance/os_glance_staging_store
> glance-external-api-1 ls -lh /var/lib/glance/os_glance_staging_store
total 0
> glance-external-api-2 ls -lh /var/lib/glance/os_glance_staging_store
total 4.0K
-rw-r-----. 1 root root 273 Nov 25 16:33 c45160f8-0412-45da-acce-3346cdbde1c4
```
The above is from a call to [cmd-glances.sh](cmd-glances.sh)
to list the contents of the staging directory. We see that the image
has been staged on `glance-external-api-2`.

We then see the following in the logs of `glance-external-api-0`.
```
2023-11-25 16:33:20.753 45 ERROR glance.async_.taskflow_executor
Stderr: "qemu-img: Could not open
'/var/lib/glance/os_glance_staging_store/c45160f8-0412-45da-acce-3346cdbde1c4':
Could not open
'/var/lib/glance/os_glance_staging_store/c45160f8-0412-45da-acce-3346cdbde1c4':
No such file or directory\n"
```

The problem is:

- glance-external-api-2 has staged the image at
  /var/lib/glance/os_glance_staging_store/c45160f8-0412-45da-acce-3346cdbde1c4
  on its PVC
- glance-external-api-0 is trying to process it at the same path but
  cannot find it on its PVC

glance-external-api-0 should be able to read the image's
`worker_self_reference_url` and it should return
glance-external-api-2, because that's the server which staged the
image. glance-external-api-0 should then be able to stream the
image from glance-external-api-2 so that it can then complete
the image's import and set it to active.

I assume the `worker_self_reference_url` is working because when I
repeat the test and query the glance database, its value was stored
like this:
```
[fultonj@hamfast glance{main}]$ gsql "SELECT * FROM image_properties WHERE image_id=\"$ID\" AND name='os_glance_stage_host'"
+----+--------------------------------------+----------------------+-------------------------------------------+---------------------+---------------------+---------------------+---------+
| id | image_id                             | name                 | value                                     | created_at          | updated_at          | deleted_at          | deleted |
+----+--------------------------------------+----------------------+-------------------------------------------+---------------------+---------------------+---------------------+---------+
|  8 | 7b73dd6b-f9c5-4082-b4b7-309842075094 | os_glance_stage_host | http://glance-internal.openstack.svc:9292 | 2023-11-27 20:12:28 | 2023-11-27 20:12:41 | 2023-11-27 20:12:41 |       1 |
+----+--------------------------------------+----------------------+-------------------------------------------+---------------------+---------------------+---------------------+---------+
[fultonj@hamfast glance{main}]$
```
I assume the problem is that http://glance-internal.openstack.svc:9292
will load balance across the glance workers so odds are only 1 our of
N (for N workers) that the right image will be found.

## Test image staging and conversion during import

- Use [test-import.sh](test-import.sh)
- Run commands directly, with one replica, as seen in
  [dist_import_testing.md](dist_import_testing.md)
