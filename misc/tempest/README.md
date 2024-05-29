# Tempest on openstack-k8s-operators

If you create a
[CR of kind Tempest](https://openstack-k8s-operators.github.io/test-operator/crds.html#tempest-custom-resource)
then the
[test-operator](https://github.com/openstack-k8s-operators/test-operator)
will launch a pod and run tempest tests.

The ci-framework `test_operator` Ansible role can do the same
and has a [variable to override this CR](https://github.com/openstack-k8s-operators/ci-framework/blob/main/roles/test_operator/defaults/main.yml#L49)
(or the
`cifmw_tempest_tempestconf_config`
[part of it](https://github.com/openstack-k8s-operators/ci-framework/blob/main/roles/test_operator/defaults/main.yml#L72)). I use
[tempest_ansible_vars.yml](tempest_ansible_vars.yml)
with use my own branches of
[ci-framework](https://github.com/openstack-k8s-operators/ci-framework/compare/main...fultonj:ci-framework:rgw_test#) and
[architecture](https://github.com/openstack-k8s-operators/architecture/compare/main...fultonj:architecture:rgw_test) for
workarounds.

After ci-framework runs, if I want to re-run tempest then I edit the
CR it generates (e.g. [tempest.yml](tempest.yml)) and run it again like
this.
```bash
oc get tempest/tempest-tests -o yaml > tempest.yml 
vi tempest.yml
oc apply -f tempest.yml
oc logs -f tempest-tests-xyz
```

I then access the results of the test or the configuration it used
like this:
```bash
oc debug tempest-tests-xyz
cat /var/lib/tempest/external_files/tempest-tests/stestr_results.html
cat /var/lib/tempest/external_files/tempest-tests/etc/tempest.conf
```
I use [get.sh](get.sh) to get the HTML report to my local machine.
