# Topology Feature

Add ability to use
[TopologySpreadConstraints](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#pod-topology-spread-constraints)
and
[Affinity / Anti-Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity)
to schedule the Glance pods on specific nodes.

- [infra-operator](https://github.com/openstack-k8s-operators/infra-operator/pull/325)
- [lib-common](https://github.com/openstack-k8s-operators/lib-common/pull/582)
- [glance-operator](https://github.com/openstack-k8s-operators/glance-operator/pull/670)
- [opentsack-operator](https://github.com/fmount/openstack-operator/tree/topology-0)

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

### Confirm glance follows topology spread constraints (1 node)

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

## Three Node Testing

### Make Testing Environment

#### Deploy 3 nodes

Follow the ci-framework documentation as if you were going to
[deploy a VA](https://ci-framework.pages.redhat.com/docs/main/ci-framework/deploy_va.html)
but set `cifmw_deploy_architecture=false`.

There should be no `openstack` or `openstack-operators` namespaces
but you should now have a 3-node OCP deployment. The rest of these
should be run as zuul@controller-0.

#### Deploy OpenStack operator with custom image

fmount built an
[openstack-operator-index image](https://quay.io/repository/fpantano/openstack-operator-index?tab=tags&tag=v0.0.3)
based on
[opentsack-operator](https://github.com/fmount/openstack-operator/tree/topology-0).

Use install_yamls to install it.
```
cd ~/src/github.com/openstack-k8s-operators/install_yamls/
NETWORK_ISOLATION=false make openstack OPENSTACK_IMG=quay.io/fpantano/openstack-operator-index:v0.0.3
```
Watch the opentack operators start.
```
oc get pods -n openstack-operators -w
```

#### Deploy OpenStack control plane

These commands should be run in
`~/src/github.com/openstack-k8s-operators/install_yamls/`
unless otherwise indicated

Satisfy dependencies:
```
pushd devsetup
make download_tools
popd
make crc_storage
```

Deploy the control plane
```
NETWORK_ISOLATION=false make openstack_deploy
```

Patch the control plane to add a default topology:
```
oc patch openstackcontrolplane $(oc get oscp -o custom-columns=NAME:.metadata.name --no-headers) --type=merge -p='{"spec": {"topology": {"maxSkew": 1, "topologyKey": "topology.kubernetes.io/zone", "whenUnsatisfiable": "DoNotSchedule"}}}' -n openstack
```
View the topology
```
oc get topology
```

Use [storage-topology.yaml](storage-topology.yaml) to create a storage
topology.

```
oc create -f storage-topology.yaml
```

Patch glance to point to the new topology.

```
oc patch openstackcontrolplane $(oc get oscp -o custom-columns=NAME:.metadata.name --no-headers) --type=merge -p='{"spec": {"glance": {"template": {"glanceAPIs": {"default": {"topologyRef": {"name":"storage-topology", "namespace":"openstack"}}}}}}}' -n openstack
```

#### Observe Glance

```
$  oc get glanceapi  glance-default-external -o yaml | yq ".spec.topologyRef"
name: storage-topology
namespace: openstack
$
```

```
$ oc get sts glance-default-external-api -o yaml | yq ".spec.template.spec.topologySpreadConstraints"
- labelSelector:
    matchLabels:
      service: glance
  maxSkew: 3
  topologyKey: topology.kubernetes.io/zone
  whenUnsatisfiable: ScheduleAnyway
$
```

```
$ oc get sts glance-default-external-api -o yaml | yq ".spec.template.spec.affinity"
nodeAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    nodeSelectorTerms:
      - matchExpressions:
          - key: topology.kubernetes.io/zone
            operator: In
            values:
              - zoneA
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
    - podAffinityTerm:
        labelSelector:
          matchExpressions:
            - key: service
              operator: In
              values:
                - glance
        topologyKey: kubernetes.io/hostname
      weight: 80
$
```

### Create a topology for glance edge pods (3 node)

Put two OCP nodes in Zone A and one node in Zone B.
```
ZoneA: node1, node2
ZoneB: node3
```
Deploy one glance pod1 in Zone A and another glance pod2 in Zone B.

Confirm that:

- If node1 is not schedulable, glance pod1 is only scheduled on node2
- If node3 is not schedulable, glance pod2 remains `Pending`

Label the nodes as seen in the [Node labels example](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/#node-labels)

```
oc label nodes master-0 node=node1 zone=zoneA --overwrite
oc label nodes master-1 node=node2 zone=zoneA --overwrite
oc label nodes master-2 node=node3 zone=zoneB --overwrite
```

The steps in the previous section produce a glance pod which uses
this `topologyRef`:

```yaml
          topologyRef:
            name: storage-topology
```
Create two new topologies: [a-zone-topo.yaml](a-zone-topo.yaml) and
[b-zone-topo.yaml](b-zone-topo.yaml).

```yaml
$ oc create -f a-zone-topo.yaml
topology.topology.openstack.org/a-zone-topo created
$ oc create -f b-zone-topo.yaml
topology.topology.openstack.org/b-zone-topo created
$
```

Use `oc edit openstackcontrolplane` and search for `glance:`
Under `glanceAPIs` add two news entries under `default` to
run a glance pod called `azone` in zone A and glance pod called
`bzone` in zone B.

```yaml
      glanceAPIs:
        azone:
          topologyRef:
            name: a-zone-topo
          replicas: 1
          type: edge
        bzone:
          topologyRef:
            name: b-zone-topo
          replicas: 1
          type: edge
```
Observe the pods:
```
$ oc get pods | grep glance | grep zone
glance-azone-edge-api-0     3/3     Running     0          4m20s
glance-bzone-edge-api-0     3/3     Running     0          4m
$
```
Observe where the pods are running.
```
$ oc get pod glance-azone-edge-api-0 -o yaml | grep nodeName
  nodeName: master-2
$ oc get pod glance-bzone-edge-api-0 -o yaml | grep nodeName
  nodeName: master-0
$
```
I'd expect the opposite given the labeling.

#### Update Toplogies

The pods could be scheduled in the desired way after a lot of changes.

- The so-called "a-zone" pod has been scheduled to be in zone B.
- The so-called "b-zone" pod has been scheduled to be in zone A.

I should have updated this example to rename the pods since they've
been scheduled backwards. Regardless, I was able to see the scheduler
take action in the zones.

We see the "a-zone" pod is pending and other pods are running.
```shell
$ oc get pods | grep glance | grep zone
glance-azone-edge-api-0            0/3     Pending     0          46h
glance-bzone-edge-api-0            3/3     Running     0          46h
glance-default-external-api-0      3/3     Running     0          46h
glance-default-internal-api-0      3/3     Running     0          46h
$
```
The "b-zone" pod is running on a node in zone A.
```shell
$ oc get pod glance-bzone-edge-api-0 -o yaml | grep nodeName
  nodeName: master-0
$
```
The default pods are also running in zone A.
```shell
$ oc get pod glance-default-external-api-0 -o yaml | grep nodeName
  nodeName: master-1
$ oc get pod glance-default-internal-api-0 -o yaml | grep nodeName
  nodeName: master-0
$
```
The `oscp` CR glance section looks like this:
```yaml
        glanceAPIs:
          azone:
            replicas: 1
            topologyRef:
              name: b-zone-topo
            type: edge
          bzone:
            replicas: 1
            type: edge
          default:
            replicas: 1
            type: split
        secret: osp-secret
        serviceUser: glance
        storage:
          storageRequest: 10G
        topologyRef:
          name: storage-topology
      uniquePodNames: false
```
So all glance pods will inherit the `topologyRef` called
`storage-topology` except the "azone" pod which has an override so
that it uses the `topologyRef` called `b-zone-topo`.

This [storage-topology.yaml](storage-topology.yaml) version
results in glance pods being scheduled on nodes in zone A
and ensures that those pods are spread scheduled, i.e. the
second pod wont' be scheduled on the same node; this is desirable
since if that node becomes unavailable and the other node is still
running then the redundant pod can cover for the missing service.

The [b-zone-topo-update.yaml](b-zone-topo-update.yaml) represents the
current b-zone topology which differs like this from
[b-zone-topo.yaml](b-zone-topo.yaml).

```diff
diff --git a/glance/b-zone-topo.yaml b/glance/b-zone-topo.yaml
index e9c8f5d..46a6191 100644
--- a/glance/b-zone-topo.yaml
+++ b/glance/b-zone-topo.yaml
@@ -1,4 +1,3 @@
----
 apiVersion: topology.openstack.org/v1beta1
 kind: Topology
 metadata:
@@ -6,9 +5,9 @@ metadata:
   namespace: openstack
 spec:
   topologySpreadConstraint:
-  - maxSkew: 1
-    topologyKey: "zone"
-    whenUnsatisfiable: DoNotSchedule
-    labelSelector:
+  - labelSelector:
       matchLabels:
-        zone: zoneB
+        api-name: azone
+    maxSkew: 2
+    topologyKey: zoneB
+    whenUnsatisfiable: DoNotSchedule
```

The above `b-zone-topo` results in nodes being scheduled in zone B.
Because my environment only has one node in zone B the pod is not
scheduled. This is because the openstack-k8s-operators always inject
the following `podAntiAffinity`.
```yaml
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: service
              operator: In
              values:
              - glance
          topologyKey: kubernetes.io/hostname
        weight: 80
```
The above ensures that a node with a different hostname can host
additional pods, i.e. it implements something similar to the
topology spread in [b-zone-topo-update.yaml](b-zone-topo-update.yaml).

Because there is only one node in zone-b, the pod which should run
there (the unfortunately named glance-azone-edge-api-0), remains
in `pending`. I expect that if zone-b had an additional node that
it would be scheduled. I'll confirm this by redeploying my
environment with more OCP nodes.

## Multi Node Testing

### Make Testing Environment

Follow the ci-framework documentation as if you were going to
[deploy a VA](https://ci-framework.pages.redhat.com/docs/main/ci-framework/deploy_va.html)
but let `cifmw_deploy_architecture` default to false.

I use
[va-pidone](https://github.com/openstack-k8s-operators/ci-framework/blob/main/scenarios/reproducers/va-pidone.yml)
since it deploys seven OCP nodes. For example:
```
ansible-playbook \
     -i custom/inventory.yml \
     -e cifmw_target_host=hypervisor-1 \
     -e @scenarios/reproducers/networking-definition.yml \
     -e @scenarios/reproducers/va-pidone.yml \
     -e @custom/default-vars.yml \
     reproducer.yml
```
If you have both masters and workers then
[devscripts](https://ci-framework.readthedocs.io/en/latest/roles/devscripts.html)
makes the masters unschedulable by default. Make the masters schedulable:
```
oc patch scheduler cluster --type=merge -p '{"spec": {"mastersSchedulable": true}}'
```
If for some reason the nodes have `SchedulingDisabled` uncordon them:
```
oc adm uncordon master-0 master-1 master-2 worker-0 worker-1 worker-2 worker-3
```
There should be no `openstack` or `openstack-operators` namespaces
but you should now have a 7-node OCP deployment.
```
$ oc get nodes
NAME       STATUS   ROLES                         AGE    VERSION
master-0   Ready    control-plane,master,worker   142m   v1.29.5+29c95f3
master-1   Ready    control-plane,master,worker   140m   v1.29.5+29c95f3
master-2   Ready    control-plane,master,worker   141m   v1.29.5+29c95f3
worker-0   Ready    worker                        96m    v1.29.5+29c95f3
worker-1   Ready    worker                        96m    v1.29.5+29c95f3
worker-2   Ready    worker                        96m    v1.29.5+29c95f3
worker-3   Ready    worker                        96m    v1.29.5+29c95f3
```

We can now use `install_yamls` on controller-0 as the zuul user to
test the environment.

#### Storage Class

Do not run `make crc_storage`. Instead ensure the LVMS storage class
is available.
```
$ oc get sc
NAME                           PROVISIONER   RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
lvms-local-storage (default)   topolvm.io    Delete          WaitForFirstConsumer   true                   7d
$
```
The
[ci_lvms_storage](https://github.com/openstack-k8s-operators/ci-framework/tree/main/roles/ci_lvms_storage)
Ansible role can help with this.
```
pushd ~/src/github.com/openstack-k8s-operators/ci-framework/
URL=https://raw.githubusercontent.com/fultonj/antelope/refs/heads/main/lvms/ansible/lvms.yml
curl $URL -o lvms.yml
ansible-playbook lvms.yml
popd
```
The k8s manifests for LVMS should be in ~/ci-framework-data/artifacts/manifests/lvms

When deploying the control plane (in a future step) use the following:
```
STORAGE_CLASS=lvms-local-storage NETWORK_ISOLATION=false make openstack_deploy
```

#### Create Zones

I will create three zones (`A`, `B`, `C`) with my nodes:
```
A: cifmw-ocp-master-0
   cifmw-ocp-worker-0
   cifmw-ocp-worker-3

B: cifmw-ocp-master-1
   cifmw-ocp-worker-1

C: cifmw-ocp-master-2
   cifmw-ocp-worker-2
```

Label the nodes as seen in the [Node labels example](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/#node-labels)

```
oc label nodes master-0 node=node1 zone=zoneA --overwrite
oc label nodes worker-0 node=node2 zone=zoneA --overwrite
oc label nodes worker-3 node=node3 zone=zoneA --overwrite

oc label nodes master-1 node=node4 zone=zoneB --overwrite
oc label nodes worker-1 node=node5 zone=zoneB --overwrite

oc label nodes master-2 node=node6 zone=zoneC --overwrite
oc label nodes worker-2 node=node7 zone=zoneC --overwrite
```
Use `oc get nodes --show-labels` to confirm the lables were applied.

#### Deploy OpenStack operator with custom image

fmount built an
[openstack-operator-index image](https://quay.io/repository/fpantano/openstack-operator-index?tab=tags&tag=v0.0.3)
based on
[opentsack-operator](https://github.com/fmount/openstack-operator/tree/topology-0).

Use `install_yamls` to install it.
```
cd ~/src/github.com/openstack-k8s-operators/install_yamls/
STORAGE_CLASS=lvms-local-storage NETWORK_ISOLATION=false make openstack OPENSTACK_IMG=quay.io/fpantano/openstack-operator-index:v0.0.3
```
Watch the opentack operators start.
```
oc get pods -n openstack-operators -w
```

#### Deploy OpenStack control plane

These commands should be run in
`~/src/github.com/openstack-k8s-operators/install_yamls/`
unless otherwise indicated

Satisfy dependencies:
```
pushd devsetup
make download_tools
popd
```

Deploy the control plane
```
STORAGE_CLASS=lvms-local-storage NETWORK_ISOLATION=false make openstack_deploy
```
