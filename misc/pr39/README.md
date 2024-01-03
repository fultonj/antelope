# Testing PR39 

These are my notes on testing architecture PR39.

The CRs from PR39 should produce a working deployment when compared to 
manually editing the CRs from the main branch. These notes describe
how to make manual edits on an environment deployed by ci-framework.

Use a fresh copy of this:

 https://github.com/openstack-k8s-operators/architecture/tree/main

## stage1

Follow https://github.com/openstack-k8s-operators/architecture/tree/main/va/hci/stage1

no changes

## stage2

Follow https://github.com/openstack-k8s-operators/architecture/tree/main/va/hci/stage2

no changes

## stage3

1. Create Storage
```
pushd ~/src/github.com/openstack-k8s-operators/install_yamls/
PV_NUM=64 make crc_storage
popd
```

2. change NICs
```
pushd /home/zuul/architecture/va/hci
grep -rl enp7s0 ./ | xargs sed -i 's/enp7s0/enp6s0/g'
popd
```

3. change node name
```
pushd /home/zuul/architecture/va/hci/stage3
grep -rl ostest ./ | xargs sed -i 's/ostest-master/master/g'
popd
```

4. change MTU
```
pushd /home/zuul/architecture/va/hci/
grep -rl 9000 ./ | xargs sed -i 's/9000/1500/g'
popd
```

Follow https://github.com/openstack-k8s-operators/architecture/tree/main/va/hci/stage3

## stage4

1. Set `storageClass` in `openstackcontrolplane.yaml` to `local-storage`

2. Update dns in `openstackcontrolplane.yaml` as below
```
  dns:
    template:
      options:
        - key: server
          values:
            - 192.168.122.1
        - key: server
          values:
            - 10.47.242.10
        - key: server
          values:
            - 10.38.5.26
```

Follow https://github.com/openstack-k8s-operators/architecture/tree/main/va/hci/stage4

### Note about DNS

Each key/value now needs to be separate as above. The following no
longer works:
```
  dns:
    template:
      options:
        - key: server
          values:
            - 192.168.122.1
            - 10.47.242.10
            - 10.38.5.26

```
As it will crash loop the pod:
```
[zuul@controller-0 stage4]$ oc get pods
NAME                           READY   STATUS                  RESTARTS      AGE
dnsmasq-dns-67848bbc44-gbd4n   0/1     Init:CrashLoopBackOff   2 (25s ago)   70s
dnsmasq-dns-6b7b984f54-hznsc   0/1     Init:CrashLoopBackOff   2 (19s ago)   70s
```
```
$ oc logs dnsmasq-dns-65cf7db67d-kqd92 -c init
dnsmasq: bad address at line 1 of /etc/dnsmasq.d/config.cfg
```
```
[zuul@osp-storage-01 ~]$ oc get cm dns -o yaml
apiVersion: v1
data:
  dns: |
    server=192.168.122.1,10.47.242.10,10.38.5.26
kind: ConfigMap
```
When it's configured correctly it should look like this:
```
[zuul@controller-0 misc]$ oc get cm dns -o yaml | head -7
apiVersion: v1
data:
  dns: |
    server=192.168.122.1
    server=10.47.242.10
    server=10.38.5.26
kind: ConfigMap
[zuul@controller-0 misc]$ 
```

## stage5

Use the ci-framework documentation.

## stage6

Use the ci-framework documentation.
