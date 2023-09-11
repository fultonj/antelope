# Update CRC

`make crc` from
[install_yamls devsetup](https://github.com/openstack-k8s-operators/install_yamls/blob/main/devsetup/Makefile)
ensures there is a `~/bin/crc` binary before proceeding with the rest
of the CRC setup.

If `~/bin/crc` already exists, then it does not update it to the
latest version. Below is how I update it after I run `make crc_cleanup`.

```
export CRC_URL=https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/crc/latest/crc-linux-amd64.tar.xz
curl -L "${CRC_URL}" | tar -U --strip-components=1 -C ~/bin -xJf - *crc
ls -l $(which crc)
crc version
```

You can then go ahead with `make crc` to complete the setup.
