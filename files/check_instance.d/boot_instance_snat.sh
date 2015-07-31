# 2015, j.grassler@syseleven.de, s.andres@syseleven.de

# Global state used across functions.

stack_id=''              # ID of the Heat stack to use.
image_id=''              # ID of the Glance image to use.

snat_dest=8.8.8.8

# Write out Heat template used for spawning a test instance.

get_public_net_id() {
  if [ -r /root/openrc ]; then
    . /root/openrc
  fi

  PATH=$PATH:/usr/lib/nagios/plugins/check_instance.d/

  get_first_external_net

}

write_heat_template() {
public_net_id=$(get_public_net_id)
cat > $1 <<EOF
# HOT template
# 
# heat stack-create --template-file checkcloud.yaml checkcloud
#
heat_template_version: 2013-05-23

description: >
  This template tests basic functionality of an Openstack installation's Glance,
  Heat, Neutron and Nova services by spawning an Openstack instance with an SNAT
  router that pings $snat_dest and logs the result to /dev/console for retrieval
  through nova.
  
parameters:
  image:
    type: string
    default: CirrOS 0.3.4 amd64
    description: Name of image to use for test instance
  flavor_testnode:
    type: string
    default: m1.tiny
    description: Flavor to use for test instance
  public_net_id:
    type: string
    default: $public_net_id
    description: ID of public network for which floating IP addresses will be allocated

 
resources:

  test_net_snat:
    type: OS::Neutron::Net
    properties: 
      name:
        str_replace:
          template: \$cloud_admin
          params: 
            \$cloud: { get_param: 'OS::stack_name' }

  test_subnet_snat:
    type: OS::Neutron::Subnet
    properties:
      # Because contrail does not support subnet names, so forcing to be empty
      name: test_subnet_snat
      network_id: {get_resource: test_net_snat}
      ip_version: 4
      cidr: 10.0.80.0/24
      allocation_pools:
      - {start: 10.0.80.10, end: 10.0.80.150}


  ### Test Node ###
  #################


  testnode:
    type: OS::Nova::Server
    properties:
      name: testnode
      image: { get_param: image }
      flavor: { get_param: flavor_testnode }
      networks:
        - port: { get_resource: testnode_admin_port }
      user_data_format: RAW  # Leave this in. Otherwise the ssh key specified in key_name won't get deployed. I'll buy you a beer if you tell me why that happens.
      user_data: |
        #!/bin/sh
        exec > /var/log/script_user_data.log 2>&1
        set -x

        sleep 40
        ping -c 10 $snat_dest > /dev/console

  testnode_admin_port:
    type: OS::Neutron::Port
    properties:
      network_id: { get_resource: test_net_snat }

  test_router_snat:
    type: OS::Neutron::Router
    properties:
      external_gateway_info: {"network": { get_param: public_net_id}, "enable_snat": true}
      name: test_router_snat

  router_subnet_bridge:
    type: OS::Neutron::RouterInterface
    depends_on:  test_subnet_snat
    properties:
      router_id: { get_resource: test_router_snat }
      subnet: { get_resource: test_subnet_snat }


outputs:
  testnode_id:
    description: test instance's nova ID
    value: { get_resource: testnode }
EOF
}




check_vm_pings() {
  sleep 60
  testnode_id=$(heat output-show "$stack_id" testnode_id | sed 's/"//g')

  pings=$(nova console-log "${testnode_id}" | grep '64 bytes from' | wc -l)
  #nova console-log "${testnode_id}"

  if [ $pings -eq 0 ]; then
    echo "CRITICAL - VM could not ping $snat_dest [contrail]"
    return 2 # CRITICAL, since none got through
  elif [ $pings -ne 10 ]; then
    echo "WARNING - Not all of the VM's pings reached $snat_dest (${pings}/10 got through) [contrail]"
    return 1
  elif [ $pings -eq 10 ]; then
    echo "OK - All of the VM's pings reached $snat_dest [contrail]"
    return 0
  fi
}
