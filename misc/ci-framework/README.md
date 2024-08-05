# ci-framework notes

I use
[ci-framework](https://github.com/openstack-k8s-operators/ci-framework)

On my laptop `~/cifw/` has a directory for each hypervisor I use. E.g.
[my home hypervisor](https://pcpartpicker.com/user/fultonj/saved/v9KLD3)
is called `hamfast` so in `~/cifw/hamfast/` I have my
[ci-framework fork](https://github.com/fultonj/ci-framework) and
[architecture fork](https://github.com/fultonj/architecture) it
looks like this:
```
[fultonj@runcible hamfast]$ ls -lF
total 12
drwxr-xr-x. 12 fultonj fultonj 4096 Aug  4 16:24 architecture/
drwxr-xr-x. 20 fultonj fultonj 4096 Aug  4 16:16 ci-framework/
-rwxr-xr-x.  1 fultonj fultonj 1451 Aug  4 16:42 deploy.sh*
drwxr-xr-x.  2 fultonj fultonj  154 Aug  4 19:56 logs/
[fultonj@runcible hamfast]$
```
My [deploy.sh](deploy.sh) script does the following for me:

- ensures I'm using the python venv
- tests if my ci_token has expried before starting the deployment
- rotates ansible log for each deployment
- passes the arguments to deploy [HCI VA](https://github.com/openstack-k8s-operators/architecture/tree/main/examples/va/hci)
- has a `deep_clean` option for to use before I redeploy

My [my-overrides.yml](my-overrides.yml) file ensures that LVMS is
used and applies other workarounds as should be explanatory by the
comments.

It also ensures that my architecture fork is used. The
[standard branch](https://github.com/fultonj/architecture/tree/standard)
of my fork disables Horizon but I can keep it update with other
changes I might want to test or I can just update
`cifmw_reproducer_repositories` to pull from a different source.
