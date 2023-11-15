# Minimal Glance Deployment

These are my notes on deploying a minimal Glance environment for
development.

Unlike [standard](../docs/standard.md) it only runs the following
control plane services but sets Glance to replica 3.

- galera
- keystone
- glance
- memcached
- openstackclient
- dnsmasq-dns
- ovn-controller

## Initial Set Up

Use [deploy.sh](../scripts/deploy.sh) sequentially with the following
tags set to `1`.

- `CRC`
- `ATTACH`
- `PVC`
- `DEPS`

## Deploy Operators

Use [deploy.sh](../scripts/deploy.sh) with `OPER` set to 1.

If desired replace the glance operator deployed by `OPER`
with your [own image](image.md) or a [local copy](local.md).

## Deploy Control Plane

Use [deploy.sh](../scripts/deploy.sh) with `CONTROL` set to `1`.

Use the
[control plane minimal overlay](../crs/control_plane/overlay/minimal)
to have kustomize modify the CR prepared by `install_yamls`.

```
pushd ~/antelope/crs/
kustomize build control_plane/overlay/minimal > control.yaml
oc apply -f control.yaml
popd
```

After Glance is deployed inspect the default configuration built by
its operator.

```
oc get secret glance-config-data -o json | jq -r '.data."00-config.conf"' | base64 -d
```

## Clean

```
pushd ~/install_yamls
make openstack_deploy_cleanup # rm control-plane
make openstack_cleanup        # rm operators
popd
```

After cleaning resume at "Deploy Operators" or "Deploy Control Plane".
