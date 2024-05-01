# Removing the LVMS deployment Manually by applying CRs

1. Delete Test Pod and PVC
```
oc delete -f test/test-p
oc delete -f test/test-pvc.yaml 
```

2. Delete lvmcluster
```
oc delete -f lvms-cluster.yaml
```

3. Delete subscription
```
oc delete -f sub.yaml
```

4. Delete openshift-storage-operatorgroup
```
oc delete -f og.yaml
```

5. Delete LVMS namespace
```
oc delete -f lvms-namespace.yaml
```

6. Confirm there are no LVM PVs on the OCP nodes
```
[zuul@controller-0 cr]$ ssh ocp-0 "sudo pvdisplay" 
Warning: Permanently added '192.168.111.20' (ED25519) to the list of known hosts.
[zuul@controller-0 cr]$ 
```
