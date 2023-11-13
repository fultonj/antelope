# Running the Glance EnvTest

The env tests can be run like this:
```
cd ~/glance-operator
make test
```
They should result in the folowing in less than a minute:
```
Ran 39 of 39 Specs in 34.519 seconds
SUCCESS! -- 39 Passed | 0 Failed | 0 Pending | 0 Skipped
```

## Overview

- EnvTesting was added to glance-operator in
  [PR239](https://github.com/openstack-k8s-operators/glance-operator/pull/239)

- See [EnvTest source](https://github.com/openstack-k8s-operators/glance-operator/tree/main/test/functional)

- See also the
  [general EnvTest docs](https://github.com/openstack-k8s-operators/docs/blob/main/envtest.md)

## Examples

In
[PR363](https://github.com/openstack-k8s-operators/glance-operator/pull/363),
a webhook was added for `GlanceAPI` (instead of just `Glance`). We see
[test/functional/suite_test.go](https://github.com/openstack-k8s-operators/glance-operator/blob/main/test/functional/suite_test.go#L199-L200)
was updated to create that webhook in the `BeforeSuite` call.

[PR334](https://github.com/openstack-k8s-operators/glance-operator/pull/334)
included a
[patch](https://github.com/openstack-k8s-operators/glance-operator/commit/2a8d70891ea9718aa41e8df7fa3088d0a033cfb8)
to
[test/functional/glance_controller_test.go](https://github.com/openstack-k8s-operators/glance-operator/blob/2a8d70891ea9718aa41e8df7fa3088d0a033cfb8/test/functional/glance_controller_test.go#L243-L246)
since the change involved creating an additional PVC the test is
updated to assert that it exists (or fail if it doesn't).
