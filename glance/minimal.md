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

## Deploy Glance

At this point I switch to my local copy of the glance operator
and `make run-with-webhook`. No need to scale down as described
in [local copy](local.md).
