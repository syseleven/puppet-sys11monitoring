# Deploys sensu checks for an Openstack controller.
class sys11monitoring::profile::openstack_controller(
  $auth_url         = hiera('sys11stack::keystone::auth_url_public'),
  $admin_user       = hiera('keystone::roles::admin::admin'),
  $admin_password   = hiera('keystone::roles::admin::password'),
  $admin_tenant     = hiera('keystone::roles::admin::admin_tenant'),
  $monitoring       = hiera('sys11stack::monitoring', false),
) {

  case $monitoring {
    'sensu': {
      # Directory for common functions used by multiple checks.

      file{'/usr/lib/nagios/plugins/check_instance.d/':
        ensure  => directory,
        mode    => '0555',
        require => Package['nagios-plugins-basic'],
      }


      ### Common functions ###

      file{'/usr/lib/nagios/plugins/check_instance.d/boot_instance.sh':
        ensure  => file,
        mode    => '0444',
        source  => "puppet:///modules/$module_name/check_instance.d/boot_instance.sh",
        require => File['/usr/lib/nagios/plugins/check_instance.d/'],
      }



      ### Individual checks ###

      # Check for working Heat API

      file {'/usr/lib/nagios/plugins/check_heat_api':
        ensure  => file,
        mode    => '0555',
        source  => "puppet:///modules/$module_name/check_heat_api",
        require =>  Package['nagios-plugins-basic'],
      }

      file_line { 'sudo_check_heat_api':
        path    => '/etc/sudoers',
        line    => 'sensu ALL=(ALL) NOPASSWD: /usr/lib/nagios/plugins/check_heat_api',
        require => File['/usr/lib/nagios/plugins/check_heat_api'],
      }

      sensu::check { 'check_heat_api':
        command     => "PATH=\$PATH:/usr/lib/nagios/plugins/ check_nova_api --auth_url $auth_url --username $admin_user --password $admin_password --tenant $admin_tenant",
        require     => [ File['/usr/lib/nagios/plugins/check_heat_api'], File_line['sudo_check_heat_api' ] ],
        interval    => '120',
        occurrences => '2',
        timeout     => '30',
      }


      # Check for working instance boot (Indicates working Nova, Glance and Heat)

      file {'/usr/lib/nagios/plugins/check_instance_boot':
        ensure  => file,
        mode    => '0555',
        source  => "puppet:///modules/$module_name/check_instance_boot",
        require => [ Package['nagios-plugins-basic'], File['/usr/lib/nagios/plugins/check_instance.d/boot_instance.sh'] ],
      }

      file_line { 'sudo_check_instance_boot':
        path    => '/etc/sudoers',
        line    => 'sensu ALL=(ALL) NOPASSWD: /usr/lib/nagios/plugins/check_instance_boot',
        require => File['/usr/lib/nagios/plugins/check_instance_boot'],
      }


      sensu::check { 'check_instance_boot':
        command     => 'sudo /usr/lib/nagios/plugins/check_instance_boot',
        require     => [ File['/usr/lib/nagios/plugins/check_instance_boot'], File_line['sudo_check_instance_boot' ] ],
        interval    => '600',
        occurrences => '2',
        timeout     => '120',
      }
    }
    false: { }
    default: { fail("Only sensu monitoring supported ('$monitoring' given)") }
  }
}
