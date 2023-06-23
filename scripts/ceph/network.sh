#!/usr/bin/env bash

VERBOSE=1
FILES=1
EXECUTE=1
VIPS=0
PATCH_ANSIBLE_TEMPLATE=0

export GATEWAY=192.168.122.1
export CTLPLANE_IP=192.168.122.100
export CTLPLANE_VIP=192.168.122.99
export INTERNAL_IP=$(sed -e 's/192.168.122/172.17.0/' <<<"$CTLPLANE_IP")
export STORAGE_IP=$(sed -e 's/192.168.122/172.18.0/' <<<"$CTLPLANE_IP")
export STORAGE_MGMT_IP=$(sed -e 's/192.168.122/172.20.0/' <<<"$CTLPLANE_IP")
export TENANT_IP=$(sed -e 's/192.168.122/172.10.0/' <<<"$CTLPLANE_IP")
export EXTERNAL_IP=$(sed -e 's/192.168.122/172.19.0/' <<<"$CTLPLANE_IP")
export NEUTRON_INTERFACE=vlan44

if [[ $VERBOSE -eq 1 ]]; then
    echo $INTERNAL_IP
    echo $STORAGE_IP
    echo $TENANT_IP
    echo $EXTERNAL_IP
fi

if [[ $FILES -eq 1 ]]; then
    sudo mkdir -p /etc/os-net-config
    cat << EOF | sudo tee /etc/os-net-config/config.yaml
network_config:
- type: ovs_bridge
  name: br-ctlplane
  mtu: 1500
  use_dhcp: false
  dns_servers:
  - $GATEWAY
  domain: []
  addresses:
  - ip_netmask: $CTLPLANE_IP/24
  routes:
  - ip_netmask: 0.0.0.0/0
    next_hop: $GATEWAY
  members:
  - type: interface
    name: nic1
    mtu: 1500
    # force the MAC address of the bridge to this interface
    primary: true

  # external
  - type: vlan
    mtu: 1500
    vlan_id: 44
    addresses:
    - ip_netmask: $EXTERNAL_IP/24
    routes: []

  # internal
  - type: vlan
    mtu: 1500
    vlan_id: 20
    addresses:
    - ip_netmask: $INTERNAL_IP/24
    routes: []

  # storage
  - type: vlan
    mtu: 1500
    vlan_id: 21
    addresses:
    - ip_netmask: $STORAGE_IP/24
    routes: []

  # storage_mgmt
  - type: vlan
    mtu: 1500
    vlan_id: 23
    addresses:
    - ip_netmask: $STORAGE_MGMT_IP/24
    routes: []

  # tenant
  - type: vlan
    mtu: 1500
    vlan_id: 22
    addresses:
    - ip_netmask: $TENANT_IP/24
    routes: []
EOF

    cat << EOF | sudo tee /etc/cloud/cloud.cfg.d/99-edpm-disable-network-config.cfg
network:
  config: disabled
EOF
fi

if [[ $EXECUTE -eq 1 ]]; then
    sudo systemctl enable network
    sudo os-net-config -c /etc/os-net-config/config.yaml
fi

if [[ $VIPS -eq 1 ]]; then
    # Add VIPs to manually configured networks
    sudo ip addr add 172.20.0.2/32 dev vlan23
    sudo ip addr add 172.17.0.2/32 dev vlan20
    sudo ip addr add 172.18.0.2/32 dev vlan21
    sudo ip addr add 172.19.0.2/32 dev vlan44
    # sudo ip addr add 172.10.0.2/32 dev vlan22
    ip a | grep /32
fi

if [[ $VERBOSE -eq 1 ]]; then
    sudo ovs-vsctl show
    ip route
    ip a
fi

if [[ PATCH_ANSIBLE_TEMPLATE -eq 1 ]]; then
    sudo cp /usr/share/ansible/roles/tripleo_network_config/templates/standalone.j2 /root/
    sudo cp ~/zed/adopt/standalone/standalone.j2 /usr/share/ansible/roles/tripleo_network_config/templates/standalone.j2
fi
