# 2015, j.grassler@syseleven.de, s.andres@syseleven.de
#
# Functions used by checks that spawn openstack instances.

# Checks if J. Random API service is usable.

check_service_ready() {
  service=$1

  if [ -x /usr/lib/nagios/plugins/check_${service}_api ]; then
    /usr/lib/nagios/plugins/check_${service}_api \
      --auth_url $OS_AUTH_URL \
      --username $OS_USERNAME \
      --password $OS_PASSWORD \
      --tenant admin > /dev/null 2>&1
    return $?
  else
    return 2
  fi
}


# Finds the first CirrOS image available in glance and records its ID.

get_cirros_image() {
    image_id=$(glance image-list | grep CirrOS | head -n 1 | awk '{print $2}')
    if [ -n $image_id ]; then
      return 0
    else
      return 1
    fi
}


# Spawns a heat stack based on the embedded template.

spawn_vm() {
  heat_template=$1
  if [ -n "$image_id" ]; then
    stack_id=$(heat stack-create --template-file "${heat_template}" check_instance_boot -P image=$image_id | grep check_instance_boot | awk '{print $2}')
  else
    stack_id=$(heat stack-create --template-file "${heat_template}" check_instance_boot | grep check_instance_boot | awk '{print $2}')
  fi

  if [ -z $stack_id ]; then
    return 2
  fi

  # Wait for stack status to change from CREATE_IN_PROGRESS to CREATE_{COMPLETE,FAILED}
  watch -g heat stack-show ${stack_id} \| grep CREATE_ > /dev/null 2>&1

  if heat stack-show ${stack_id} | grep CREATE_COMPLETE > /dev/null; then
    return 0
  else
    return 2
  fi
}


