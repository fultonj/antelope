# LVMS

[PR739](https://github.com/openstack-k8s-operators/install_yamls/pull/739)
introduces [LVMS](https://github.com/openshift/lvm-operator/blob/main/README.md).

Instead of using `make crc_storage` use `make lvms` and `make
lvms_deploy`. Then replace `local-storage` with `lvms-vg1` in
CRs which request PVCs.

Be sure to run `make crc_attach_default_interface` before `make lvms`.
Otherwise, if LVMS is set up first, then attaching the extra network
interface will fail with a `No more available PCI slots` error.

I use it like this:
```
cd ~/install_yamls/devsetup
make crc_cleanup
rm -f ~/.crc/vdb
make CPUS=12 MEMORY=49152 DISK=100 crc
make crc_attach_default_interface
cd ..
make lvms
make lvms_deploy
```

## Details

[PR739](https://github.com/openstack-k8s-operators/install_yamls/pull/739)
uses `/dev/vdb` (backed by `~/.crc/vdb`) as it's available on `crc`
and defaults to `DISK_SIZE=100` to provide up to ten `10G` PVs.
```
$ make lvms
bash scripts/gen-lvms-kustomize.sh
~/install_yamls/out/openstack/lvms/cr ~/install_yamls
Creating Device vdb:100
Formatting '/home/fultonj/.crc/vdb', fmt=raw size=107374182400
Attaching disk vdb to crc
Disk attached successfully

Domain 'crc' destroyed

Domain 'crc' started

curl: (7) Failed to connect to 192.168.130.11 port 6443: No route to host
curl: (7) Failed to connect to 192.168.130.11 port 6443: Connection refused
The apiserver hasn't been fully initialized yet, please try again later.
Wait for the OCP API to be fully available
.......
namespace/openshift-storage created
operatorgroup.operators.coreos.com/openshift-storage-operatorgroup created
catalogsource.operators.coreos.com/lvms-catalogsource created
subscription.operators.coreos.com/lvms-operator created
Rolling out the lvms-operator
namespace/openshift-storage configured
................
clusterserviceversion.operators.coreos.com/lvms-operator.v0.0.1 patched
$ 
```
The above will pull images from https://quay.io/organization/lvms_dev
and `sudo virsh dumpxml crc | grep vdb -C 5` should show `crc` has
virtio device `/dev/vdb`.

Wait for the `lvms-catalogsource-*` and `lvms-operator-*` pods.
```
oc get pods -n openshift-storage -w
```
Watch for the `lastObservedState` of the `lvms-catalogsource` to be READY.
```
watch "oc -n openshift-storage get catalogsource -o yaml | tail"
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
## metrics-cert workaround

The `metrics-cert` volume mount won't be available if the
certificate has not yet been created. PR739 has a line to
patch the `lvms-operator` to remove this mount to speed up
deployment. Once the script sees the `lvms-operator.v0.0.1`
CSV:
```
[fultonj@hamfast install_yamls{lvms}]$ oc -n openshift-storage get csv lvms-operator.v0.0.1
NAME                   DISPLAY       VERSION   REPLACES   PHASE
lvms-operator.v0.0.1   LVM Storage   0.0.1                Succeeded
[fultonj@hamfast install_yamls{lvms}]$
```
it will patch the lvms-operator like this to remove the mount of the
`metrics-cert` volume.
```
oc patch csv -n openshift-storage lvms-operator.v0.0.1 --type=json \
-p="[{'op': 'remove', 'path': '/spec/install/spec/deployments/0/spec/template/spec/containers/0/volumeMounts/1'}]"
```
The `vg-manager` can have the same problem.
```
$ oc describe pod vg-manager-6dx5k
...
Events:
  Type     Reason       Age                From               Message
  ----     ------       ----               ----               -------
  Normal   Scheduled    99s                default-scheduler  Successfully assigned openshift-storage/vg-manager-6dx5k to crc-pjmnl-master-0
  Warning  FailedMount  35s (x8 over 99s)  kubelet            MountVolume.SetUp failed for volume "metrics-cert" : secret "vg-manager-metrics-cert" not found
```
I know of no simple command to patch the `vg-manager` to not use the
metrics cert but editing the CSV works.
```
oc -n openshift-storage edit csv
```
I then search for `metrics-cert`. I then remove these lines.
```
              - name: metrics-cert
                secret:
                  defaultMode: 420
                  secretName: lvms-operator-metrics-cert
```
