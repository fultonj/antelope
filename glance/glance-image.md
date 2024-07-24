# Build your own Glance image

This is a guide to build your own version of the
[openstack-glance-api](https://quay.io/repository/podified-antelope-centos9/openstack-glance-api?tab=tags) in
your own quay repository (unlike [this document](image.md) which is to build a `glance-operator`).
The image can then be pushed to a RHOSO18 deployment as described in
[dev-docs custom-images section](https://github.com/openstack-k8s-operators/dev-docs/blob/main/version_updates.md#custom-images-for-other-openstack-services).

In this example I want
`quay.io/fultonj/podified-master-centos9/openstack-glance-api:pr924824`
to host the same image as
[openstack-glance-api](https://quay.io/repository/podified-antelope-centos9/openstack-glance-api?tab=tags)
but to also have
[Glance patch 924824](https://review.opendev.org/c/openstack/glance/+/924824).

## Use TCIB to build an unmodified local copy of the image

Before I apply the patch I want to confirm I can build the same
default image but host it in my quay.

Use [TCIB](https://github.com/openstack-k8s-operators/tcib).

Follow the
[setup](https://github.com/openstack-k8s-operators/tcib/tree/main?tab=readme-ov-file#setup)
and then the
[Building images with local changes](https://github.com/openstack-k8s-operators/tcib/tree/main?tab=readme-ov-file#building-images-with-local-changes)
guides (though I didn't apply any local changes yet).

I used this:
```
[fultonj@runcible repo-setup{main}]$ cat containers.yaml
container_images:
  - imagename: quay.io/podified-antelope-centos9/openstack-glance-api:current-podified
[fultonj@runcible repo-setup{main}]$
```
Within the venv, `openstack tcib container image build` failed until I
linked `/usr/share/tcib` to where I had closned the tcib repos:
`sudo ln -s /home/fultonj/tcib/tcib/ /usr/share/tcib`.

When `openstack tcib container image build` is run within the venv an
Ansible playbook is run and a log is generated showing the image build
location.

```
[fultonj@runcible base]$ grep COMMIT /tmp/container-builds/a7a02754-67e2-4c22-b479-196f8b7c30cb/base/os/glance-api/glance-api-build.log
COMMIT localhost/podified-master-centos9/openstack-glance-api:current-podified
[fultonj@runcible base]$
```
So I confirm I built my Glance image:
```
[fultonj@runcible base]$ sudo podman images | grep localhost
localhost/podified-master-centos9/openstack-glance-api   current-podified                           2639aa0e9581  16 hours ago  961 MB
localhost/podified-master-centos9/openstack-os           current-podified                           967591dc4b05  16 hours ago  349 MB
localhost/podified-master-centos9/openstack-base         current-podified                           85c7395479db  16 hours ago  209 MB
[fultonj@runcible base]$
```

## Publish the image to your personal quay

Tag the image:
```
sudo podman tag \
  localhost/podified-master-centos9/openstack-glance-api:current-podified \
  quay.io/fultonj/podified-master-centos9/openstack-glance-api:current-podified
```

Use the quay.io web interface to create an encrypted password and
confirm it works with `podman login`.
```
sudo podman login -u="fultonj" -p="************" quay.io
```
Push the image:
```
sudo podman push \
  quay.io/fultonj/podified-master-centos9/openstack-glance-api:current-podified
```
For example:
```
(.venv) [fultonj@runcible tcib]$ sudo podman push quay.io/fultonj/podified-master-centos9/openstack-glance-api:current-podified
Getting image source signatures
Copying blob 47adde196eb6 done   | 
Copying blob 03f35e6f0494 done   | 
Copying blob c8a46543157a done   | 
Copying blob 43735fbce921 skipped: already exists  
Copying config 2639aa0e95 done   | 
Writing manifest to image destination
(.venv) [fultonj@runcible tcib]$ 
```

I verify I can see the image here:

https://quay.io/repository/fultonj/podified-master-centos9/openstack-glance-api?tab=tags&tag=current-podified

Use the [settings](https://quay.io/repository/fultonj/podified-master-centos9/openstack-glance-api?tab=settings&tag=current-podified)
tab to make it public so that the OCP can download it.

## Confirm you can use the image from quay

Follow the [dev-docs custom-images section](https://github.com/openstack-k8s-operators/dev-docs/blob/main/version_updates.md#custom-images-for-other-openstack-services).

```
[zuul@controller-0 ~]$ oc get OpenStackVersion
NAME           TARGET VERSION   AVAILABLE VERSION   DEPLOYED VERSION
controlplane   0.0.1            0.0.1               0.0.1
[zuul@controller-0 ~]$ 
```
Open the CR with `oc edit OpenStackVersion controlplane` and change
```
spec:
  customContainerImages: {}
  targetVersion: 0.0.1
```
to:
```
spec:
  customContainerImages:
    glanceAPIImage: quay.io/fultonj/podified-master-centos9/openstack-glance-api:current-podified
  targetVersion: 0.0.1
```
Observe k8s deploying the new image.
```
[zuul@controller-0 ~]$ oc get pods | grep glance | grep -v dbpurge
glance-az1-edge-api-0                                             3/3     Running             0          9d
glance-az2-edge-api-0                                             3/3     Running             0          8d
glance-db-sync-sw5pf                                              0/1     ContainerCreating   0          31s
glance-default-external-api-0                                     3/3     Running             0          8d
glance-default-internal-api-0                                     3/3     Running             0          8d
[zuul@controller-0 ~]$ 
...
[zuul@controller-0 ~]$ oc get pods | grep glance | grep -v dbpurge
glance-az1-edge-api-0                                             0/3     ContainerCreating   0          27s
glance-az2-edge-api-0                                             3/3     Running             0          25s
glance-db-sync-sw5pf                                              0/1     Completed           0          75s
glance-default-external-api-0                                     0/3     ContainerCreating   0          25s
glance-default-internal-api-0                                     3/3     Running             0          26s
[zuul@controller-0 ~]$ 
```
Confirm that the image has been replaced:
```
[zuul@controller-0 ~]$ oc get pod glance-az1-edge-api-0 -o yaml | fgrep image: | sort | uniq
    image: quay.io/fultonj/podified-master-centos9/openstack-glance-api:current-podified
[zuul@controller-0 ~]$ 
```

Test that the new image works before it's patched.

## Use TCIB to build an modified local copy of the image

I now want to apply
[Glance patch 924824](https://review.opendev.org/c/openstack/glance/+/924824)
and build a new image.

As per [glance-api.yaml](https://github.com/openstack-k8s-operators/tcib/blob/main/container-images/tcib/base/os/glance-api/glance-api.yaml#L12)
in TCIB, I see that it builds the container by running a series of
commands including the installation of the `glance-api` package with
`dnf`. There are many ways to add the patch but in my case I will
append the following command to the end of the list of commands.
```
curl -k -L https://raw.githubusercontent.com/openstack/glance/ee7e96f06af741bb34bedac18fa2c4616fcc3905/glance/location.py -o /usr/lib/python3.9/site-packages/glance/location.py
```
After making the edit:
```
(.venv) [fultonj@runcible glance-api{main}]$ git diff
diff --git a/container-images/tcib/base/os/glance-api/glance-api.yaml b/container-images/tcib/base/os/glance-api/glance-api.yaml
index dd242c1..7c79fbf 100644
--- a/container-images/tcib/base/os/glance-api/glance-api.yaml
+++ b/container-images/tcib/base/os/glance-api/glance-api.yaml
@@ -4,6 +4,7 @@ tcib_actions:
 - run: cp /usr/share/tcib/container-images/kolla/glance-api/extend_start.sh /usr/local/bin/kolla_extend_start
 - run: chmod 755 /usr/local/bin/kolla_extend_start
 - run: sed -i -r 's,^(Listen 80),#\1,' /etc/httpd/conf/httpd.conf &&  sed -i -r 's,^(Listen 443),#\1,' /etc/httpd/conf.d/ssl.conf
+- run: curl -k -L https://raw.githubusercontent.com/openstack/glance/ee7e96f06af741bb34bedac18fa2c4616fcc3905/glance/location.py -o /usr/lib/python3.9/site-packages/glance/location.py
 tcib_packages:
   common:
   - httpd
(.venv) [fultonj@runcible glance-api{main}]$
```
I ran the same comamnd to build in the venv as described in "Use TCIB to build an unmodified local copy of the image".
```
openstack tcib container image build --config-file containers.yaml --repo-dir /tmp/repos/ --tcib-extras tcib_package=
```
I can see the `curl` to apply the patch was run.
```
[fultonj@runcible ~]$ grep curl -B 1 -A 5 /tmp/container-builds/ac88bc87-c9d7-4270-98c7-8b0b5e64a6fc/base/os/glance-api/glance-api-build.log
STEP 7/10: RUN sed -i -r 's,^(Listen 80),#\1,' /etc/httpd/conf/httpd.conf &&  sed -i -r 's,^(Listen 443),#\1,' /etc/httpd/conf.d/ssl.conf
STEP 8/10: RUN curl -k -L https://raw.githubusercontent.com/openstack/glance/ee7e96f06af741bb34bedac18fa2c4616fcc3905/glance/location.py -o /usr/lib/python3.9/site-packages/glance/location.py
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100 27092  100 27092    0     0   117k      0 --:--:-- --:--:-- --:--:--  117k
STEP 9/10: USER glance
STEP 10/10: LABEL "tcib_build_tag"="current-podified"
[fultonj@runcible ~]$
```

From `sudo podman images | grep glance` I see the SHA has changed.
```
localhost/podified-master-centos9/openstack-glance-api                  current-podified                           8ca87f850555  39 hours ago  961 MB
```
I will tag it for upstream:
```
sudo podman tag \
  localhost/podified-master-centos9/openstack-glance-api:current-podified \
  quay.io/fultonj/podified-master-centos9/openstack-glance-api:pr924824
```
and now I see the SHA and tag are aligned.
```
$ sudo podman images | grep pr924824
quay.io/fultonj/podified-master-centos9/openstack-glance-api            pr924824                                   8ca87f850555  39 hours ago  961 MB
$
```
As described above I push it to quay:
```
sudo podman push \
  quay.io/fultonj/podified-master-centos9/openstack-glance-api:pr924824
```
and I see my image is available.

https://quay.io/repository/fultonj/podified-master-centos9/openstack-glance-api?tab=tags&tag=pr924824

I can now use the above image as described in the
[dev-docs custom-images section](https://github.com/openstack-k8s-operators/dev-docs/blob/main/version_updates.md#custom-images-for-other-openstack-services).

I now see the new image has been deployed.
```
[zuul@controller-0 ~]$ oc get pods | grep glance | grep -v dbpurge
glance-3d293-default-external-api-0                               0/3     ContainerCreating   0               8s
glance-3d293-default-external-api-1                               3/3     Running             0               20s
glance-3d293-default-external-api-2                               3/3     Running             0               43s
glance-3d293-default-internal-api-0                               0/3     ContainerCreating   0               7s
glance-3d293-default-internal-api-1                               3/3     Running             0               19s
glance-3d293-default-internal-api-2                               3/3     Running             0               44s
glance-db-sync-sbcvw                                              0/1     Completed           0               65s
[zuul@controller-0 ~]$ oc get pods glance-3d293-default-external-api-0 -o yaml | fgrep image: | sort | uniq
    image: quay.io/fultonj/podified-master-centos9/openstack-glance-api@sha256:a36a9ae074dc3ea0674b88351589c0a84bd264d30ef62a0c42bab5081c0d3b4c
[zuul@controller-0 ~]$ 
```
and I can see the patch in place.
```
[zuul@controller-0 ~]$ oc rsh --container glance-api glance-3d293-default-external-api-0
sh-5.1# grep -C 10 skipping /usr/lib/python3.9/site-packages/glance/location.py 
            member_ids = [m.member_id for m in member_repo.list()]
        for location in image.locations:
            if CONF.enabled_backends:
                # NOTE(whoami-rajat): Do not set_acls if store is not defined
                # on this node. This is possible in case of edge deployment
                # that image location is present but the actual store is
                # not related to this node.
                image_store = location['metadata'].get('store')
                if image_store not in CONF.enabled_backends:
                    msg = (_("Store %s is not available on "
                             "this node, skipping `_set_acls` "
                             "call.") % image_store)
                    LOG.debug(msg)
                    continue
                self.store_api.set_acls_for_multi_store(
                    location['url'], image_store,
                    public=public, read_tenants=member_ids,
                    context=self.context
                )
            else:
                self.store_api.set_acls(location['url'], public=public,
--
            member_ids = [m.member_id for m in self.repo.list()]
            for location in self.image.locations:
                if CONF.enabled_backends:
                    # NOTE(whoami-rajat): Do not set_acls if store is not
                    # defined on this node. This is possible in case of edge
                    # deployment that image location is present but the actual
                    # store is not related to this node.
                    image_store = location['metadata'].get('store')
                    if image_store not in CONF.enabled_backends:
                        msg = (_("Store %s is not available on "
                                 "this node, skipping `_set_acls` "
                                 "call.") % image_store)
                        LOG.debug(msg)
                        continue
                    self.store_api.set_acls_for_multi_store(
                        location['url'], image_store,
                        public=public, read_tenants=member_ids,
                        context=self.context
                    )
                else:
                    self.store_api.set_acls(location['url'], public=public,
sh-5.1# 
```
