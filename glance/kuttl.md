# Running Glance kuttl tests

## Prerequisites

The prerequisites to run kuttl are described in the comments of
[kuttl-test.yaml](https://github.com/openstack-k8s-operators/glance-operator/blob/main/kuttl-test.yaml).
I have my own variation of this procedure.

Ensure you have the kuttl CLI command installed and set up a fresh
hypervisor using [deploy.sh](../scripts/deploy.sh) with the following
tags.

- CRC
- ATTACH
- PVC
- DEPS
- OPER

Before running kuttl ensure your image and repository are aligned as
described in the next section.

### Why a fresh crc?

I did a [scale-down.sh](scale-down.sh) of the glance deployed by
OLM so I could run my own copy and then did a restore. Even though
I could see the `webhookdefinitions` in my CSV backup
`glance_operator_csv.json` I saw the following when
`make glance_kuttl` was running. So I assume I didn't correctly
restore my webhooks. Using a fresh environment is one way to avoid
this.
```
logger.go:42: 17:36:05 | glance_scale/1-deploy_glance |
Error from server (InternalError): error when creating "STDIN":
Internal error occurred: failed calling webhook "mglance.kb.io":
failed to call webhook: Post
"https://192.168.130.1:9443/mutate-glance-openstack-org-v1beta1-glance?timeout=10s":
dial tcp 192.168.130.1:9443: connect: connection refused
```

## Align image and repository

Determine which glance-operator image is running with [which_image.sh](which_image.sh).

Use the list of built images to determine when that image was built:

  https://quay.io/repository/openstack-k8s-operators/glance-operator?tab=tags

Look for which version of the glance repository is compatible with that
image (e.g. on the same date):

  https://github.com/openstack-k8s-operators/glance-operator/commits/main

It's possible that the kuttl tests defined in the repository
were only tested with an image from the same point in time and won't
work with another image.

  https://github.com/openstack-k8s-operators/glance-operator/tree/main/test/kuttl/tests/glance_scale

Use [this process](image.md) to build an image with the branch to be
teted and update the CSV to run that image.

Alternatively, you should be able to run a [local copy](local.md)
of the operator and run kuttl the same way.

## Running kuttl

As per
[kuttl-test.yaml](https://github.com/openstack-k8s-operators/glance-operator/blob/main/kuttl-test.yaml):

```
pushd ~/install_yamls/
GLANCE_KUTTL_NAMESPACE=glance-kuttl-tests GLANCE_KUTTL_DIR=~/glance-operator/ make glance_kuttl
```
`GLANCE_KUTTL_DIR` is set to prevent it from downloading a new copy
from the main repo. I'm assuming you want to test your own patch to
both the operator code and kuttl test definition which is in
`~/glance-operator/`.

`GLANCE_KUTTL_NAMESPACE` is set to its default (`glance-kuttl-tests`) 
in my example to make it easy to copy/paste the above and switch the
namespace if you want to run a new test in a clean environment in a
new namespace.

If you want to run the kuttl tests directly in an environment where
you have already deployed keystone, memcached and galera then you can
use this.
```
kubectl-kuttl test --config ~/glance-operator/kuttl-test.yaml ~/glance-operator/test/kuttl/tests --namespace openstack | tee -a $HOME/kuttl.log
```

## Example of Good Results

After running the `make glance_kuttl` variation above you should be
able to scroll up and see the following indicating that the kuttl
tests passed.

```
--- PASS: kuttl (10.97s)
    --- PASS: kuttl/harness (0.00s)
        --- PASS: kuttl/harness/.git (0.00s)
        --- PASS: kuttl/harness/pkg (0.00s)
        --- PASS: kuttl/harness/test (0.00s)
        --- PASS: kuttl/harness/templates (0.00s)
        --- PASS: kuttl/harness/config (0.00s)
        --- PASS: kuttl/harness/hack (0.00s)
        --- PASS: kuttl/harness/docs (0.00s)
        --- PASS: kuttl/harness/controllers (0.00s)
        --- PASS: kuttl/harness/api (0.00s)
        --- PASS: kuttl/harness/bin (0.00s)
        --- PASS: kuttl/harness/.github (0.00s)
```

A command like `oc -n glance-kuttl-tests2 get pods` will return
nothing because by default the environment to run the test is claned
up.

On [my machine](https://pcpartpicker.com/user/fultonj/saved/v9KLD3)
the `make glance_kuttl` variation took about 10 minutes.


## Example of Bad Results

After 5 minutes in the fresh env I see the following:
```
[fultonj@hamfast scripts{main}]$ oc -n glance-kuttl-tests get pods
NAME                                   READY   STATUS      RESTARTS   AGE
glance-db-create-qphnd                 0/1     Completed   0          2m59s
glance-db-sync-2989n                   0/1     Completed   0          2m39s
glance-external-api-7dbc6f9b6d-g85b9   3/3     Running     0          78s
glance-internal-api-564c9c695c-f67gr   3/3     Running     0          78s
keystone-6df49586-lc9j8                1/1     Running     0          70s
keystone-bootstrap-22cxq               0/1     Completed   0          83s
keystone-db-create-2bsp5               0/1     Completed   0          2m45s
keystone-db-sync-hdprk                 0/1     Completed   0          2m35s
memcached-0                            1/1     Running     0          3m30s
openstack-galera-0                     1/1     Running     0          3m33s
openstack-galera-1                     1/1     Running     0          3m33s
openstack-galera-2                     1/1     Running     0          3m33s
rabbitmq-server-0                      1/1     Running     0          3m26s
[fultonj@hamfast scripts{main}]$
```

I then fail on the scale test like this:

```
    logger.go:42: 11:44:31 | glance_scale/1-deploy_glance | test step failed 1-deploy_glance
    case.go:364: failed in step 1-deploy_glance
    case.go:366: statefulsets.apps "glance-external-api" not found
    case.go:366: statefulsets.apps "glance-internal-api" not found
    logger.go:42: 11:44:31 | glance_scale | skipping kubernetes event logging
=== CONT  kuttl
    harness.go:405: run tests finished
    harness.go:513: cleaning up
    harness.go:570: removing temp folder: ""
--- FAIL: kuttl (195.12s)
    --- FAIL: kuttl/harness (0.00s)
        --- FAIL: kuttl/harness/glance_scale (184.15s)
FAIL
make[1]: *** [Makefile:1606: glance_kuttl_run] Error 1
make[1]: Leaving directory '/home/fultonj/install_yamls'
make: *** [Makefile:1614: glance_kuttl] Error 2
[fultonj@hamfast install_yamls{main}]$
```
I know the
[kuttl tests were adjusted to match StatefulSet](https://github.com/openstack-k8s-operators/glance-operator/pull/352/commits/a5152b2205204a3d17dc48a69147741510970651)
and the
[build-log](https://gcsweb-ci.apps.ci.l2s4.p1.openshiftapps.com/gcs/origin-ci-test/pr-logs/pull/openstack-k8s-operators_glance-operator/352/pull-ci-openstack-k8s-operators-glance-operator-main-glance-operator-build-deploy-kuttl/1720072280718970880/artifacts/glance-operator-build-deploy-kuttl/openstack-k8s-operators-kuttl/build-log.txt)
from CI showed that it passed the same test and others.
```
logger.go:42: 14:10:53 | glance_scale/1-deploy_glance | test step completed 1-deploy_glance
```
If I comment out
[these lines](https://github.com/openstack-k8s-operators/glance-operator/blob/main/test/kuttl/tests/glance_scale/01-assert.yaml#L67-L144)
and run
```
kubectl-kuttl assert --namespace glance-kuttl-tests ~/glance-operator/test/kuttl/tests/glance_scale/01-assert.yaml --timeout 10
```
as described in the [docs](https://github.com/openstack-k8s-operators/docs/blob/main/kuttl_tests.md),
then it fails instead with the following since "the assert command
does not support having TestAssert blocks in the assert files".
```
//api.crc.testing:6443/apis/quota.openshift.io/v1?timeout=32s
retrieving API resource for kuttl.dev/v1beta1, Kind=TestAssert failed: the server could not find the requested resource
retrieving API resource for kuttl.dev/v1beta1, Kind=TestAssert failed: the server could not find the requested resource
Error: asserts not valid
```
The root cause of the above result was that the image and the
repository were not aligned as described under "Align image and
repository".


