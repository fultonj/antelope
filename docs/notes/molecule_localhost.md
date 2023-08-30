# Building an ephemeral virtual machine for molecule localhost testing

The
[edpm_libvirt](https://github.com/openstack-k8s-operators/edpm-ansible/tree/main/roles/edpm_libvirt)
molecule senario uses the delegated driver to run against localhost.
Thus, it's better to run that test it inside an ephemeral virtual
machine which you can can snapshot and restore.

## Bootstrap

Boot a `CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2`
from https://cloud.centos.org/centos/9-stream/x86_64/images.

## DNF Repository

Use
[repo-setup](https://github.com/openstack-k8s-operators/repo-setup) to
configure your VM's DNF repositories.
```
pushd /tmp
curl -sL https://github.com/openstack-k8s-operators/repo-setup/archive/refs/heads/main.tar.gz | tar -xz
pushd repo-setup-main
python3 -m venv ./venv
PBR_VERSION=0.0.0 ./venv/bin/pip install ./
./venv/bin/repo-setup current-podified-dev
popd
```

## Git repository

```
dnf install -y git
git clone git@github.com:openstack-k8s-operators/edpm-ansible.git
```

## Prepare Molecule

```
pushd edpm-ansible
python3 -m venv molecule-venv
source molecule-venv/bin/activate
pip install --upgrade pip
pip install -r molecule-requirements.txt
popd
```

## Test 

Before running this test you might wish to snapshot your VM.

```
cd roles/edpm_libvirt/
molecule test --all
```
