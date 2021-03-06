class sys11monitoring::profile::generic_host(
  $zombie_procs_warn_limit = 2,
  $zombie_procs_crit_limit = 5,
  $total_procs_warn_limit = 150,
  $total_procs_crit_limit = 200,
  $check_reboot_needed = false,
  $type = hiera('sys11monitoring::type', 'sensu'),
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
      command                 => '/usr/lib/nagios/plugins/check_reboot_needed',
      interval                => 86400,
      require                 => File['/usr/lib/nagios/plugins/check_reboot_needed'],
      custom                  => {
        'alert_on_occurrence' => 1,
      },
    }
  }

  if versioncmp($::operatingsystemmajrelease, '14.04') != 1 {
    # we only need this on ubuntu <= 14.04, since newer versions,
    # systemd replaced upstart.
    include apt

    apt::ppa { 'ppa:syseleven-platform/upstartwatch': }

    package { 'python3-upstartwatch':
      ensure  => latest,
      require => Apt::Ppa['ppa:syseleven-platform/upstartwatch'],
    }

    service { 'upstartwatch':
      ensure  => running,
      enable  => true,
      require => Package['python3-upstartwatch'],
    }

    file {'/usr/lib/nagios/plugins/check_upstart_respawn_loop':
      ensure  => file,
      mode    => '0555',
      source  => "puppet:///modules/$module_name/check_upstart_respawn_loop",
      require => [Package['nagios-plugins-basic'], Package['python3-upstartwatch']],
    }

    sensu::check { 'upstart_respawn_loop':
      command      => '/usr/lib/nagios/plugins/check_upstart_respawn_loop',
      custom       => {
        'volatile' => true,
      },
      require      => File['/usr/lib/nagios/plugins/check_upstart_respawn_loop'],
    }

  }

  sensu::check  { 'check_zombie_procs':
    command => "/usr/lib/nagios/plugins/check_procs -w ${zombie_procs_warn_limit} -c ${zombie_procs_crit_limit} -s Z",
  }

  sensu::check  { 'check_total_procs':
    command => "/usr/lib/nagios/plugins/check_procs -w ${total_procs_warn_limit} -c ${total_procs_crit_limit}",
  }

  if $::virtual == 'openvz' {

    file { 'check_outgoing_ip':
      path   => "/usr/lib/nagios/plugins/check_outgoing_ip",
      mode   => '0555',
      source => "puppet:///modules/${module_name}/check_outgoing_ip",
    }

    sensu::check { 'check_outgoing_ip':
      command     => "/usr/lib/nagios/plugins/check_outgoing_ip",
    }

    file { 'check_oomkiller':
      path   => "/usr/lib/nagios/plugins/check_oomkiller",
      mode   => '0555',
      source => "puppet:///modules/${module_name}/check_oomkiller",
    }

    sensu::check { 'check_oomkiller':
      command => "/usr/lib/nagios/plugins/check_oomkiller",
    }

  }

}
