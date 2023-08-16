# Debugging Nova Overrides

I have a configmap.

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nova-libvirt-qemu
data:
  02-nova-libvirt-qemu.conf: |
    [libvirt]
    virt_type = qemu
```

I have a service.

```yaml
---
apiVersion: dataplane.openstack.org/v1beta1
kind: OpenStackDataPlaneService
metadata:
  name: nova-compute
spec:
  label: dataplane-deployment-nova-compute
  configMaps:
    - nova-libvirt-qemu
  role:
    name: "Configure Nova libvirt"
    hosts: "all"
    strategy: "linear"
    tasks:
      - name: "Configure nova libivrt"
        import_role:
          name: "osp.edpm.edpm_nova"
```

I created a CR with with `install_yamls`.

```
pushd ~/install_yamls
DATAPLANE_CHRONY_NTP_SERVER=pool.ntp.org \
    DATAPLANE_TOTAL_NODES=3 \
    DATAPLANE_SINGLE_NODE=false \
    make edpm_deploy_prep
oc kustomize out/openstack/dataplane/cr > ~/data_plane.yaml
```

I updated the services list in my CR have my custom service.

```
[fultonj@hamfast crs]$ grep -A 10 services data_plane.yaml 
      services:
      - nova-compute
[fultonj@hamfast crs]$ 
```

After I create my CR with `oc create -f ~/data_plane.yaml` I see
ansible run.

```
[fultonj@hamfast ~]$ oc get pods | grep nova-compute
dataplane-deployment-nova-compute-edpm-compute-fl5hw   0/1     Completed   0          18m
[fultonj@hamfast ~]$ 
```

I can see the resultant file has been copied to my compute node.
```
[root@edpm-compute-0 ~]# cat /var/lib/openstack/config/nova/02-nova-libvirt-qemu.conf
[libvirt]
virt_type = qemu
[root@edpm-compute-0 ~]# 
```
However, I do not see the file inside my nova_compute container.
```
[root@edpm-compute-0 ~]# podman exec -ti nova_compute ls -l /etc/nova/nova.conf.d/
total 4
-rw-------. 1 nova nova 3804 Aug 16 11:25 01-nova.conf
[root@edpm-compute-0 ~]# 
```
This is because the snippet file name needs to end in "nova.conf" or
it won't be copied from `host:/var/lib/openstack/config/nova` to
`container:/etc/nova/nova.conf.d/`.

When I
[renamed](https://github.com/fultonj/antelope/commit/485bd56ab08cbc9c5bf87291f9cae9b762d25f35)
the service it worked.
```
[root@edpm-compute-0 ~]# podman exec -ti nova_compute ls -l /etc/nova/nova.conf.d/
total 8
-rw-------. 1 nova nova 3804 Aug 16 13:45 01-nova.conf
-rw-------. 1 nova nova   27 Aug 16 13:45 02-libvirt-qemu-nova.conf
[root@edpm-compute-0 ~]#
```

The following PR changes the pattern from "*nova.conf" to
"*nova*.conf".

https://github.com/openstack-k8s-operators/edpm-ansible/pull/282
