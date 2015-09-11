# 2015, j.grassler@syseleven.de, s.andres@syseleven.de

# Global state used across functions.

stack_id=''              # ID of the Heat stack to use.
image_id=''              # ID of the Glance image to use.

# 37.123.105.116 is a sys11 GTM
snat_dest=37.123.105.116

# Write out Heat template used for spawning a test instance.

get_public_net_id() {
  if [ -r /root/admin-openrc.sh ]; then
    . /root/admin-openrc.sh
  fi

  PATH=$PATH:/usr/lib/nagios/plugins/check_instance.d/

  get_first_external_net

}

write_heat_template() {
public_net_id=$(get_public_net_id)
cat > $1 <<EOF
heat_template_version: 2014-10-16

description: >
    Creates a router + net + subnet + interface + VM
    WARNING: This assigns 2 floating IPs - 1 for router, 1 for VM
parameters:
  public_network_id:
    type: string
    default: $public_net_id
  image:
    type: string
    default: CirrOS 0.3.4 amd64
  flavor:
    type: string
    default: m1.small

resources:
  testnode:
    type: OS::Nova::Server
    properties:
      image: { get_param: image }
      flavor: { get_param: flavor }
      networks:
        - port: { get_resource: server2_port }
      user_data_format: RAW  # Leave this in. Otherwise the ssh key specified in key_name won't get deployed. I'll buy you a beer if you tell me why that happens.
      user_data: |
        #!/bin/sh
        exec > /var/log/script_user_data.log 2>&1
        set -x

        #sleep 10
        ping -c 10 $snat_dest > /dev/console

  server2_port:
    type: OS::Neutron::Port
    properties:
      network_id: { get_resource: network}
      security_groups: [{ get_resource: server_security_group }]

  #server2_floating_ip:
  #  type: OS::Neutron::FloatingIP
  #  properties:
  #    floating_network: { get_param: public_network_id }
  #    port_id: { get_resource: server2_port }

  network:
    type: OS::Neutron::Net
    properties:
      name: example-test-net

  subnet:
    type: OS::Neutron::Subnet
    depends_on: router
    properties:
      name: examplae_subnet
      dns_nameservers:
        - 37.123.105.117
      network_id: {get_resource: network}
      ip_version: 4
      cidr: 10.0.0.0/24
      # optional
      gateway_ip : 10.0.0.1
      allocation_pools:
      - {start: 10.0.0.10, end: 10.0.0.250}

  router:
    type: OS::Neutron::Router
    properties:
      external_gateway_info: {"network": { get_param: public_network_id }}

  router_subnet_bridge:
    type: OS::Neutron::RouterInterface
    depends_on:  subnet
    properties:
      router_id: { get_resource: router }
      subnet: { get_resource: subnet }

  server_security_group:
    type: OS::Neutron::SecurityGroup
    properties:
      description: Test group to demonstrate Neutron security group functionality with Heat.
      name: test-security-group
      rules: [
        {remote_ip_prefix: 0.0.0.0/0,
        protocol: tcp,
        port_range_min: 22,
        port_range_max: 22},
        {remote_ip_prefix: 0.0.0.0/0,
        protocol: icmp},
        {remote_ip_prefix: 10.0.0.0/8,
        protocol: tcp,
        port_range_min: 5,
        port_range_max: 10000}]
outputs:
  testnode_id:
    description: test instance's nova ID
    value: { get_resource: testnode }
EOF
}




check_vm_pings() {
  sleep 20
  testnode_id=$(heat output-show "$stack_id" testnode_id | sed 's/"//g')

  pings=$(nova console-log "${testnode_id}" | grep '64 bytes from' | wc -l)
  #nova console-log "${testnode_id}"

  if [ $pings -eq 0 ]; then
    echo "CRITICAL - VM could not ping $snat_dest [midonet]"
    return 2 # CRITICAL, since none got through
  elif [ $pings -ne 10 ]; then
    echo "WARNING - Not all of the VM's pings reached $snat_dest (${pings}/10 got through) [midonet]"
    return 1
  elif [ $pings -eq 10 ]; then
    echo "OK - All of the VM's pings reached $snat_dest [midonet]"
    return 0
  fi
}
