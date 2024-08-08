# Networking options for ci-framework storage jobs

There are cases where EDPM nodes need to be connected to the
"OSP external network" (as seen in the diagram under
[networking](https://github.com/openstack-k8s-operators/dev-docs/blob/main/networking.md)).

In this example I will: 

- Use os-net-config to put an EDPM node on an external network
- Host the public RGW endpoint on the external network
- ensure that a tempest pod can access that endpoint
