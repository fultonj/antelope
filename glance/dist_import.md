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

The `worker_self_reference_url` should be set to the internal API URL
for each node where Glance API will run
[as was the case for TripleO](https://review.opendev.org/c/openstack/tripleo-heat-templates/+/882391). By
[glance-ceph overlay deployment.yaml](https://github.com/fultonj/antelope/blob/main/crs/control_plane/overlay/glance-ceph/deployment.yaml)
it is currently set to the internal API Endpoint of the Glance
service.
```
$ oc describe glance glance | grep 'API Endpoint' -A 1
  API Endpoint:
    Internal:  http://glance-internal.openstack.svc:9292
$
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

### Test image import conversion from qcow2 to raw

Define [bash functions](bash-functions.sh) so you can run `glance`,
`openstack`, `rbd` and `ceph` commands from the hypervisor.
```
source bash-functions.sh
```
Import the image using the `--uri`.
```
[fultonj@hamfast glance{main}]$ glance --verbose image-create-via-import --disk-format qcow2 --container-format bare --name cirros --uri http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img --import-method web-download
+-----------------------+--------------------------------------+
| Property              | Value                                |
+-----------------------+--------------------------------------+
| checksum              | None                                 |
| container_format      | bare                                 |
| created_at            | 2023-11-20T22:29:26Z                 |
| disk_format           | qcow2                                |
| id                    | 79fc5093-8b8d-4b3f-9b72-7342253374d6 |
| min_disk              | 0                                    |
| min_ram               | 0                                    |
| name                  | cirros                               |
| os_glance_import_task | b55cbe91-95a8-4a24-9cd2-e4367c3181d3 |
| os_hash_algo          | None                                 |
| os_hash_value         | None                                 |
| os_hidden             | False                                |
| owner                 | 8de96860a2b34858b0e41da848b1a910     |
| protected             | False                                |
| size                  | None                                 |
| status                | queued                               |
| tags                  | []                                   |
| updated_at            | 2023-11-20T22:29:26Z                 |
| virtual_size          | Not available                        |
| visibility            | shared                               |
+-----------------------+--------------------------------------+
[fultonj@hamfast glance{main}]$ 
```

Observe that the qcow2 file was converted to raw four seconds 
(created_at vs updated_at) after creation.

```
[fultonj@hamfast glance{main}]$ glance image-show 79fc5093-8b8d-4b3f-9b72-7342253374d6
+-------------------------------+----------------------------------------------------------------------------------+
| Property                      | Value                                                                            |
+-------------------------------+----------------------------------------------------------------------------------+
| checksum                      | ba3cd24377dde5dfdd58728894004abb                                                 |
| container_format              | bare                                                                             |
| created_at                    | 2023-11-20T22:29:26Z                                                             |
| disk_format                   | raw                                                                              |
| id                            | 79fc5093-8b8d-4b3f-9b72-7342253374d6                                             |
| min_disk                      | 0                                                                                |
| min_ram                       | 0                                                                                |
| name                          | cirros                                                                           |
| os_glance_failed_import       |                                                                                  |
| os_glance_importing_to_stores |                                                                                  |
| os_hash_algo                  | sha512                                                                           |
| os_hash_value                 | b795f047a1b10ba0b7c95b43b2a481a59289dc4cf2e49845e60b194a911819d3ada03767bbba4143 |
|                               | b44c93fd7f66c96c5a621e28dff51d1196dae64974ce240e                                 |
| os_hidden                     | False                                                                            |
| owner                         | 8de96860a2b34858b0e41da848b1a910                                                 |
| protected                     | False                                                                            |
| size                          | 46137344                                                                         |
| status                        | active                                                                           |
| stores                        | default_backend                                                                  |
| tags                          | []                                                                               |
| updated_at                    | 2023-11-20T22:29:30Z                                                             |
| virtual_size                  | 46137344                                                                         |
| visibility                    | shared                                                                           |
+-------------------------------+----------------------------------------------------------------------------------+
[fultonj@hamfast glance{main}]$ 
```
Observe from the `properties` that the image did not fail import.
```
[fultonj@hamfast glance{main}]$ openstack image show cirros
+------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Field            | Value                                                                                                                                                                                                                                                                              |
+------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| checksum         | ba3cd24377dde5dfdd58728894004abb                                                                                                                                                                                                                                                   |
| container_format | bare                                                                                                                                                                                                                                                                               |
| created_at       | 2023-11-20T22:29:26Z                                                                                                                                                                                                                                                               |
| disk_format      | raw                                                                                                                                                                                                                                                                                |
| file             | /v2/images/79fc5093-8b8d-4b3f-9b72-7342253374d6/file                                                                                                                                                                                                                               |
| id               | 79fc5093-8b8d-4b3f-9b72-7342253374d6                                                                                                                                                                                                                                               |
| min_disk         | 0                                                                                                                                                                                                                                                                                  |
| min_ram          | 0                                                                                                                                                                                                                                                                                  |
| name             | cirros                                                                                                                                                                                                                                                                             |
| owner            | 8de96860a2b34858b0e41da848b1a910                                                                                                                                                                                                                                                   |
| properties       | os_glance_failed_import='', os_glance_importing_to_stores='', os_hash_algo='sha512', os_hash_value='b795f047a1b10ba0b7c95b43b2a481a59289dc4cf2e49845e60b194a911819d3ada03767bbba4143b44c93fd7f66c96c5a621e28dff51d1196dae64974ce240e', os_hidden='False', stores='default_backend' |
| protected        | False                                                                                                                                                                                                                                                                              |
| schema           | /v2/schemas/image                                                                                                                                                                                                                                                                  |
| size             | 46137344                                                                                                                                                                                                                                                                           |
| status           | active                                                                                                                                                                                                                                                                             |
| tags             |                                                                                                                                                                                                                                                                                    |
| updated_at       | 2023-11-20T22:29:30Z                                                                                                                                                                                                                                                               |
| virtual_size     | 46137344                                                                                                                                                                                                                                                                           |
| visibility       | shared                                                                                                                                                                                                                                                                             |
+------------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
[fultonj@hamfast glance{main}]$ 
```
Observe that the image is stored in Ceph at 44 MiB.
```
[fultonj@hamfast glance{main}]$ rbd ls -l images
NAME                                       SIZE    PARENT  FMT  PROT  LOCK
79fc5093-8b8d-4b3f-9b72-7342253374d6       44 MiB            2
79fc5093-8b8d-4b3f-9b72-7342253374d6@snap  44 MiB            2  yes
[fultonj@hamfast glance{main}]$
```
I used [test-import.sh](test-import.sh) to repeat the above test many
times.

With the logs in debug mode I see the following:
```
$ export SVC=glance-external
$ ./logs-glances.sh -f
...
2023-11-21 19:49:09.277 46 DEBUG glance.async_.taskflow_executor [-] Task 'api_image_import-Convert_Image-f6378601-64a4-456b-a98e-ab00d932db62' (3a0441a1-ae3f-4e8d-b7dc-7bede13c0858) transitioned into state 'RUNNING' from state 'PENDING' _task_receiver /usr/lib/python3.9/site-packages/taskflow/listeners/logging.py:190
...
2023-11-21 19:49:09.337 46 DEBUG oslo_concurrency.processutils [-] Running cmd (subprocess): qemu-img convert -f qcow2 -O raw /var/lib/glance/os_glance_staging_store/9bca6d1b-95f7-4b22-ac67-0cccd9d83ee5 /var/lib/glance/os_glance_staging_store/9bca6d1b-95f7-4b22-ac67-0cccd9d83ee5.raw execute /usr/lib/python3.9/site-packages/oslo_concurrency/processutils.py:384
...
2023-11-21 19:49:09.391 46 DEBUG oslo_concurrency.processutils [-] CMD "qemu-img convert -f qcow2 -O raw /var/lib/glance/os_glance_staging_store/9bca6d1b-95f7-4b22-ac67-0cccd9d83ee5 /var/lib/glance/os_glance_staging_store/9bca6d1b-95f7-4b22-ac67-0cccd9d83ee5.raw" returned: 0 in 0.055s execute /usr/lib/python3.9/site-packages/oslo_concurrency/processutils.py:422
...
2023-11-21 19:49:09.392 46 INFO glance.async_.flows.plugins.image_conversion [-] Updated image 9bca6d1b-95f7-4b22-ac67-0cccd9d83ee5 size=117440512 disk_format=raw

2023-11-21 19:49:09.484 46 WARNING glance_store._drivers.rbd [-] Since image size is zero we will be doing resize-before-write which will be slower than normal
2023-11-21 19:49:09.565 46 DEBUG glance_store._drivers.rbd [-] resizing image to 8192.0 KiB _resize_on_write /usr/lib/python3.9/site-packages/glance_store/_drivers/rbd.py:523
2023-11-21 19:49:09.843 46 DEBUG glance_store._drivers.rbd [-] resizing image to 24576.0 KiB _resize_on_write /usr/lib/python3.9/site-packages/glance_store/_drivers/rbd.py:523
2023-11-21 19:49:10.272 46 DEBUG glance_store._drivers.rbd [-] resizing image to 57344.0 KiB _resize_on_write /usr/lib/python3.9/site-packages/glance_store/_drivers/rbd.py:523
2023-11-21 19:49:11.159 46 DEBUG glance_store._drivers.rbd [-] resizing image to 122880.0 KiB _resize_on_write /usr/lib/python3.9/site-packages/glance_store/_drivers/rbd.py:523

```
As per the logs the following command is run:
```
qemu-img convert -f qcow2 -O raw
  /var/lib/glance/os_glance_staging_store/9bca6d1b-95f7-4b22-ac67-0cccd9d83ee5 \
  /var/lib/glance/os_glance_staging_store/9bca6d1b-95f7-4b22-ac67-0cccd9d83ee5.raw
```

I see the image is correctly imported and converted.
