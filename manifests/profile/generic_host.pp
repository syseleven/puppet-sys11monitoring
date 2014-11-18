class sys11monitoring::profile::generic_host() {
  # iso9660 is /config metadata filesystem, it always is 100%
  sensu::check { 'diskspace':
    command => '/opt/sensu-community-plugins/plugins/system/check-disk.rb -x iso9660',
  }

  file {'/usr/lib/nagios/plugins/check_hn_load':
    ensure => file,
    mode   => '0555',
    source => "puppet:///modules/$module_name/check_hn_load",
  }

  sensu::check { 'load':
    command => '/usr/lib/nagios/plugins/check_hn_load -p /usr/lib/nagios/plugins -w  -c',
    require => File['/usr/lib/nagios/plugins/check_hn_load'],
  }


  file {'/usr/lib/nagios/plugins/check_ram':
    ensure => file,
    mode   => '0555',
    source => "puppet:///modules/$module_name/check_ram",
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
    }

    sensu::check { 'bonding':
      command => '/usr/lib/nagios/plugins/check_linux_bonding',
      require => File['/usr/lib/nagios/plugins/check_linux_bonding'],
    }
  }
}
