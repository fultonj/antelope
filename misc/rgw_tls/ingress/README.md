# ingress experiment

This directory contains k8s manifests which I hoped could be
modified to have haproxy on k8s proxy to RGW on edpm nodes instead of
using the `ingress.rgw.default` provided by
[cephadm](https://docs.ceph.com/en/reef/cephadm/services/rgw/).
This is approach is on hold.
