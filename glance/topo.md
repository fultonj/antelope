# Topology Feature

Add ability to use
[TopologySpreadConstraints](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#pod-topology-spread-constraints)
and
[Affinity / Anti-Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity)
to schedule the Glance pods on specific nodes.

-  [infra-operator](https://github.com/openstack-k8s-operators/infra-operator/pull/325)
-  [lib-common](https://github.com/openstack-k8s-operators/lib-common/pull/582)
-  [glance-operator](https://github.com/fmount/glance-operator/tree/topology-1)

## Single Node Testing

### Make Testing Environment

These steps assume you have already followed [minimal.md](minimal.md).

#### infra

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

#### glance

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

### Confirm Glance Follows Topology Spread Constraints

Update the `topologyRef` in the `glanceAPI` to use the default-sample
from [topo.yaml](topo.yaml).

```
oc edit glance/glance
```
For example:
```yaml
  glanceAPIs:
    default:
      topologyRef:
        name: default-sample
```
The glance pod should then switch from a state of `Running` to `Pending`
```
$ oc get pods -w | grep -v Completed
NAME                               READY   STATUS      RESTARTS   AGE
glance-default-single-0    3/3     Running     0          5h35m
keystone-59b5f6b958-wpfjr  1/1     Running     0          3m30s
memcached-0                1/1     Running     0          3d
openstack-galera-0         1/1     Running     0          3d
openstack-galera-1         1/1     Running     0          3d
openstack-galera-2         1/1     Running     0          3d
rabbitmq-server-0          1/1     Running     0          3d
<...>
glance-default-single-0    3/3     Terminating   0          5h35m
glance-default-single-0    0/3     Terminating   0          5h35m
glance-default-single-0    0/3     Pending       0          0s
glance-default-single-0    0/3     Pending       0          0s
$
```
The `glance-default-single-0` is in a state of `Pending` because
[topo.yaml](topo.yaml) has the following:
```
    topologyKey: "topology.kubernetes.io/zone" # Spread evenly across zones
    whenUnsatisfiable: DoNotSchedule
```
The
[Node labels](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/#node-labels)
example shows a k8s cluster with nodes labeled into zones.
Because my crc deployment does not have zones, the `topologyKey`
is unable to be satisfied. Because the `whenUnsatisfiable` field is
set to `DoNotSchedule`, the pod still stay in `Pending`.

If we change to `whenUnsatisfiable: ScheduleAnyway` as described in
[whenUnsatisfiable](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/#spread-constraint-definition),
```
$ oc edit Topology
topology.topology.openstack.org/default-sample edited
$
```
then the glance pod should change to state `Running`.
```
glance-default-single-0      0/3     Pending             0          0s
glance-default-single-0      0/3     ContainerCreating   0          1s
glance-default-single-0      0/3     Running             0          2s
```
This shows that the Glance pod is obeying the
[Topology Spread Constraints](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints)
defined in [topo.yaml](topo.yaml).

## Proposed Three Node Testing

Put two OCP nodes in Zone A and one node in Zone B.
```
ZoneA: node1, node2
ZoneB: node3
```
Deploy one glance pod1 in Zone A and another glance pod2 in Zone B.

Confirm that:

- If node1 is not schedulable, glance pod1 is only scheduled on node2
- If node3 is not schedulable, glance pod2 remains `Pending`

### Make Testing Environment

[Deploy a VA](https://ci-framework.pages.redhat.com/docs/main/ci-framework/deploy_va.html)
using ci-framework. Label the nodes as seen in the [Node labels example](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/#node-labels)

```
oc label nodes master-0 node=node1 zone=zoneA --overwrite
oc label nodes master-1 node=node2 zone=zoneA --overwrite
oc label nodes master-2 node=node3 zone=zoneB --overwrite
```

Create `config/crd/bases/topology.openstack.org_topologies.yaml`
as described under `infra` in the previous section.

Create a custom image from the checkout of glance-operator and
push it to quay as described in [image](image.md). I updated my
`go.work` with the following:
```
replace github.com/openstack-k8s-operators/lib-common/modules/common => github.com/fmount/lib-common/modules/common v0.0.0-20241203102750-0b9fe14de0b0
```
and confirmed I could get the image via `podman pull
quay.io/fultonj/glance-operator:topo`.

Use
[operator-image.sh](operator-image.sh) to deploy the custom
glance-operator image with `topologyKey` support.
