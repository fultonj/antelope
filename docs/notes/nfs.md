# NFS for EDPM Ansible

These are my notes from following
[Testing ansibleEE with NFS](https://openstack-k8s-operators.github.io/edpm-ansible/testing_with_ansibleee.html)

Install utils and open firewall on hamfast
```
sudo dnf install nfs-utils
sudo systemctl enable --now nfs-server
nft add rule inet firewalld filter_IN_libvirt_pre accept
```

Create export
```
sudo su -
cat <<EOF >/etc/exports
/home/fultonj/edpm-ansible 192.168.130.0/24(rw,sync,no_root_squash)
EOF
```
Export export
```
sudo su -
cat /var/lib/nfs/etab
exportfs -r 
cat /var/lib/nfs/etab
```

Test export
```
[root@hamfast ~]# mount -vv -t nfs 192.168.130.1:/home/fultonj/edpm-ansible /mnt/test
mount.nfs: timeout set for Mon Jul 31 17:53:12 2023
mount.nfs: trying text-based options 'vers=4.2,addr=192.168.130.1,clientaddr=192.168.130.1'
[root@hamfast ~]# ls /mnt/test/
bindep.txt  LICENSE   molecule-requirements.txt  plugins           scripts
contribute  Makefile  openstack_ansibleee        README.md         tests
docs        meta      OWNERS                     requirements.yml  zuul.d
galaxy.yml  molecule  OWNERS_ALIASES             roles
[root@hamfast ~]# umount /mnt/test
```
Create PV and PVC CR files
```
NFS_SHARE=/home/fultonj/edpm-ansible
NFS_SERVER=192.168.130.1
cat <<EOF >edpm-ansible-storage.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: edpm-ansible
spec:
  capacity:
    storage: 1Gi
  volumeMode: Filesystem
  accessModes:
    - ReadOnlyMany
  # IMPORTANT! The persistentVolumeReclaimPolicy must be "Retain" or else
  # your code will be deleted when the volume is reclaimed!
  persistentVolumeReclaimPolicy: Retain
  storageClassName: edpm-ansible
  mountOptions:
    - nfsvers=4.1
  nfs:
    path: ${NFS_SHARE}
    server: ${NFS_SERVER}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: edpm-ansible
spec:
  storageClassName: edpm-ansible
  accessModes:
    - ReadOnlyMany
  resources:
    requests:
      storage: 1Gi
EOF
```
Create PV and PVC
```
[fultonj@hamfast ~]$ oc apply -f edpm-ansible-storage.yaml
persistentvolume/edpm-ansible created
persistentvolumeclaim/edpm-ansible created
[fultonj@hamfast ~]$ 
```
Update a CR to use the extraVol

```diff
diff --git a/crs/data_plane/overlay/standard/deployment.yaml b/crs/data_plane/overlay/standard/deployment.yaml
index 037ba43..936000e 100644
--- a/crs/data_plane/overlay/standard/deployment.yaml
+++ b/crs/data_plane/overlay/standard/deployment.yaml
@@ -7,6 +7,16 @@ spec:
   roles:
     edpm-compute:
       nodeTemplate:
+        extraMounts:
+        - extraVolType: edpm-ansible
+          mounts:
+          - mountPath: /usr/share/ansible/collections/ansible_collections/osp/edpm
+            name: edpm-ansible
+          volumes:
+          - name: edpm-ansible
+            persistentVolumeClaim:
+              claimName: edpm-ansible
+              readOnly: true
         nova:
           customServiceConfig: |
             [libvirt]
```
