# LVMS

[PR739](https://github.com/openstack-k8s-operators/install_yamls/pull/739)
introduces [LVMS](https://github.com/openshift/lvm-operator/blob/main/README.md).

Instead of using `make crc_storage` use `make lvms` and `make
lvms_deploy`. Then replace `local-storage` with `lvms-vg1` in
CRs which request PVCs.

Be sure to run `make crc_attach_default_interface` before `make lvms`.
Otherwise, if LVMS is set up first, then attaching the extra network
interface will fail with a `No more available PCI slots` error.

## Details

[PR739](https://github.com/openstack-k8s-operators/install_yamls/pull/739)
is opinionated and uses `/dev/vdb` as it's available on `crc`.
Use `DISK_SIZE=100` to provide up to ten `10G` PVs.
```
$ DISK_SIZE=100 make lvms
bash scripts/gen-lvms-kustomize.sh
~/install_yamls/out/openstack/lvms/cr ~/install_yamls
Attaching disk vdb to crc
Disk attached successfully

Domain 'crc' destroyed

Domain 'crc' started

curl: (7) Failed to connect to 192.168.130.11 port 6443: No route to host
curl: (7) Failed to connect to 192.168.130.11 port 6443: Connection refused
The apiserver hasn't been fully initialized yet, please try again later.
Wait for the OCP API to be fully available
.......................
namespace/openshift-storage created
operatorgroup.operators.coreos.com/openshift-storage-operatorgroup created
catalogsource.operators.coreos.com/lvms-catalogsource created
subscription.operators.coreos.com/lvms-operator created
$ 
```
The above will pull images from https://quay.io/organization/lvms_dev
and `sudo virsh dumpxml crc | grep vdb -C 5` should show `crc` has
virtio device `/dev/vdb`.

Wait for the `lvms-catalogsource-*` and `lvms-operator-*` pods.
```
oc get pods -n openshift-storage -w
```
Once the `lvms-operator` is running, try `make lvms_deploy`
```
$ make lvms_deploy
bash scripts/gen-lvms-kustomize.sh
~/install_yamls/out/openstack/lvms/cr ~/install_yamls
lvmcluster.lvm.topolvm.io/lvmcluster created
$
```
You should then see the `vg-manager`.
```
$ oc get pods -n openshift-storage
NAME                                                              READY   STATUS      RESTARTS     AGE
fdc083e1fa5c9aafe131a5eeeb19c49d045d1f746562a90dc0fce6a98c6xpwb   0/1     Completed   0            8h
lvms-catalogsource-r92c2                                          1/1     Running     0            8h
lvms-operator-69ff9d64f9-9tkzp                                    1/1     Running     0            8h
vg-manager-hrw8z                                                  1/1     Running     1 (8h ago)   8h
$ 
```
If not, try running `make lvms_deploy` again.

The following should indicate that the `lvmcluster` is ready. 
```
$ oc get lvmclusters lvmcluster
NAME         STATUS
lvmcluster   Ready
$ 
```
`oc get storageclass` should show the storage class.
```
$ oc get sc
NAME                                     PROVISIONER                        RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
crc-csi-hostpath-provisioner (default)   kubevirt.io.hostpath-provisioner   Delete          WaitForFirstConsumer   false                  89d
lvms-vg1                                 topolvm.io                         Delete          WaitForFirstConsumer   true                   26s
$
```
