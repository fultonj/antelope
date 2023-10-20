# CI for HCI

When a patch is submitted to ci-framework, edpm-ansible, data-plane
operator, etc, a ci-job is run in https://review.rdoproject.org
including the job `podified-multinode-edpm-deployment-crc` which
uses one compute and one crc. This is a gating job.

[PR 588 to ci-framework](https://github.com/openstack-k8s-operators/ci-framework/pull/588)
introduced `podified-multinode-hci-deployment-crc-3comp-testproject`.
As of October 2023 this is not a gating job. It is planned that it
will be a periodic job so we can check nightly results. If you
write code in https://github.com/openstack-k8s-operators and want
the CI to run it against HCI, then you can create a DNM patch in
`testproject` which `depends-on` your patch. For example the following
tested the original
[PR 588](https://github.com/openstack-k8s-operators/ci-framework/pull/588).

  https://review.rdoproject.org/r/c/testproject/+/48781


## Create your own test project patch

[PR 704](https://github.com/openstack-k8s-operators/ci-framework/pull/704)
is a simple patch to ci-framework which introduces a new variable
`ceph_spec_fqdn` and gets the
`podified-multinode-hci-deployment-crc-3comp-testproject`
job to test it by modifying 
`ci_framework/playbooks/06-deploy-edpm.yml`. After PR704 was created I
created a `testproject` patch to test it by doing this.

```
# This assumes that the git-review RPM is already installed

declare -a repos=(
                      'r/testproject' \
                      # add the next repo here
		 );

GERRIT_USER='fultonj'
git config --global gitreview.username $GERRIT_USER

for REPO in "${repos[@]}"; do
    DIR=$(echo $REPO | awk 'BEGIN { FS = "/" } ; { print $2 }')
    if [ ! -d $DIR ]; then
	git clone https://review.rdoproject.org/$REPO.git
	pushd $DIR
	git remote add gerrit ssh://$GERRIT_USER@review.rdoproject.org:29418/$DIR.git
	git review -s
	popd
    fi
done
```

The above created this:

  https://review.rdoproject.org/r/c/testproject/+/50595
  
You create a new `.zuul.yaml` file with the job yaml and you put the
`depends-on` in the commit message. The CI should then run your new
code and you can click the review created to see the results of your
job.

