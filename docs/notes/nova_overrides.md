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