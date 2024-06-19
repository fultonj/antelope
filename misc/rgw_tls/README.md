# Test RGW with TLS

Misc files for testing this PR

https://github.com/openstack-k8s-operators/ci-framework/pull/1865

Put [test_rgw.yml](test_rgw.yml) in ~/ci-framework and then:

```
cd ~/ci-framework
ln -s roles/cifmw_cephadm/templates

ansible-playbook -i ~/reproducer-inventory test_rgw.yml \ 
  -e cifmw_cephadm_certificate="/etc/pki/tls/example.com.crt" \
  -e cifmw_cephadm_key="/etc/pki/tls/example.com.key" \
  -e cifmw_cephadm_rgw_network=192.168.122.0/24 \
  -e cephadm_vip=192.168.122.2
```

[dns](dns) contains notes and k8s manifests about the DNS problems.
