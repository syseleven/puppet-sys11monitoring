# 2015, j.grassler@syseleven.de

# Global state used across functions.

stack_id=''              # ID of the Heat stack to use.
image_id=''              # ID of the Glance image to use.

# Write out Heat template used for spawning a test instance.

write_heat_template() {
cat > $1 <<'EOF'
# HOT template
# 
# heat stack-create --template-file checkcloud.yaml checkcloud
#
heat_template_version: 2013-05-23

description: >
  This template tests basic functionality of an Openstack installation's Glance,
  Heat, Neutron and Nova services by spawning an Openstack instance that pings
  its default gateway and logs the result to /dev/console for retrieval through
  nova.
  
parameters:
  image:
    type: string
    default: CirrOS 0.3.2 amd64
    description: Name of image to use for test instance
  flavor_testnode:
    type: string
    default: m1.tiny
    description: Flavor to use for test instance
 
resources:

  admin_net:
    type: OS::Neutron::Net
    properties: 
      name:
        str_replace:
          template: $cloud_admin
          params: 
            $cloud: { get_param: 'OS::stack_name' }

  admin_subnet:
    type: OS::Neutron::Subnet
    properties:
      # Because contrail does not support subnet names, so forcing to be empty
      name:
      network_id: {get_resource: admin_net}
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

        gateway=$(ip route show | grep default | awk '{print $3}')

        ping -c 10 $gateway > /dev/console

  testnode_admin_port:
    type: OS::Neutron::Port
    properties:
      network_id: { get_resource: admin_net }

outputs:
  testnode_id:
    description: test instance's nova ID
    value: { get_resource: testnode }
EOF
}




check_vm_pings() {
  sleep 30
  testnode_id=$(heat output-show "$stack_id" testnode_id | sed 's/"//g')

  pings=$(nova console-log "${testnode_id}" | grep '64 bytes from' | wc -l)

  if [ $pings -eq 0 ]; then
    echo 'CRITICAL - VM could not ping its gateway.'
    return 2 # CRITICAL, since none got through
  elif [ $pings -ne 10 ]; then
    echo "WARNING - Not all of the VM's pings reached its gateway (${pings} got through)."
    return 1
  elif [ $pings -eq 10 ]; then
    echo "OK - All of the VM's pings reached its gateway."
    return 0
  fi
}


# Removes the heat stack used for testing.

cleanup_heat_stack() {
  rm "${heat_template}"

  if [ -n "$stack_id" ]; then
    heat stack-delete "${stack_id}" > /dev/null

    watch -g heat stack-list \| grep ${stack_id} > /dev/null 2>&1

    if heat stack-list | grep ${stack_id}; then
      return 1  # Stack still present - shouldn't happen.
    else
      return 0
    fi
  fi
}
