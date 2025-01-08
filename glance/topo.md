# Topology Feature

Add ability to use
[TopologySpreadConstraints](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#pod-topology-spread-constraints)
and
[Affinity / Anti-Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity)
to schedule the Glance pods on specific nodes.

- [infra-operator](https://github.com/openstack-k8s-operators/infra-operator/pull/325)
- [lib-common](https://github.com/openstack-k8s-operators/lib-common/pull/587)
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

### Configure Topologies

As described in the
[glance-operator design decisions document](https://github.com/openstack-k8s-operators/glance-operator/blob/main/docs/design-decisions.md)
there are both `split` and `edge` glance pods.

We will use `nodeAffinity` to schedule `edge` pods
and `TopologySpreadConstraints` to schedule `split` pods
as desired when the k8s cluster is split into three zones.

#### Affinity for Glance Edge Pods

Create a `Topology` for each zone baed on affinity.

- [glance-azone-node-affinity.yaml](glance-azone-node-affinity.yaml)
- [glance-bzone-node-affinity.yaml](glance-bzone-node-affinity.yaml)
- [glance-czone-node-affinity.yaml](glance-czone-node-affinity.yaml)

```
for F in $(echo glance-{a,b,c}zone-node-affinity.yaml); do oc apply -f $F; done
```

Use `oc edit oscp` and search for `glance:`.
Under `glanceAPIs` add new entries under `default` to:

- run glance pods with the name `azone` in zone A
- run glance pods with the name `bzone` in zone B
- run glance pods with the name `czone` in zone C

```yaml
      glanceAPIs:
        azone:
          topologyRef:
            name: glance-azone-node-affinity
          replicas: 3
          type: edge
        bzone:
          topologyRef:
            name: glance-bzone-node-affinity
          replicas: 3
          type: edge
        czone:
          topologyRef:
            name: glance-czone-node-affinity
          replicas: 3
          type: edge
```

Observe which pods end up on which nodes and confirm they match their zones.

```
$ oc get pods -l service=glance -o wide
NAME                            READY   STATUS    RESTARTS   AGE     IP               NODE       NOMINATED NODE   READINESS GATES
glance-azone-edge-api-0         3/3     Running   0          2m13s   192.168.34.111   master-0   <none>           <none>
glance-azone-edge-api-1         3/3     Running   0          35s     192.168.52.40    worker-0   <none>           <none>
glance-azone-edge-api-2         3/3     Running   0          35s     192.168.34.112   master-0   <none>           <none>
glance-bzone-edge-api-0         3/3     Running   0          114s    192.168.36.153   master-1   <none>           <none>
glance-bzone-edge-api-1         3/3     Running   0          35s     192.168.36.154   master-1   <none>           <none>
glance-bzone-edge-api-2         3/3     Running   0          35s     192.168.44.51    worker-1   <none>           <none>
glance-czone-edge-api-0         3/3     Running   0          2m10s   192.168.40.209   master-2   <none>           <none>
glance-czone-edge-api-1         0/3     Running   0          35s     192.168.56.31    worker-2   <none>           <none>
glance-czone-edge-api-2         3/3     Running   0          35s     192.168.40.210   master-2   <none>           <none>
glance-default-external-api-0   3/3     Running   0          16m     192.168.52.39    worker-0   <none>           <none>
glance-default-internal-api-0   3/3     Running   0          16m     192.168.44.49    worker-1   <none>           <none>
```

- A zone pods are on master-0 or worker-0 which are in zone A
- B zone pods are on master-1 or worker-1 which are in zone B
- C zone pods are on master-2 or worker-2 which are in zone C

#### topologySpreadConstraints for Glance Split Pods

Use `oc edit oscp` to scale the default split pods from 1 to 3
replicas.

```yaml
      glanceAPIs:
        azone:
          <...>
        bzone:
          <...>
        czone:
          <...>
        default:
          <...>
          replicas: 3
```
Observe their distribution is mostly in zone A with the exeption of
`glance-default-internal-api-0` which is running in zone B on
`worker-1`. The scheduler is not aware of these zones when scheduling
these pods.

```
$ oc get pods -l service=glance -o wide | grep default
glance-default-external-api-0   3/3     Running   0          40m     192.168.52.39    worker-0   <none>           <none>
glance-default-external-api-1   3/3     Running   0          2m40s   192.168.56.32    worker-2   <none>           <none>
glance-default-external-api-2   3/3     Running   0          2m40s   192.168.48.41    worker-3   <none>           <none>
glance-default-internal-api-0   3/3     Running   0          40m     192.168.44.49    worker-1   <none>           <none>
glance-default-internal-api-1   3/3     Running   0          2m40s   192.168.48.42    worker-3   <none>           <none>
glance-default-internal-api-2   3/3     Running   0          2m40s   192.168.52.41    worker-0   <none>           <none>
```

There is a built in `podAntiAffinity` in the OpenStack operator
which pre-dates the pathces to add `topologyRef`. It distributes
pods so that they land on a node with a different hostname. This
makes sense as a general rule so that OpenStack pods are distributed
to different nodes within the k8s cluster. The following `affinity` is
added automatically to pods by default.

```yaml
$ oc get pod glance-default-internal-api-0 -o yaml | grep affinity -A 11
  affinity:
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
        weight: 100
```

However, because the scheduling for the default split glance pod is
not aware of the A,B,C zones we will give it a `topologyRef` to a
new [glance-default-spread-pods.yaml](glance-default-spread-pods.yaml)
`Topology` which spreads the pods across the zones.
```
oc create -f glance-default-spread-pods.yaml
```
Use `oc edit oscp` to add the `topologyRef`.
```yaml
      glanceAPIs:
        azone:
          <...>
        bzone:
          <...>
        czone:
          <...>
        default:
          <...>
          replicas: 3
          topologyRef:
            name: glance-default-spread-pods
```
Observe the result:
```
$ oc get pods -l service=glance -o wide | grep default
glance-default-external-api-0   3/3     Running   0          66m     192.168.52.39    worker-0   <none>           <none>
glance-default-external-api-1   3/3     Running   0          28m     192.168.56.32    worker-2   <none>           <none>
glance-default-external-api-2   0/3     Pending   0          2m33s   <none>           <none>     <none>           <none>
glance-default-internal-api-0   3/3     Running   0          66m     192.168.44.49    worker-1   <none>           <none>
glance-default-internal-api-1   0/3     Pending   0          2m20s   <none>           <none>     <none>           <none>
glance-default-internal-api-2   3/3     Running   0          2m33s   192.168.52.43    worker-0   <none>           <none>
$
```
- Pod `external-api-2` was moved from `worker-3` in zone A to Pending
- Pod `internal-api-1` was moved from `worker-3` in zone A to Pending

Both `internal-api-1` and `external-api-2` had the following so I'll
just show one.

```yaml
$ oc get pod glance-default-external-api-2 -o yaml
<...>
spec:
  affinity:
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
        weight: 100
  <...>
  topologySpreadConstraints:
  - labelSelector:
      matchLabels:
        service: glance
    maxSkew: 1
    topologyKey: zone
    whenUnsatisfiable: DoNotSchedule
<...>
status:
  conditions:
  - lastProbeTime: null
    lastTransitionTime: "2025-01-08T16:52:54Z"
    message: '0/7 nodes are available: 1 node(s) didn''t match pod topology spread
      constraints (missing required label), 6 node(s) had volume node affinity conflict.
      preemption: 0/7 nodes are available: 7 Preemption is not helpful for scheduling.'
    reason: Unschedulable
    status: "False"
    type: PodScheduled
  phase: Pending
  qosClass: BestEffort
```

The `6 node(s) had volume node affinity conflict` is because
both `internal-api-1` and `external-api-2` were on `worker-3`
and had a PV:
```
$ oc get pv | grep internal-api-1 | awk {'print $1'}
pvc-e49079ee-4871-4b27-a207-10fb972e52c6
$ oc get pv | grep external-api-2 | awk {'print $1'}
pvc-7da33e01-8866-4e40-b95a-eef99a5b0ebd
$
```
which is also on the same worker:
```
$ oc get pv pvc-e49079ee-4871-4b27-a207-10fb972e52c6 -o yaml | grep worker
          - worker-3
$ oc get pv pvc-7da33e01-8866-4e40-b95a-eef99a5b0ebd -o yaml | grep worker
          - worker-3
$
```
and that PV is implemented with LVMS so it cannot be migrated. Because
we are applying this as a new scheduling constraint to an existing pod
we are effectivley requesting to migrate the PV. We can avoid this by
having this scheduling constraint in place before the pod is created
the first time.

As per the
[glance-operator FAQ](https://github.com/openstack-k8s-operators/glance-operator/blob/main/docs/faq.md)
the PV is used as a staging area and we can remove the additional
constraint it has by setting `storage/external: true` and then the
desired scheduling will not be blocked.

Use `oc edit oscp` accordingly.
```yaml
      glanceAPIs:
        azone:
          <...>
        bzone:
          <...>
        czone:
          <...>
        default:
          <...>
          replicas: 3
          topologyRef:
            name: glance-default-spread-pods
          storage:
            external: true
```
For demo puposes external share will not be configured.

Now all of the default glance pods are running with the desired zone
distribution.
```
$ oc get pods -l service=glance -o wide | grep default
glance-default-external-api-0   0/3     Running   0          7s     192.168.44.53    worker-1   <none>           <none>
glance-default-external-api-1   0/3     Running   0          7s     192.168.56.34    worker-2   <none>           <none>
glance-default-external-api-2   0/3     Running   0          7s     192.168.52.44    worker-0   <none>           <none>
glance-default-internal-api-0   0/3     Running   0          6s     192.168.52.45    worker-0   <none>           <none>
glance-default-internal-api-1   0/3     Running   0          6s     192.168.40.239   master-2   <none>           <none>
glance-default-internal-api-2   0/3     Running   0          6s     192.168.44.54    worker-1   <none>           <none>
$
```
- Zone A: external-api-2, internal-api-0
- Zone B: external-api-0, internal-api-2
- Zone C: external-api-1, internal-api-1
