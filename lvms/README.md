# LVMS

These are my notes on creating and testing the `ci_lvms_storage`
Ansible role.

- We use
[LVMS](https://docs.openshift.com/container-platform/4.15/storage/persistent_storage/persistent_storage_local/persistent-storage-using-lvms.html)
(based on [TopoLVM](https://github.com/topolvm/topolvm))
[with install_yamls](../docs/notes/lvms.md)
and should also use it with
[ci-framework](https://github.com/openstack-k8s-operators/ci-framework/).

- [ci_local_storage](https://github.com/openstack-k8s-operators/ci-framework/tree/main/roles/ci_local_storage)
([called here](https://github.com/openstack-k8s-operators/ci-framework/blob/main/playbooks/06-deploy-edpm.yml#L26-L28))
should be replaced by a new role
`ci_lvms_storage`.

## Prerequisites

Call the ci-framework as usual but pass these overrides.
```
cifmw_devscripts_config_overrides:
  vm_extradisks: "true"
  vm_extradisks_list: "vdb vda"
  vm_extradisks_size: "10G"
```
On the the three CoreOS systems root will be mounted on `/dev/sda` but
`/dev/vda` and `/dev/vdb` will be available to back LVMS.
```
[zuul@controller-0 ~]$ ssh ocp-2 "lsblk"
Warning: Permanently added '192.168.111.22' (ED25519) to the list of known hosts.
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda      8:0    0  100G  0 disk
├─sda1   8:1    0    1M  0 part
├─sda2   8:2    0  127M  0 part
├─sda3   8:3    0  384M  0 part /boot
└─sda4   8:4    0 79.5G  0 part /var/lib/kubelet/pods/a0dc0880-bbdb-4ad3-ba48-07c48fa90a45/volume-subpaths/nginx-conf/monitoring-plugin/1
                                /var
                                /sysroot/ostree/deploy/rhcos/var
                                /usr
                                /etc
                                /
                                /sysroot
vda    252:0    0   10G  0 disk
vdb    252:16   0   10G  0 disk
[zuul@controller-0 ~]$
```

## Manual LVMS

We need to know what Ansible has to automate first.

### Deploy

1. Use [kustomization.yaml](kustomization.yaml) to deploy the
   LVMS operator.
```
[zuul@controller-0 lvms]$ oc kustomize .  | oc apply -f -
namespace/openshift-storage created
operatorgroup.operators.coreos.com/openshift-storage-operatorgroup created
catalogsource.operators.coreos.com/lvms-catalogsource created
subscription.operators.coreos.com/lvms-operator created
[zuul@controller-0 lvms]$
```
2. Use [lvms-namespace.yaml](lvms-namespace.yaml) to patch
   openshift-storage namespace to set annotations.
```
[zuul@controller-0 lvms]$ oc apply -f lvms-namespace.yaml
namespace/openshift-storage configured
[zuul@controller-0 lvms]$
```
3. Use [og.yaml](og.yaml) to create the openshift-storage-operatorgroup
```
[zuul@controller-0 lvms]$ oc create -f og.yaml
operatorgroup.operators.coreos.com/openshift-storage-operatorgroup created
[zuul@controller-0 lvms]$
```
4. Use [sub.yaml](sub.yaml) to create the lvms-operator subscription
```
oc create -f sub.yaml
```
5. Wait for the lvms-operator to reach state Succeeded
```
[zuul@controller-0 lvms]$ oc get csv -n openshift-storage -o custom-columns=Name:.metadata.name,Phase:.status.phase | grep lvms
lvms-operator.v4.14.4                   Succeeded
[zuul@controller-0 lvms]$
```
6. Use [lvms-cluster.yaml](lvms-cluster.yaml) to deploy the LVMS
   cluster.
```
[zuul@controller-0 lvms]$ oc create -f lvms-cluster.yaml
lvmcluster.lvm.topolvm.io/lvmcluster created
[zuul@controller-0 lvms]$
```
7. Look for topolvm and vg-manager pods.
```
[zuul@controller-0 lvms]$ oc project openshift-storage
[zuul@controller-0 lvms]$ oc get pods
NAME                                  READY   STATUS    RESTARTS   AGE
lvms-operator-df5c69cd6-rbffn         3/3     Running   0          2m22s
topolvm-controller-744976dfd4-cptv7   5/5     Running   0          60s
topolvm-node-7mfg9                    4/4     Running   0          60s
topolvm-node-p67mf                    4/4     Running   0          60s
topolvm-node-stfqk                    4/4     Running   0          60s
vg-manager-8lv96                      1/1     Running   0          60s
vg-manager-nb5wl                      1/1     Running   0          60s
vg-manager-xpzw2                      1/1     Running   0          60s
[zuul@controller-0 lvms]$
```
8. Get the status of the lvmclusters
```
[zuul@controller-0 lvms]$ oc get lvmclusters lvmcluster
NAME         STATUS
lvmcluster   Ready
[zuul@controller-0 lvms]$ oc get lvmclusters.lvm.topolvm.io -o jsonpath='{.items[*].status}' | jq .
{
  "deviceClassStatuses": [
    {
      "name": "vg1",
      "nodeStatus": [
        {
          "devices": [
            "/dev/vda",
            "/dev/vdb"
          ],
          "node": "master-0",
          "status": "Ready"
        },
        {
          "devices": [
            "/dev/vda",
            "/dev/vdb"
          ],
          "node": "master-2",
          "status": "Ready"
        },
        {
          "devices": [
            "/dev/vda",
            "/dev/vdb"
          ],
          "node": "master-1",
          "status": "Ready"
        }
      ]
    }
  ],
  "ready": true,
  "state": "Ready"
}
[zuul@controller-0 lvms]$
```
9. Use [test/test-pvc.yaml](test/test-pvc.yaml) and [test/test-pod.yaml](test/test-pod.yaml)
   to create a test PVC and pod to use it.
```
[zuul@controller-0 test]$ oc create -f test-pvc.yaml
persistentvolumeclaim/test-pvc created
[zuul@controller-0 test]$ oc create -f test-pod.yaml 
pod/my-pod created
[zuul@controller-0 test]$

```
10. Check if the PVC was able to be bound
```
[zuul@controller-0 test]$ oc get pvc
NAME       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
test-pvc   Bound    pvc-79eb0543-d203-4b36-9098-f33e5bf5e3fa   1Gi        RWO            lvms-vg1       107s
[zuul@controller-0 test]$
```
and used by the pod
```
[zuul@controller-0 lvms]$ oc get pod my-pod
NAME     READY   STATUS    RESTARTS   AGE
my-pod   1/1     Running   0          8m37s
[zuul@controller-0 lvms]$ oc get pod my-pod -o yaml | grep volumeMounts -A 2
    volumeMounts:
    - mountPath: /data
      name: my-volume
[zuul@controller-0 lvms]$

[zuul@controller-0 lvms]$ oc get pod my-pod -o yaml | grep volumes -A 3
  volumes:
  - name: my-volume
    persistentVolumeClaim:
      claimName: test-pvc
[zuul@controller-0 lvms]$
```

```
[zuul@controller-0 lvms]$ oc rsh my-pod
# mount | grep data
/dev/topolvm/423a6b61-cd7c-4ba7-b8bd-94b1b26fccc6 on /data type ext4 (rw,relatime,seclabel,stripe=32)
# ls /data
lost+found
#
```
