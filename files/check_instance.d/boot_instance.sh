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
    default: CirrOS 0.3.4 amd64
    description: Name of image to use for test instance
  flavor_testnode:
    type: string
    default: m1.micro
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

        sleep 15
        if curl -I http://169.254.169.254 | grep -q 'HTTP/1.1 200 OK'; then
          echo "TESTVM: OK - got metadata" > /dev/console
        else
          echo "TESTVM: CRITICAL - got no metadata" > /dev/console
        fi

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




check_network() {
  sleep 30
  testnode_id=$(heat output-show "$stack_id" testnode_id | sed 's/"//g')

  ret=$(nova console-log "${testnode_id}" | grep 'TESTVM:')

  if [[ $ret = *CRITICAL* ]]; then
    echo 'CRITICAL - VM ${testnode_id} could not get metadata [midonet]'
    return 2 # CRITICAL, since none got through
  elif [[ $ret = *OK* ]]; then
    echo "OK - VM ${testnode_id} could access metadata URL [midonet]"
    return 0
  else
    echo 'Unkown - VM ${testnode_id} could not get metadata and script got no return value [midonet]'
    return 2
  fi
}
