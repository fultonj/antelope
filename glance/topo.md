# Topology Feature

Add ability to use
[TopologySpreadConstraints](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#pod-topology-spread-constraints)
and
[Affinity / Anti-Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity)
to schedule the Glance pods on specific nodes.

-  [infra-operator](https://github.com/openstack-k8s-operators/infra-operator/pull/325)
-  [lib-common](https://github.com/openstack-k8s-operators/lib-common/pull/582)
-  [glance-operator](https://github.com/fmount/glance-operator/tree/topology-1)

## Get it running

These steps assume you have already followed [minimal.md](minimal.md).

### infra

```
git clone https://github.com/fmount/infra-operator.git -b topology-1
cd infra-operator/
make
oc create -f config/crd/bases/topology.openstack.org_topologies.yaml
```
It's not necessary to run a local copy of this operator. You only need
to create the new CRD. Test it with [topo.yaml](topo.yaml).

```
oc create -f topo.yaml
oc get Topology
oc get Topology/default-sample -o yaml
```

#### lib-common

```
git clone https://github.com/fmount/lib-common.git -b affinity-1
```

### glance

```
git clone https://github.com/fmount/glance-operator.git -b topology-1
cd glance-operator
make
```
The above will create a `go.work` file but fail to build until the
the following is added to the last line of `go.work`

```
replace github.com/openstack-k8s-operators/lib-common/modules/common => ../lib-common/modules/common
```
