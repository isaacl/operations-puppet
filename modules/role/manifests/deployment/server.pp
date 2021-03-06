class role::deployment::server(
    $apache_fqdn = $::fqdn,
    $deployment_group = 'wikidev',
) {
    include standard

    # Can't include this while scap is present on the deployment server:
    # include misc::deployment::scripts
    include role::deployment::mediawiki

    # scap::server will ensure that all keyholder::agents and scap::sources
    # declared in hiera will exist.  scap::server is
    # for generic repository deployment and does not have
    # anything to do with Mediawiki.
    include scap::server

    class { 'deployment::deployment_server':
        deployment_group => $deployment_group,
    }

    # set umask for wikidev users so that newly-created files are g+w
    file { '/etc/profile.d/umask-wikidev.sh':
        ensure => present,
        owner  => 'root',
        group  => 'root',
        mode   => '0444',
        # NOTE: This file is also used in role::statistics
        source => 'puppet:///modules/role/deployment/umask-wikidev-profile-d.sh',
    }

    include ::apache
    # Install apache-fast-test
    include ::apache::helper_scripts
    include mysql

    include network::constants
    $deployable_networks = $::network::constants::deployable_networks

    if $::realm != 'labs' {
        include role::microsites::releases::upload
        # backup /home dirs on deployment servers
        include role::backup::host
        backup::set {'home': }
    }

    # Firewall rules
    ferm::service { 'rsyncd_scap_master':
        proto  => 'tcp',
        port   => '873',
        srange => '$MW_APPSERVER_NETWORKS',
    }


    $deployable_networks_ferm = join($deployable_networks, ' ')

    # T113351
    ferm::service { 'http_deployment_server':
        desc   => 'http on trebuchet deployment servers, for serving actual files to deploy',
        proto  => 'tcp',
        port   => '80',
        srange => "(${deployable_networks_ferm})",
    }

    ### End firewall rules

    #T83854
    ::monitoring::icinga::git_merge { 'mediawiki_config':
        dir           => '/srv/mediawiki-staging/',
        user          => 'root',
        remote        => 'readonly',
        remote_branch => 'master',
    }

    # Also make sure that no files have been stolen by root ;-)
    ::monitoring::icinga::bad_directory_owner { '/srv/mediawiki-staging': }

    ### Trebuchet
    file { '/srv/deployment':
        ensure => directory,
        owner  => 'trebuchet',
        group  => $deployment_group,
    }

    apache::site { 'deployment':
        content => template('role/deployment/apache-vhost.erb'),
        require => File['/srv/deployment'],
    }

    $deployment_server = hiera('deployment_server', 'tin.eqiad.wmnet')
    class { '::deployment::redis':
        deployment_server => $deployment_server
    }

    $deploy_ensure = $deployment_server ? {
        $::fqdn => 'absent',
        default => 'present'
    }

    class { '::deployment::rsync':
        deployment_server => $deployment_server,
        cron_ensure       => $deploy_ensure,
    }

    motd::script { 'inactive_warning':
        ensure   => $deploy_ensure,
        priority => 01,
        source   => 'puppet:///modules/role/deployment/inactive.motd',
    }

    # Bacula backups (T125527)
    backup::set { 'srv-deployment': }

    # Used by the trebuchet salt returner
    ferm::service { 'deployment-redis':
        proto  => 'tcp',
        port   => '6379',
        srange => "(${deployable_networks_ferm})",
    }

    sudo::group { "${deployment_group}_deployment_server":
        group      => $deployment_group,
        privileges => [
            'ALL = (root) NOPASSWD: /usr/bin/salt-call -l quiet --out=json pillar.data',
            'ALL = (root) NOPASSWD: /usr/bin/salt-call -l quiet publish.runner deploy.fetch *',
            'ALL = (root) NOPASSWD: /usr/bin/salt-call -l quiet publish.runner deploy.checkout *',
            'ALL = (root) NOPASSWD: /usr/bin/salt-call -l quiet --out=json publish.runner deploy.restart *',
        ],
    }
    ### End Trebuchet


    # tig is a ncurses-based git utility which is useful for
    # determining the state of git repos during deployments.

    require_package 'percona-toolkit', 'tig'

    # Bug T126262
    require_package 'php5-readline'
}
