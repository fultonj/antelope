# Minimal Glance Deployment

These are my notes on deploying a minimal Glance environment for
development.

Unlike [standard](../docs/standard.md) it only runs the following
control plane services and does not use the openstack operator.

- galera
- rabbitmq
- memcached
- keystone

## Deploy Dependent Services

With a new hypervisor first run [init.sh](../scripts/init.sh).

Directly Deploy Dependent Services with `install_yamls`.
```
    pushd ~/install_yamls

    make mariadb
    make mariadb_deploy

    make rabbitmq
    make rabbitmq_deploy

    make infra

    make memcached_deploy

    make keystone
    make keystone_deploy
    
    popd
```
Or use [minimal.sh](minimal.sh).

When running this I like to watch from two terminals:

- term1: `oc get pods -w -n openstack-operators`
- term2: `oc get pods -w -n openstack`

## Run Local Glance Operator

```
cd ~/glance-operator
for c in $(ls config/crd/bases/); { oc create -f config/crd/bases/$c; }
make run-with-webhook
```
This is like running a [local copy](local.md) but there is nothing
to scale down first.

## Deploy Glance

```
cd ~/glance-operator/config/samples/layout/
kustomize build single | oc apply -f -
```
Use the following to remove the deployment.
```
kustomize build single | oc delete -f -
```
