# Deploys sensu checks for an Openstack controller.
class sys11monitoring::profile::openstack_controller() {

  # Directory for common functions used by multiple checks.

  file{'/usr/lib/nagios/plugins/common/':
    ensure  => directory,
    mode    => '0555',
    require => Package['nagios-plugins-basic'],
  }


  ### Common functions ###

  file{'/usr/lib/nagios/plugins/common/boot_instance.sh':
    ensure  => file,
    mode    => '0444',
    source  => "puppet:///modules/$module_name/common/boot_instance.sh",
    require => File['/usr/lib/nagios/plugins/common/'],
  }



  ### Individual checks ###

  # Checks for working instance boot (Indicates working Nova, Glance and Heat)

  file {'/usr/lib/nagios/plugins/check_instance_boot':
    ensure  => file,
    mode    => '0555',
    source  => "puppet:///modules/$module_name/check_instance_boot",
    require => [ Package['nagios-plugins-basic'], File['/usr/lib/nagios/plugins/common/boot_instance.sh'] ],
  }

  sensu::check { 'check_instance_boot':
    command     => '/usr/lib/nagios/plugins/check_instance_boot',
    require     => File['/usr/lib/nagios/plugins/check_instance_boot'],
    interval    => '600',
    occurrences => '2',
  }

}
