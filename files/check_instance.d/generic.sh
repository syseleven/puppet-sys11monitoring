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
  stack_name=$2
  local try=0

  # try to delete old stack 10 times
  # (should not exist, but does, because heat stack-delete
  # may fail at cleanup because of unstable heat api)
  while sleep 5; do
    ((try++))
    if ((try == 10)); then
      echo "Could not delete old stack 10 times [heat]"
      break
    fi
    output=$(heat stack-list|grep "$stack_name")
    if echo "$output" | grep -q DELETE_IN_PROGRESS; then
      continue
    else
      heat stack-delete "$stack_name" >/dev/null 2>&1
    fi

    # break out of loop when no stack can be found (==is deleted)
    echo $output | grep -q "$stack_name" || break

    if echo "$output" | grep -q FAIL; then
      heat stack-delete "$stack_name" >/dev/null 2>&1
    fi
  done

  if [ -n "$image_id" ]; then
    stack_id=$(heat stack-create --template-file "${heat_template}" $stack_name -P image=$image_id | grep $stack_name | awk '{print $2}')
  else
    stack_id=$(heat stack-create --template-file "${heat_template}" $stack_name | grep $stack_name | awk '{print $2}')
  fi

  if [ -z $stack_id ]; then
    return 2
  fi

  # Wait for stack status to change from CREATE_IN_PROGRESS to CREATE_{COMPLETE,FAILED}
  # sometimes watch never finishes
  timeout 30 watch -g heat stack-show ${stack_id} \| grep CREATE_ > /dev/null 2>&1

  if heat stack-show ${stack_id} | grep CREATE_COMPLETE > /dev/null; then
    return 0
  else
    return 2
  fi
}

show_physical_host_of_vm() {
  heat_resource=$(heat resource-show ${stack_id} testnode | awk '/physical_resource_id/ { print $4 }')
  physical_host=$(nova show ${heat_resource} | awk '/hypervisor_hostname/ { print $4 }')
  echo "(VM compute node: ${physical_host})"
}

# Removes the heat stack used for testing.

cleanup_heat_stack() {
  rm "${heat_template}"

  if [ -n "$stack_id" ]; then
    heat stack-delete "${stack_id}" > /dev/null

    # sometimes watch never finishes
    timeout 30 watch -g heat stack-list \| grep ${stack_id} > /dev/null 2>&1

    if heat stack-list | grep ${stack_id}; then
      return 1  # Stack still present - shouldn't happen.
    else
      return 0
    fi
  fi
}
