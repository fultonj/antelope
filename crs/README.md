# CRs

A guide to my [CRs](../crs) directory.

The [openstack-k8s-operators](https://github.com/openstack-k8s-operators)
project provides
[operators](https://www.redhat.com/en/topics/containers/what-is-a-kubernetes-operator)
to deploy and manage OpenStack with
[CRs](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources).

You can generate CRs with 
[install_yamls](https://github.com/openstack-k8s-operators/install_yamls)
and then use [kustomize](https://kustomize.io) to modify them. This
directory holds kustomize files for my environment.

## control_plane

[control_plane](control_plane) assumes a file like `deployment.yaml`
has been created by install_yamls like this:
```
TARGET=$HOME/antelope/crs/control_plane/base/deployment.yaml
pushd ~/install_yamls
DBSERVICE=galera make openstack_deploy_prep
kustomize build out/openstack/openstack/cr > $TARGET
popd
```
The [ceph overlay](control_plane/overlay/ceph/) can be applied as below
to add generate a version of configured to work with Ceph.

```
cd ~/antelope/crs/
kustomize build control_plane/overlay/ceph
```

## data_plane

[data_plane](data_plane) assumes a file like `deployment.yaml` in in
the base directory and does similar substitutions with it like
control_plane.

## hello_world

See
[kustomize helloWorld](https://github.com/kubernetes-sigs/kustomize/tree/master/examples/helloWorld)
for a a kustomize example.
