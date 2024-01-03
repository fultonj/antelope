# Testing PR39

These are my notes on testing architecture PR39.

It seems, even without PR39, my dnsmasq pod gets into a crashloop.
Here are steps to reproduce.

Use a fresh copy of this:

 https://github.com/fultonj/architecture/tree/main

## stage1

Follow https://github.com/fultonj/architecture/tree/main/va/hci/stage1

no changes

## stage2

Follow https://github.com/fultonj/architecture/tree/main/va/hci/stage2

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

4. change mtu
```
pushd /home/zuul/architecture/va/hci/
grep -rl 9000 ./ | xargs sed -i 's/9000/1500/g'
popd
```

Follow https://github.com/fultonj/architecture/tree/main/va/hci/stage3

## stage4

1. Set `storageClass` in `openstackcontrolplane.yaml` to `local-storage`

2. Update dns in `openstackcontrolplane.yaml` as below
```
  dns:
    template:
      options:
        - key: server
          values:
            - 192.168.122.1 # CHANGEME
            - 10.47.242.10
            - 10.38.5.26
```

Follow https://github.com/fultonj/architecture/tree/main/va/hci/stage4

Why do I get this?

```
[zuul@controller-0 stage4]$ oc get pods
NAME                           READY   STATUS                  RESTARTS      AGE
dnsmasq-dns-67848bbc44-gbd4n   0/1     Init:CrashLoopBackOff   2 (25s ago)   70s
dnsmasq-dns-6b7b984f54-hznsc   0/1     Init:CrashLoopBackOff   2 (19s ago)   70s
memcached-0                    1/1     Running                 0             70s
openstack-cell1-galera-0       0/1     Running                 0             70s
openstack-cell1-galera-1       0/1     Running                 0             70s
openstack-cell1-galera-2       1/1     Running                 0             70s
openstack-galera-0             0/1     Running                 0             70s
openstack-galera-1             0/1     Running                 0             70s
openstack-galera-2             1/1     Running                 0             70s
ovn-controller-ccbch           3/3     Running                 0             70s
ovn-controller-pq2sz           3/3     Running                 0             70s
ovn-controller-tf5q7           3/3     Running                 0             70s
ovn-northd-59dc9bf674-kz7q9    1/1     Running                 0             27s
ovsdbserver-nb-0               1/1     Running                 0             70s
ovsdbserver-sb-0               1/1     Running                 0             70s
rabbitmq-cell1-server-0        0/1     Running                 0             70s
rabbitmq-cell1-server-1        0/1     Running                 0             70s
rabbitmq-cell1-server-2        0/1     PodInitializing         0             70s
rabbitmq-server-0              0/1     Running                 0             70s
rabbitmq-server-1              0/1     Running                 0             70s
rabbitmq-server-2              0/1     PodInitializing         0             70s
[zuul@controller-0 stage4]$ 
```

## stage5
todo
## stage6
todo
