class sys11monitoring::profile::generic_host(
  $check_reboot_needed = false,
) {
  # iso9660 is /config metadata filesystem, it always is 100%
  sensu::check { 'diskspace':
    command => '/opt/sensu-community-plugins/plugins/system/check-disk.rb -x iso9660',
  }

  file {'/usr/lib/nagios/plugins/check_hn_load':
    ensure  => file,
    mode    => '0555',
    source  => "puppet:///modules/$module_name/check_hn_load",
    require => Package['nagios-plugins-basic'],
  }

  sensu::check { 'load':
    command => '/usr/lib/nagios/plugins/check_hn_load -p /usr/lib/nagios/plugins -w  -c',
    require => File['/usr/lib/nagios/plugins/check_hn_load'],
  }


  file {'/usr/lib/nagios/plugins/check_ram':
    ensure => file,
    mode   => '0555',
    source => "puppet:///modules/$module_name/check_ram",
    require => Package['nagios-plugins-basic'],
  }

  sensu::check { 'ram':
    command => '/usr/lib/nagios/plugins/check_ram',
    require => File['/usr/lib/nagios/plugins/check_ram'],
  }


  if $::kernel == 'Linux' {
    # check_linux_bonding itselfs checks if there are bonds
    file {'/usr/lib/nagios/plugins/check_linux_bonding':
      ensure => file,
      mode   => '0555',
      source => "puppet:///modules/$module_name/check_linux_bonding",
      require => Package['nagios-plugins-basic'],
    }

    sensu::check { 'bonding':
      command => '/usr/lib/nagios/plugins/check_linux_bonding',
      require => File['/usr/lib/nagios/plugins/check_linux_bonding'],
    }
  }

  if $check_reboot_needed {
    file {'/usr/lib/nagios/plugins/check_reboot_needed':
      ensure => file,
      mode   => '0555',
      source => "puppet:///modules/$module_name/check_reboot_needed",
    }

    sensu::check { 'reboot_needed':
      command  => '/usr/lib/nagios/plugins/check_reboot_needed',
      interval => 86400,
      require  => File['/usr/lib/nagios/plugins/check_reboot_needed'],
    }
  }
}
