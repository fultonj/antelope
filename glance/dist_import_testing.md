# Test image import conversion from qcow2 to raw

Define [bash functions](functions.sh) so you can run `glance`,
`openstack`, `rbd` and `ceph` commands from the hypervisor.
```
source functions.sh
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

### Observe Import tasks

Observe the log of tasks run to import an image.
```
[fultonj@hamfast glance{main}]$ glance task-list
+--------------------------------------+------------------+---------+----------------------------------+
| ID                                   | Type             | Status  | Owner                            |
+--------------------------------------+------------------+---------+----------------------------------+
| 8ef3acee-e5bd-4649-ba7e-dae5c2353420 | api_image_import | success | 6b449bc48de9428ca41c28739b70fd1f |
...
| 321534fa-c5da-45d7-8dd5-636c22e8cf4e | api_image_import | success | 6b449bc48de9428ca41c28739b70fd1f |
+--------------------------------------+------------------+---------+----------------------------------+
```
This task is from when [test-import.sh](test-import.sh) is used
with `GLANCE_CLI=0` and `WEB=0`
```
[fultonj@hamfast glance{main}]$ glance task-show 8ef3acee-e5bd-4649-ba7e-dae5c2353420
+------------+----------------------------------------------------------------------------------+
| Property   | Value                                                                            |
+------------+----------------------------------------------------------------------------------+
| created_at | 2023-11-21T22:15:34Z                                                             |
| expires_at | 2023-11-23T22:15:35Z                                                             |
| id         | 8ef3acee-e5bd-4649-ba7e-dae5c2353420                                             |
| image_id   | ffdd548e-e028-4bd8-a158-230ce2fc1a4a                                             |
| input      | {"image_id": "ffdd548e-e028-4bd8-a158-230ce2fc1a4a", "import_req": {"method":    |
|            | {"name": "glance-direct"}}, "backend": ["default_backend"]}                      |
| message    | Copied 0 MiB                                                                     |
| owner      | 6b449bc48de9428ca41c28739b70fd1f                                                 |
| request_id | req-7d80cf93-a90f-42cd-abc3-87adc2dde271                                         |
| result     | {"image_id": "ffdd548e-e028-4bd8-a158-230ce2fc1a4a"}                             |
| status     | success                                                                          |
| type       | api_image_import                                                                 |
| updated_at | 2023-11-21T22:15:35Z                                                             |
| user_id    | 0d4040d6ce5d40fdb1739abdb23e798c                                                 |
+------------+----------------------------------------------------------------------------------+
[fultonj@hamfast glance{main}]$
```
This task is from when [test-import.sh](test-import.sh) is used
with `WEB=1`.
```
[fultonj@hamfast glance{main}]$ glance task-show 321534fa-c5da-45d7-8dd5-636c22e8cf4e
+------------+----------------------------------------------------------------------------------+
| Property   | Value                                                                            |
+------------+----------------------------------------------------------------------------------+
| created_at | 2023-11-21T18:59:21Z                                                             |
| expires_at | 2023-11-23T18:59:28Z                                                             |
| id         | 321534fa-c5da-45d7-8dd5-636c22e8cf4e                                             |
| image_id   | b73875c3-7186-4a8e-8d84-def508f57304                                             |
| input      | {"image_id": "b73875c3-7186-4a8e-8d84-def508f57304", "import_req": {"method":    |
|            | {"name": "web-download", "uri": "http://download.cirros-                         |
|            | cloud.net/0.5.2/cirros-0.5.2-x86_64-disk.img"}}, "backend": ["default_backend"]} |
| message    | Copied 112 MiB                                                                   |
| owner      | 6b449bc48de9428ca41c28739b70fd1f                                                 |
| request_id | req-5cd8a4de-85ae-4161-9c06-f51f9d951a63                                         |
| result     | {"image_id": "b73875c3-7186-4a8e-8d84-def508f57304"}                             |
| status     | success                                                                          |
| type       | api_image_import                                                                 |
| updated_at | 2023-11-21T18:59:28Z                                                             |
| user_id    | 0d4040d6ce5d40fdb1739abdb23e798c                                                 |
+------------+----------------------------------------------------------------------------------+
[fultonj@hamfast glance{main}]$
```
