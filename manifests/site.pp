# site.pp

import "realm.pp"	# These ones first
import "base.pp"

import "admins.pp"
import "ganglia.pp"
import "ntp.pp"
import "dns.pp"
import "imagescaler.pp"
import "jobrunner.pp"
import "search.pp"
import "squid.pp"
import "varnish.pp"
import "apaches.pp"
import "mediawiki.pp"
import "mysql.pp"
import "memcached.pp"
import "mobile.pp"
import "snapshots.pp"
import "ntp.pp"
import "nfs.pp"
import "lvs.pp"
import "exim.pp"
import "mailman.pp"
import "misc-servers.pp"
import "network.pp"
import "facilities.pp"
import "nrpe.pp"
import "nagios.pp"
import "backups.pp"
import "svn.pp"
import "ldap.pp"
import "iptables.pp"
import "owa.pp"
import "media-storage.pp"
import "certs.pp"
import "drac.pp"
import "openstack.pp"
import "protoproxy.pp"
import "puppetmaster.pp"
import "gerrit.pp"

# Include stages last
import "stages.pp"

# Initialization

$roles = [ ]

# Base nodes

# Class for *most* servers, standard includes
class standard {
	include base,
		ganglia,
		ntp::client,
		exim::simple-mail-sender
}


class applicationserver {
	class parent {
		$roles += [ 'appserver' ]
		$cluster = "appserver"
		$nagios_group = $cluster
	}

	class homeless inherits parent {
		$lvs_realserver_ips = $realm ? {
			'production' => [ "10.2.1.1" ],
			'labs' => [ "10.4.0.254" ],
		}

		include	base,
			ganglia,
			ntp::client,
			exim::simple-mail-sender,
			admins::roots,
			admins::mortals,
			accounts::l10nupdate,
			nfs::upload,
			mediawiki::packages,
			lvs::realserver,
			apaches::cron,
			apaches::service,
			apaches::pybal-check,
			apaches::monitoring,
			generic::geoip::files
	}

	class home-no-service inherits parent {
		include	base,
			ganglia,
			ntp::client,
			exim::simple-mail-sender,
			nfs::home,
			nfs::upload,
			mediawiki::packages,
			admins::roots,
			admins::mortals,
			accounts::l10nupdate,
			generic::geoip::files
	}

	class home inherits home-no-service {
		include apaches::service,
			apaches::pybal-check
	}

	class api inherits parent {
		$roles += [ 'appserver::api' ]
		$cluster = "api_appserver"
		$nagios_group = $cluster

		$lvs_realserver_ips = $realm ? {
			'production' => [ "10.2.1.22", "10.2.1.1" ],
			'labs' => [ "10.4.0.253" ],
		}

		include base,
			ganglia,
			ntp::client,
			exim::simple-mail-sender,
			admins::roots,
			admins::mortals,
			accounts::l10nupdate,
			nfs::upload,
			lvs::realserver,
			mediawiki::packages,
			apaches::cron,
			apaches::service,
			apaches::pybal-check,
			apaches::monitoring,
			generic::geoip::files
	}

	class bits inherits parent {
		$roles += [ 'appserver::bits' ]
		$cluster = "bits_appserver"
		$nagios_group = $cluster

		$lvs_realserver_ips = $realm ? {
			'production' => [ "10.2.1.1" ],
			'labs' => [ "10.4.0.252" ],
		}

		include standard,
			admins::roots,
			admins::mortals,
			accounts::l10nupdate,
			mediawiki::packages,
			lvs::realserver,
			apaches::cron,
			apaches::service,
			apaches::pybal-check,
			apaches::monitoring,
			generic::geoip::files
	}

	class jobrunner {
		$roles += [ 'appserver::jobrunner' ]

		include jobrunner::packages
	}

}

class imagescaler {
	$roles += [ 'imagescaler' ]
	$cluster = "imagescaler"
	$nagios_group = "image_scalers"
	
	$lvs_realserver_ips = $realm ? {
		'production' => [ "10.2.1.21" ],
		'labs' => [ "10.4.0.252" ],
	}

	include	base,
		imagescaler::cron,
		imagescaler::packages,
		imagescaler::files,
		nfs::upload,
		mediawiki::packages,
		lvs::realserver,
		apaches::packages,
		apaches::cron,
		apaches::service,
		ganglia,
		ntp::client,
		exim::simple-mail-sender,
		admins::roots,
		admins::mortals,
		admins::restricted,
		apaches::pybal-check,
		apaches::monitoring
}

class db {
	class core {
		$roles += [ 'db::core' ]
		$cluster = "mysql"

		system_role { "db::core": description => "Core Database server" }

		include base,
			ntp::client,
			ganglia,
			exim::simple-mail-sender,
			mysql
	}

	class es {
		$roles += [ 'db::es' ]
		$cluster = "mysql"
		$nagios_group = "es"

		system_role { "db::es": description => "External Storage server (${mysql_role})" }

		include	base,
			ntp::client,
			ganglia,
			exim::simple-mail-sender,
			mysql,
			mysql::mysqluser,
			mysql::datadirs,
			mysql::conf,
			mysql::mysqlpath,
			nrpe

		# Nagios monitoring
		monitor_service {
			"mysql status":
				description => "MySQL ${mysql_role} status",
				check_command => "check_mysqlstatus!--${mysql_role}";
			"mysql replication":
				description => "MySQL replication status",
				check_command => "check_db_lag",
				ensure => $mysql_role ? {
					"master" => absent,
					"slave" => present
				};
		}

		class master {
			$mysql_role = "master"

			include db::es
		}

		class slave {
			$mysql_role = "slave"

			include db::es
		}
	}
}

class searchserver {
	$roles += [ 'search' ]
	$cluster = "search"
	$nagios_group = "lucene"

	$lvs_realserver_ips = [ "10.2.1.11", "10.2.1.12", "10.2.1.13" ]

	include	base,
		ntp::client,
		ganglia,
		nfs::home,
		exim::simple-mail-sender,
		admins::roots,
		admins::mortals,
		admins::restricted,
		search::sudo,
		search::jvm,
		search::monitoring,
		lvs::realserver
}

class searchindexer {
	$roles += [ 'search::indexer' ]
	$cluster = "search"
	$nagios_group = "lucene"

	$search_indexer = "true"

	include	base,
		ntp::client,
		ganglia,
		exim::simple-mail-sender,
		admins::roots,
		admins::mortals,
		admins::restricted,
		search::sudo,
		search::jvm,
		search::php,
		search::monitoring,
		search::indexer
}

class text-squid {
	$roles += [ 'cache::text' ]
	if $cluster == "misc" {
		$cluster = "squids_text"
	}

	if ! $lvs_realserver_ips {
		$lvs_realserver_ips = $realm ? {
			'production' => $site ? {
			 	'pmtpa' => [ "208.80.152.2", "208.80.152.200", "208.80.152.201", "208.80.152.202", "208.80.152.203", "208.80.152.204", "208.80.152.205", "208.80.152.206", "208.80.152.207", "208.80.152.208", "208.80.152.209", "10.2.1.25" ],
				'eqiad' => [ "" ],
				'esams' => [ "91.198.174.232", "91.198.174.233", "91.198.174.224", "91.198.174.225", "91.198.174.226", "91.198.174.227", "91.198.174.228", "91.198.174.229", "91.198.174.230", "91.198.174.231", "91.198.174.235", "10.2.3.25" ]
			},
			# TODO: add text svc address
			'labs' => $site ? {
			 	'pmtpa' => [ "208.80.153.193", "208.80.153.197", "208.80.153.198", "208.80.153.199", "208.80.153.200", "208.80.153.201", "208.80.153.202", "208.80.153.203", "208.80.153.204", "208.80.153.205" ],
				'eqiad' => [ "" ],
				'esams' => [ "" ]
			}
		}
	}

	system_role { text-squid: description => "text Squid server" }

	$nagios_group = $site ? {
		'pmtpa' => 'squids_text',
		'esams' => 'squids_esams_text'
	}

	include	base,
		squid,
		lvs::realserver,
		ntp::client,
		ganglia,
		exim::simple-mail-sender

	# HTCP packet loss monitoring on the ganglia aggregators
	if $ganglia_aggregator == "true" and $site != "esams" {
		include misc::monitoring::htcp-loss
	}
}

class upload-squid {
	$roles += [ 'cache::upload' ]
	if $cluster == "misc" {
		$cluster = "squids_upload"
	}

	if ! $lvs_realserver_ips {
		$lvs_realserver_ips = $site ? { 
			'pmtpa' => [ "208.80.152.211", "10.2.1.24" ],
			'eqiad' => [ "" ],
			'esams' => [ "91.198.174.234", "10.2.3.24" ],
		}
	}

	system_role { upload-squid: description => "upload Squid server" }

	$nagios_group = $site ? {
		'pmtpa' => 'squids_upload',
		'esams' => 'squids_esams_upload'
	}

	include base,
		squid,
		lvs::realserver,
		ntp::client,
		ganglia,
		exim::simple-mail-sender

	# HTCP packet loss monitoring on the ganglia aggregators
	if $ganglia_aggregator == "true" and $site != "esams" {
		include misc::monitoring::htcp-loss
	}
}

class cache {
	class bits {
		$roles += [ 'cache::bits' ]
		$cluster = "cache_bits_${site}"
		$nagios_group = "cache_bits_${site}"

		$lvs_realserver_ips = $site ? {
			"pmtpa" => [ "208.80.152.210", "10.2.1.23" ],
			"eqiad" => [ "208.80.154.234", "10.2.4.23" ],
			"esams" => [ "91.198.174.233", "10.2.3.23" ],
		}

		if $site == "esams" and $hostname =~ /^cp/ {
			$bits_appservers = [ "srv191.pmtpa.wmnet", "srv192.pmtpa.wmnet", "srv248.pmtpa.wmnet", "srv249.pmtpa.wmnet", "mw60.pmtpa.wmnet", "mw61.pmtpa.wmnet" ]
			$test_wikipedia = [ "srv193.pmtpa.wmnet" ]
			$all_backends = [ "srv191.pmtpa.wmnet", "srv192.pmtpa.wmnet", "srv248.pmtpa.wmnet", "srv249.pmtpa.wmnet", "mw60.pmtpa.wmnet", "mw61.pmtpa.wmnet", "srv193.pmtpa.wmnet" ]

			# FIXME: add eqiad as backend for esams
			$varnish_backends = $site ? {
				/^(pmtpa|eqiad)$/ => $all_backends,
				'esams' => [ "bits.pmtpa.wikimedia.org" ],
				default => []
			}
			$varnish_directors = $site ? {
				/^(pmtpa|eqiad)$/ => {
					"backend" => $bits_appservers,
					"test_wikipedia" => $test_wikipedia
					},
				'esams' => {
					"backend" => $varnish_backends
					}
			}
		}
		else {
            if $site == "pmtpa" {
                    $varnish_backends = [ "srv191.pmtpa.wmnet", "srv192.pmtpa.wmnet", "srv248.pmtpa.wmnet", "srv249.pmtpa.wmnet", "mw60.pmtpa.wmnet", "mw61.pmtpa.wmnet" ]
                    $varnish_directors = { "appservers" => $varnish_backends }
            }
		}

		$varnish_xff_sources = [ { "ip" => "208.80.152.0", "mask" => "22" }, { "ip" => "91.198.174.0", "mask" => "24" } ]

		system_role { "cache::bits": description => "bits Varnish cache server" }

		require generic::geoip::files

		include standard,
			lvs::realserver
		
		if $site == "esams" and $hostname =~ /^cp/ {
			include varnish3::monitoring::ganglia
			
			varnish3::instance { "bits":
				name => "",
				vcl => "bits",
				port => 80,
				admin_port => 6082,
				storage => "-s malloc,1G",
				backends => $varnish_backends,
				directors => $varnish_directors,
				backend_options => {
					'port' => 80,
					'connect_timeout' => "5s",
					'first_byte_timeout' => "35s",
					'between_bytes_timeout' => "4s",
					'max_connections' => 10000,
					'probe' => "bits"
				},
				enable_geoiplookup => "true"
			}
		}
		else {
			# Old configuration
			include varnish
		}
	}
	class mobile { 
		$roles += [ 'cache::mobile' ]
		$cluster = "cache_mobile_${site}"
		$nagios_group = "cache_mobile_${site}"

		$lvs_realserver_ips = $site ? {
			'eqiad' => [ "208.80.154.236" ],
			default => [ ]
		}

		$varnish_fe_backends = $site ? {
			"eqiad" => [ "cp1043.wikimedia.org", "cp1044.wikimedia.org" ],
			default => []
		}
		$varnish_fe_directors = $site ? {
			"eqiad" => { "backend" => $varnish_fe_backends },
			default => {}
		}

		$varnish_xff_sources = [ { "ip" => "208.80.152.0", "mask" => "22" } ]

		system_role { "cache::mobile": description => "mobile Varnish cache server" }

		include standard,
			varnish3::htcpd,
			varnish3::monitoring::ganglia,
			lvs::realserver
		
		varnish3::instance { "mobile-backend":
			name => "",
			vcl => "mobile-backend",
			port => 81,
			admin_port => 6083,
			storage => "-s file,/a/sda/varnish.persist,50% -s file,/a/sdb/varnish.persist,50%",
			backends => [ "10.2.1.1" ],
			directors => { "backend" => [ "10.2.1.1" ] },
			backend_options => {
				'port' => 80,
				'connect_timeout' => "5s",
				'first_byte_timeout' => "35s",
				'between_bytes_timeout' => "4s",
				'max_connections' => 1000,
				'probe' => "bits"
				},
		}
		
		varnish3::instance { "mobile-frontend":
			name => "frontend",
			vcl => "mobile-frontend",
			port => 80,
			admin_port => 6082,
			backends => $varnish_fe_backends,
			directors => $varnish_fe_directors,
			backend_options => {
				'port' => 81,
				'connect_timeout' => "5s",
				'first_byte_timeout' => "35s",
				'between_bytes_timeout' => "2s",
				'max_connections' => 100000,
				'probe' => "bits"
				},
		}
	}
}

# Default variables
$cluster = "misc"

# FIXME: move to realm.pp
# FIXME: check if this is still correct, this was temp for a migration
$dns_auth_master = "ns1.wikimedia.org"

# Node definitions (alphabetic order)

node "alsted.wikimedia.org" {

	include base,
		admins::roots
}

node /amslvs[1-4]\.esams\.wikimedia\.org/ {
	$cluster = "misc_esams"

	$lvs_balancer_ips = [ "91.198.174.232", "91.198.174.233", "91.198.174.234", "91.198.174.224", "91.198.174.225", "91.198.174.226", "91.198.174.227", "91.198.174.228", "91.198.174.229", "91.198.174.230", "91.198.174.231", "91.198.174.235", "10.2.3.23", "10.2.3.24", "10.2.3.25" ]

	# PyBal is very dependent on recursive DNS, to the point where it is a SPOF
	# So we'll have every LVS server run their own recursor
	$nameservers = [ $ipaddress, "91.198.174.6", "208.80.152.131" ]
	$dns_recursor_ipaddress = $ipaddress

	include base,
		ganglia,
		dns::recursor,
		lvs::balancer
}

# amssq31-46 are text squids
node /amssq(3[1-9]|4[0-6])\.esams\.wikimedia\.org/ {
	$cluster = "squids_esams_t"
	$squid_coss_disks = [ 'sda5', 'sdb5' ]
	if $hostname =~ /^amssq3[12]$/ {
		$ganglia_aggregator = "true"
	}

	include text-squid,
		lvs::realserver
}

node /amssq(4[7-9]|5[0-9]|6[0-2])\.esams\.wikimedia\.org/ {
	$cluster = "squids_esams_u"
	$squid_coss_disks = [ 'sdb5' ]

	include upload-squid
}

node "argon.wikimedia.org" {
	$cluster = "misc"
	include base,
		ganglia,
		certificates::star_wikimedia_org,
		ntp::client,
		misc::survey

	install_certificate{ "star.wikimedia.org": }
	monitor_service { "secure cert": description => "Certificate expiration", check_command => "check_cert!secure.wikimedia.org!443!Equifax_Secure_CA.pem", critical => "true" }
}

node /(arsenic|niobium)\.wikimedia\.org/ {
	$ganglia_aggregator = "true"
	
	include standard
}

node "bayes.wikimedia.org" {
	include base,
		ganglia,
		ntp::client,
		exim::simple-mail-sender,
		admins::roots,
		accounts::ezachte,
		accounts::reedy,
		accounts::nimishg,
		accounts::diederik
}

node "brewster.wikimedia.org" {
	include base,
		ganglia,
		ntp::client,
		misc::install-server,
		exim::simple-mail-sender,
		backup::client
}

node "carbon.wikimedia.org" {
	include base,
		ganglia,
		ntp::client,
		exim::simple-mail-sender,
		backup::client,
		misc::install-server::tftp-server
}

node /^cp300[12]\.esams\.wikimedia\.org$/ {
	$ganglia_aggregator = "true"
	
	include cache::bits
}

node "ekrem.wikimedia.org" {
	install_certificate{ "star.wikimedia.org": }
	include base,
		ganglia,
		ntp::client,
		exim::simple-mail-sender,
		misc::wapsite,
		misc::apple-dictionary-bridge,
		misc::irc-server,
		misc::mediawiki-irc-relay
}

node "emery.wikimedia.org" {
	$gid=500
	system_role { "misc::log-collector": description => "log collector" }
	sudo_user { nimishg: user => "nimishg", privileges => ['ALL = NOPASSWD: ALL'] }
	include base,
		ganglia,
		exim::simple-mail-sender,
		ntp::client,
		misc::udp2log::aft,
		groups::wikidev,
		admins::mortals,
		admins::restricted,
		nrpe
}

node "erzurumi.pmtpa.wmnet" {
	include	base,
		ganglia,
		ntp::client,
		exim::simple-mail-sender,
		groups::wikidev,
		accounts::awjrichards,
		accounts::tfinc
}

node /es100[1-4]\.eqiad\.wmnet/ {
	if $hostname == "es1001" {
		include db::es::master
	}
	else {
		include db::es::slave
	}
	if $hostname == "es1004" {
		# replica of ms3 - currently used for backups
		cron { snapshot_mysql: command => "/root/backup.sh", user => root, minute => 15, hour => 4 }
	}
}

node "dataset1.wikimedia.org" {
	$cluster = "misc"
	$gid=500
	include base,
		ganglia,
		ntp::client,
		exim::simple-mail-sender,
		admins::roots,
		misc::download-wikimedia

}

node "dataset2.wikimedia.org" {
	$cluster = "misc"
	$gid=500
	include base,
		ganglia,
		ntp::client,
		exim::simple-mail-sender,
		admins::roots,
		groups::wikidev,
		accounts::catrope,
		misc::download-wikimedia,
		misc::download-mirror,
		misc::kiwix-mirror
}

node "db1.pmtpa.wmnet" {
	include db::core
}

node "db2.pmtpa.wmnet" {
	include db::core
}

node "db3.pmtpa.wmnet" {
	include db::core
}

node "db4.pmtpa.wmnet" {
	include db::core
}

node "db5.pmtpa.wmnet" {
	include db::core
}

node "db7.pmtpa.wmnet" {
	include db::core
}

node "db8.pmtpa.wmnet" {
	include db::core
}

node "db9.pmtpa.wmnet" {
	include db::core
}

node "db10.pmtpa.wmnet" {
	include db::core, 
		backup::mysql
}

node "db11.pmtpa.wmnet" {
	include db::core
}

node "db12.pmtpa.wmnet" {
	include db::core
}

node "db13.pmtpa.wmnet" {
	include db::core
}

node "db14.pmtpa.wmnet" {
	include db::core
}

node "db15.pmtpa.wmnet" {
	include db::core
}

node "db16.pmtpa.wmnet" {
	include db::core
}

node "db17.pmtpa.wmnet" {
	include db::core
}

node "db18.pmtpa.wmnet" {
	include db::core
}

node "db19.pmtpa.wmnet" {
	include db::core
}

node "db20.pmtpa.wmnet" {
	$ganglia_aggregator = "true"

	include db::core
}

node "db21.pmtpa.wmnet" {
	include db::core
}

node "db22.pmtpa.wmnet" {
	include db::core
}

node "db23.pmtpa.wmnet" {
	include db::core
}

node "db24.pmtpa.wmnet" {
	include db::core
}

node "db25.pmtpa.wmnet" {
	include db::core
}

node "db26.pmtpa.wmnet" {
	include db::core
}

node "db27.pmtpa.wmnet" {
	include db::core
}

node "db28.pmtpa.wmnet" {
	include db::core
}

node "db29.pmtpa.wmnet" {
	include db::core
}

node "db30.pmtpa.wmnet" {
	$ganglia_aggregator = "true"

	include db::core
}

node "db31.pmtpa.wmnet" {
	include db::core
}

node "db32.pmtpa.wmnet" {
	include db::core
}

node "db33.pmtpa.wmnet" {
	include db::core
}

node "db34.pmtpa.wmnet" {
	include db::core
}

node "db35.pmtpa.wmnet" {
	include db::core
}

node "db36.pmtpa.wmnet" {
	include db::core
}

node "db37.pmtpa.wmnet" {
	include db::core
}

node "db38.pmtpa.wmnet" {
	include db::core
}

node "db39.pmtpa.wmnet" {
	include db::core
}

node "db40.pmtpa.wmnet" {
	include db::core
}

node "db41.pmtpa.wmnet" {
	$cluster = "misc"
	$gid=500
	sudo_user { nimishg: user => "nimishg", privileges => ['ALL = NOPASSWD: ALL'] }
	include base,
		ganglia,
		ntp::client,
		memcached,
		owa::database,
		groups::wikidev,
		accounts::nimishg
}

node "db42.pmtpa.wmnet" {
	include db::core
}

node "db43.pmtpa.wmnet" {
	include db::core
}

# new pmtpa dbs
node /db4[4-7]\.pmtpa\.wmnet/ { 
	if $hostname =~ /^db(44|45)$/ { 
		$db_cluster = "s5"
	}

	if $hostname =~ /^db(46|47)$/ { 
		$db_cluster = "s6"
	}

	include db::core,
		mysql::mysqluser,
		mysql::datadirs,
		mysql::conf
}

# eqiad dbs
node /db10[0-9][0-9]\.eqiad\.wmnet/ {
	if $hostname =~ /^db(1001|1017)$/ {
		$ganglia_aggregator = "true"
	}

	if $hostname =~ /^db(1001|1017|1033|1047)$/ {
		$db_cluster = "s1"
	}

	if $hostname =~ /^db(1047)$/ {
		$research_dbs = true
	}

	if $hostname =~ /^db(1002|1018|1034)$/ {
		$db_cluster = "s2"
	}

	if $hostname =~ /^db(1003|1019|1035)$/ {
		$db_cluster = "s3"
	}

	if $hostname =~ /^db(1004|1020|1038)$/ {
		$db_cluster = "s4"
	}

	if $hostname =~ /^db(1005|1021|1039)$/ {
		$db_cluster = "s5"
	}

	if $hostname =~ /^db(1006|1022|1040)$/ {
		$db_cluster = "s6"
	}

	if $hostname =~ /^db(1007|1024|1041)$/ {
		$db_cluster = "s7"
	}

	if $hostname =~ /^(db1008|db1025)$/ {
		$db_cluster = "fundraisingdb"
		if $hostname == "db1008" { # db1008 is a middle-master
			$writable = "true"
		}
	}

	if $hostname =~ /^(db1042|db1048)$/ {
		$db_cluster = "otrsdb"
	}

	# Here Be Masters
	if $hostname =~ /^db(1047)$/ {
		$writable = "true"
	} 

	include db::core,
		mysql::mysqluser,
		mysql::datadirs,
		mysql::conf
}

node "dobson.wikimedia.org" {
	$ntp_servers = [ "173.9.142.98", "66.250.45.2", "169.229.70.201", "69.31.13.207", "72.167.54.201" ]
	$ntp_peers = [ "linne.wikimedia.org" ]

	$dns_recursor_ipaddress = "208.80.152.131"

	interface_ip { "dns::auth-server": interface => "eth0", address => "208.80.152.130" }
	interface_ip { "dns::recursor": interface => "eth0", address => $dns_recursor_ipaddress }

	include	base,
		ganglia,
		ntp::server,
		dns::recursor,
		dns::recursor::monitoring,
		dns::recursor::statistics,
		exim::simple-mail-sender

	class { "dns::auth-server":
		ipaddress => "208.80.152.130",
		soa_name => "ns0.wikimedia.org",
		master => $dns_auth_master
	}
}

node "fenari.wikimedia.org" {
	$cluster = "misc"
	$domain_search = "wikimedia.org pmtpa.wmnet eqiad.wmnet esams.wikimedia.org"

	include base,
		ganglia,
		svn::client,
		ntp::client,
		nfs::home,
		admins::roots,
		admins::mortals,
		admins::restricted,
		accounts::l10nupdate,
		misc::bastionhost,
		misc::noc-wikimedia,
		misc::extension-distributor,
		misc::scripts,
		misc::l10nupdate,
		dns::account,
		exim::simple-mail-sender,
		nrpe,
		drac::management,
		squid::cachemgr,
		accounts::awjrichards,
		mediawiki::packages

	apache_module { php5: name => "php5" }
}

node "formey.wikimedia.org" {
	install_certificate{ "star.wikimedia.org": }

	sudo_user { demon: user => "demon", privileges => ['ALL = NOPASSWD: /usr/local/sbin/add-ldap-user', 'ALL = NOPASSWD: /usr/local/sbin/delete-ldap-user', 'ALL = NOPASSWD: /usr/local/sbin/modify-ldap-user'] }
	sudo_user { robla: user => "robla", privileges => ['ALL = NOPASSWD: /usr/local/sbin/add-ldap-user', 'ALL = NOPASSWD: /usr/local/sbin/delete-ldap-user', 'ALL = NOPASSWD: /usr/local/sbin/modify-ldap-user'] }
	sudo_user { pdhanda: user => "pdhanda", privileges => ['ALL = NOPASSWD: /usr/local/sbin/add-ldap-user', 'ALL = NOPASSWD: /usr/local/sbin/delete-ldap-user', 'ALL = NOPASSWD: /usr/local/sbin/modify-ldap-user'] }
	sudo_user { sumanah: user => "sumanah", privileges => ['ALL = NOPASSWD: /usr/local/sbin/add-ldap-user', 'ALL = NOPASSWD: /usr/local/sbin/delete-ldap-user', 'ALL = NOPASSWD: /usr/local/sbin/modify-ldap-user','ALL = NOPASSWD: /usr/local/bin/svn-group'] }
	$cluster = "misc"
	$gid = 550
	$ldapincludes = ['openldap', 'nss', 'utils']
	$ssh_tcp_forwarding = "no"
	$ssh_x11_forwarding = "no"
	include base,
		ganglia,
		ntp::client,
		exim::simple-mail-sender,
		svn::server,
		ldap::client::wmf-cluster,
		backup::client,
		gerrit::proxy,
		gerrit::jetty,
		gerrit::ircbot,
		accounts::sumanah
}


node "gallium.wikimedia.org" {
	$cluster = "misc"
	$gid=500
	sudo_user { demon: user => "demon", privileges => ['ALL = (jenkins) NOPASSWD: ALL', 'ALL = NOPASSWD: /etc/init.d/jenkins'] }
	sudo_user { hashar: user => "hashar", privileges => ['ALL = (jenkins) NOPASSWD: ALL', 'ALL = NOPASSWD: /etc/init.d/jenkins'] }
	sudo_user { reedy: user => "reedy", privileges => ['ALL = (jenkins) NOPASSWD: ALL', 'ALL = NOPASSWD: /etc/init.d/jenkins'] }
	include base,
		ganglia,
		ntp::client,
		misc::contint::test,
		admins::roots,
		accounts::demon,
		accounts::hashar,
		accounts::reedy
}

node "gilman.wikimedia.org" {

	install_certificate{ "star.wikimedia.org": }

	sudo_user { awjrichards: user => "awjrichards", privileges => ['ALL = NOPASSWD: ALL'] }
	sudo_user { rfaulk: user => "rfaulk", privileges => ['ALL = NOPASSWD: ALL'] }
	sudo_user { nimishg: user => "nimishg", privileges => ['ALL = NOPASSWD: ALL'] }

	$cluster = "misc"
	$gid = 500
	include	base,
		ntp::client,
		nrpe,
		admins::roots,
		accounts::rfaulk,
		accounts::nimishg,
		accounts::awjrichards,
		misc::jenkins,
		misc::fundraising
}

node /(grosley|aluminium)\.wikimedia\.org/ {

	install_certificate{ "star.wikimedia.org": }

	sudo_user { awjrichards: user => "awjrichards", privileges => ['ALL = NOPASSWD: ALL'] }
	sudo_user { rfaulk: user => "rfaulk", privileges => ['ALL = NOPASSWD: ALL'] }
	sudo_user { nimishg: user => "nimishg", privileges => ['ALL = NOPASSWD: ALL'] }

	$cluster = "misc"
	$gid = 500
	include	base,
		ntp::client,
		nrpe,
		admins::roots,
		accounts::rfaulk,
		accounts::nimishg,
		accounts::zexley,
		accounts::khorn,
		accounts::awjrichards,
		accounts::kaldari,
		accounts::jpostlethwaite,
		accounts::jamesofur,
		accounts::pgehres,
		misc::jenkins,
		backup::client,
		misc::fundraising

}

node "gurvin.wikimedia.org" {
	include base,
		ganglia,
		ntp::client,
		certificates::wmf_ca
}

node "hooft.esams.wikimedia.org" {
	$cluster = "misc_esams"
	$ganglia_aggregator = "true"

	include base,
		ganglia,
		ntp::client,
		misc::install-server::tftp-server,
		admins::roots,
		admins::mortals,
		admins::restricted,
		ganglia::collector
}

node "hooper.wikimedia.org" {
	include base,
		ganglia,
		ntp::client,
		exim::simple-mail-sender,
		admins::roots,
		svn::client,
		misc::etherpad,
		misc::blog-wikimedia,
		certificates::star_wikimedia_org

	install_certificate{ "star.wikimedia.org": }
}

node "hume.wikimedia.org" {
	$cluster = "misc"

	include base,
		ganglia,
		ntp::client,
		nfs::home,
		misc::scripts,
		exim::simple-mail-sender,
		admins::roots,
		admins::mortals,
		admins::restricted,
		nrpe
}

node "ixia.pmtpa.wmnet" {
	$ganglia_aggregator = "true"
	include db::core
}

node "kaulen.wikimedia.org" {
	system_role { "misc": description => "Bugzilla server" }
	$ldapincludes = ['openldap', 'nss', 'utils']
	$gid = 500

	include base,
		ganglia,
		ntp::client,
		exim::simple-mail-sender,
		admins::roots,
		accounts::demon,
		accounts::reedy,
		ldap::client::wmf-cluster,
		misc::download-mediawiki,
		certificates::star_wikimedia_org

	install_certificate{ "star.wikimedia.org": }
	cron { bugzilla_whine: command => "cd /srv/org/wikimedia/bugzilla/ ; ./whine.pl", user => root, minute => 15 }
	monitor_service { "http": description => "Apache HTTP", check_command => "check_http" }
}

# knsq1-7 are Varnish bits servers, 5 has been decommissioned
node /knsq([1-7])\.esams\.wikimedia\.org/ {
	if $hostname =~ /^knsq[4]$/ {
		$ganglia_aggregator = "true"
	}

	include cache::bits
}

# knsq8-22 are upload squids, 13 and 14 have been decommissioned
 node /knsq([8-9]|1[0-9]|2[0-2])\.esams\.wikimedia\.org/ {
	$cluster = "squids_esams_u"
	$squid_coss_disks = [ 'sdb5', 'sdc', 'sdd' ]
	if $hostname =~ /^knsq[89]$/ {
		$ganglia_aggregator = "true"
	}

	include upload-squid
}

# knsq23-30 are text squids
 node /knsq(2[3-9]|30)\.esams\.wikimedia\.org/ {
	$cluster = "squids_esams_t"
	$squid_coss_disks = [ 'sda5', 'sdb5', 'sdc', 'sdd' ]
	
	include text-squid
}

node "linne.wikimedia.org" {
	$ntp_servers = [ "198.186.191.229", "64.113.32.2", "173.8.198.242", "208.75.88.4", "75.144.70.35" ]
	$ntp_peers = [ "dobson.wikimedia.org" ]

	interface_ip { "dns::auth-server": interface => "eth0", address => "208.80.152.142" }
	interface_ip { "misc::url-downloader": interface => "eth0", address => "208.80.152.143" }

	include base,
		ganglia,
		exim::simple-mail-sender,
		ntp::server,
		misc::url-downloader,
		misc::squid-logging::multicast-relay

		class { "dns::auth-server":
			ipaddress => "208.80.152.142",
			soa_name => "ns1.wikimedia.org",
			master => $dns_auth_master
		}
}
# Why would Locke be getting apaches::files for the sudoers... that is just silly...
# removing apaches::files.
node "locke.wikimedia.org" {
	$gid=500
	system_role { "misc::log-collector": description => "log collector" }
	sudo_user { awjrichards: user => "awjrichards", privileges => ['ALL = NOPASSWD: ALL'] }
	include base,
		ganglia,
		exim::simple-mail-sender,
		ntp::client,
		groups::wikidev,
		admins::restricted,
		accounts::awjrichards,
		nrpe
}

node "lomaria.pmtpa.wmnet" {
	include db::core
}

node /lvs[1-6]\.wikimedia\.org/ {
	$cluster = "misc"

	# PyBal is very dependent on recursive DNS, to the point where it is a SPOF
	# So we'll have every LVS server run their own recursor
	$nameservers = [ $ipaddress, "208.80.152.131", "208.80.152.132" ]
	$dns_recursor_ipaddress = $ipaddress

	if $hostname =~ /^lvs[1256]$/ {
		$lvs_balancer_ips = [ "208.80.152.200", "208.80.152.201", "208.80.152.202", "208.80.152.203", "208.80.152.204", "208.80.152.205", "208.80.152.206", "208.80.152.207", "208.80.152.208", "208.80.152.209", "208.80.152.210", "208.80.152.211", "208.80.152.212", "208.80.152.213", "10.2.1.23", "10.2.1.24", "10.2.1.25" ]
	}
	if $hostname =~ /^lvs[34]$/ {
		$lvs_balancer_ips = [ "10.2.1.1", "10.2.1.11", "10.2.1.12", "10.2.1.13", "10.2.1.21", "10.2.1.22" ]
	}

	include base,
		ganglia,
		dns::recursor,
		lvs::balancer,
		lvs::balancer::runcommand

	if $hostname == "lvs1" {
		interface_ip { "owa": interface => "eth0", address => "208.80.152.6" }
		interface_ip { "payments": interface => "eth0", address => "208.80.152.7" }
	} 
	if $hostname == "lvs2" {
		interface_ip { "text": interface => "eth0", address => "208.80.152.2" }
	}

	$ips = {
		'internal' => {
			'lvs1' => "10.0.0.11",
			'lvs2' => "10.0.0.12",
			'lvs3' => "10.0.0.13",
			'lvs4' => "10.0.0.14",
			'lvs5' => "10.0.0.15",
			'lvs6' => "10.0.0.16",
		},
	}

	# Set up tagged interfaces to all subnets with real servers in them
	interface_tagged { "eth0.2":
		base_interface => "eth0",
		vlan_id => "2",
		address => $ips["internal"][$hostname],
		netmask => "255.255.0.0"
	}
	
	# Make sure GRO is off
	interface_setting { "eth0 gro": interface => "eth0", setting => "offload-gro", value => "off" }

	# LVS configuration moved to lvs.pp
}

node /lvs100[1-6]\.wikimedia\.org/ {
	$cluster = "misc"

	# PyBal is very dependent on recursive DNS, to the point where it is a SPOF
	# So we'll have every LVS server run their own recursor
	$nameservers = [ $ipaddress, "208.80.152.131", "208.80.152.132" ]
	$dns_recursor_ipaddress = $ipaddress

	if $hostname =~ /^lvs100[14]$/ {
		$lvs_balancer_ips = [ "208.80.154.224", "208.80.154.225", "208.80.154.226", "208.80.154.227", "208.80.154.228", "208.80.154.229", "208.80.154.230", "208.80.154.231", "208.80.154.232", "208.80.154.233", "208.80.154.234", "208.80.154.236", "208.80.154.237" ]
	}

	if $hostname =~ /^lvs100[2356]$/ {
		$lvs_balancer_ips = [ "" ]
	}

	include base,
		ganglia,
		dns::recursor,
		lvs::balancer,
		lvs::balancer::runcommand

	$ips = {
		'public1-a-eqiad' => {
			'lvs1004' => "208.80.154.58",
			'lvs1005' => "208.80.154.59",
			'lvs1006' => "208.80.154.60",
		},
		'public1-b-eqiad' => {
			'lvs1001' => "208.80.154.140",
			'lvs1002' => "208.80.154.141",
			'lvs1003' => "208.80.154.142",
		},
		'private1-a-eqiad' => {
			'lvs1001' => "10.64.1.1",
			'lvs1002' => "10.64.1.2",
			'lvs1003' => "10.64.1.3",
			'lvs1004' => "10.64.1.4",
			'lvs1005' => "10.64.1.5",
			'lvs1006' => "10.64.1.6",
		},
		'private1-b-eqiad' => {
			'lvs1001' => "10.64.17.1",
			'lvs1002' => "10.64.17.2",
			'lvs1003' => "10.64.17.3",
			'lvs1004' => "10.64.17.4",
			'lvs1005' => "10.64.17.5",
			'lvs1006' => "10.64.17.6",
		}
	}

	# Set up tagged interfaces to all subnets with real servers in them
	case $hostname {
		/^lvs100[1-3]$/: {
			# Row A subnets on eth0
			interface_tagged { "eth0.1017":
				base_interface => "eth0",
				vlan_id => "1017",
				address => $ips["private1-a-eqiad"][$hostname],
				netmask => "255.255.252.0"
			}
			# Row B subnets on eth1
			interface_tagged { "eth1.1002":
				base_interface => "eth1",
				vlan_id => "1002",
				address => $ips["public1-b-eqiad"][$hostname],
				netmask => "255.255.255.192"
			}
			interface_tagged { "eth1.1018":
				base_interface => "eth1",
				vlan_id => "1018",
				address => $ips["private1-b-eqiad"][$hostname],
				netmask => "255.255.252.0"
			}
			# Row C subnets on eth2
			# Row D subnets on eth3
		}
		/^lvs100[4-6]$/: {
			# Row B subnets on eth0
			interface_tagged { "eth0.1018":
				base_interface => "eth0",
				vlan_id => "1018",
				address => $ips["private1-b-eqiad"][$hostname],
				netmask => "255.255.252.0"
			}
			# Row A subnets on eth1
			interface_tagged { "eth1.1001":
				base_interface => "eth1",
				vlan_id => "1001",
				address => $ips["public1-a-eqiad"][$hostname],
				netmask => "255.255.255.192"
			}
			interface_tagged { "eth1.1017":
				base_interface => "eth1",
				vlan_id => "1017",
				address => $ips["private1-a-eqiad"][$hostname],
				netmask => "255.255.252.0"
			}
			# Row C subnets on eth2
			# Row D subnets on eth3
		}
	}

	# Make sure GRO is off
	interface_manual { "eth1": interface => "eth1", before => Interface_setting["eth1 gro"] }
	interface_manual { "eth2": interface => "eth2", before => Interface_setting["eth2 gro"] }
	interface_manual { "eth3": interface => "eth3", before => Interface_setting["eth3 gro"] }

	interface_setting { "eth0 gro": interface => "eth0", setting => "offload-gro", value => "off" }
	interface_setting { "eth1 gro": interface => "eth1", setting => "offload-gro", value => "off" }
	interface_setting { "eth2 gro": interface => "eth2", setting => "offload-gro", value => "off" }
	interface_setting { "eth3 gro": interface => "eth3", setting => "offload-gro", value => "off" }
}

node "maerlant.esams.wikimedia.org" {
	$gid = 500

	$enable_ipv6_proxy = "true"
	$cluster = "ssl_esams"
	$ganglia_aggregator = "true"

	include base,
		ganglia,
		ntp::client,
		protoproxy::proxy_sites,
		protoproxy::ipv6_labs,
		certificates::wmf_ca,
		groups::wikidev,
		accounts::gmaxwell
}

node "mchenry.wikimedia.org" {
	$gid = 500
	$ldapincludes = ['openldap']

	$dns_recursor_ipaddress = "208.80.152.132"

	interface_ip { "dns::recursor": interface => "eth0", address => $dns_recursor_ipaddress }

	include base,
		ganglia,
		ntp::client,
		dns::recursor,
		dns::recursor::monitoring,
		dns::recursor::statistics,
		nrpe,
		ldap::client::corp-server,
		backup::client,
		groups::wikidev,
		accounts::jdavis
}

node /mw[1-5]?[0-9]\.pmtpa\.wmnet/ {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node /mw6[0-1]\.pmtpa\.wmnet/ {
	include applicationserver::bits
}

node /mw(6[2-9]|7[0-4])\.pmtpa\.wmnet/ {
	include applicationserver::api
}

node "lily.knams.wikimedia.org" {
	$cluster = "misc_esams"
	include ganglia,
		nrpe,
		certificates::star_wikimedia_org

	install_certificate{ "star.wikimedia.org": }
}

node /mobile[1-5]\.wikimedia\.org/ {
	sudo_user { preilly: user => "preilly", privileges => ['ALL = NOPASSWD: ALL'] }
	if $hostname =~ /^mobile[12]/ {
		$ganglia_aggregator = "true"
	}
	$cluster = "mobile"
	$gid = 500
	$lvs_realserver_ips = [ "208.80.152.5" ]
	sudo_user { hcatlin : user => "hcatlin", privileges => ['ALL = NOPASSWD: ALL'] }
	include base,
		lvs::realserver,
		ntp::client,
		ganglia,
		exim::simple-mail-sender,
		groups::wikidev,
		accounts::hcatlin,
		accounts::preilly
	if $hostname =~ /^mobile[2345]/ {
		include mobile::v1104
	} else {
		include mobile::disabled
	}	
}

node /ms[1-3]\.pmtpa\.wmnet/ {
	if $hostname == "ms3" {
		include db::es::master
	}
	else {
		include	db::es::slave
	}
}

node "ms4.pmtpa.wmnet" {
	$cluster = "misc"

	include	base,
		ntp::client,
		misc::zfs::monitoring,
		misc::nfs-server::home::monitoring
}

node "ms5.pmtpa.wmnet" {
	include	standard,
		media-storage::thumbs-server,
		media-storage::thumbs-handler
}

node "ms6.esams.wikimedia.org" {
	$cluster = "misc_esams"
	$thumbs_proxying = "true"
	$thumbs_proxy_source = "http://208.80.152.3"

	include standard,
		media-storage::thumbs-server,
		media-storage::htcp-purger
}

node "ms7.pmtpa.wmnet" {
	$cluster = "misc"

	include	base,
		groups::wikidev,
		ntp::client,
		admins::roots,
		admins::restricted,
		misc::zfs::monitoring,
		misc::nfs-server::home::monitoring
}

node "ms8.pmtpa.wmnet" {
	$cluster = "misc"

	include	base,
		ntp::client,
		misc::zfs::monitoring
}

node "ms1002.eqiad.wmnet" {
	include standard,
		misc::images::rsyncd,
		misc::images::rsync
}

node /ms100[4]\.eqiad\.wmnet/ {
	$cluster = "misc"
	$ganglia_aggregator = "true"

	$thumbs_proxying = "true"
	$thumbs_proxy_source = "http://10.0.0.252"

	include standard,
		media-storage::thumbs-server,
		media-storage::htcp-purger
}

node "nescio.esams.wikimedia.org" {
	$cluster = "misc_esams"

	$dns_recursor_ipaddress = "91.198.174.6"

	interface_ip { "dns::auth-server": interface => "eth0", address => "91.198.174.4" }
	interface_ip { "dns::recursor": interface => "eth0", address => $dns_recursor_ipaddress }
	
	include standard,
		dns::recursor,
		dns::recursor::monitoring,
		dns::recursor::statistics

		class { "dns::auth-server":
			ipaddress => "91.198.174.4",
			soa_name => "ns2.wikimedia.org",
			master => $dns_auth_master
		}
}

node /^nfs[12].pmtpa.wmnet/ {

	$ldap_server_bind_ips = ""
	$cluster = "misc"
	$ldapincludes = ['openldap']
	$ldap_certificate = "$hostname.pmtpa.wmnet"
	install_certificate{ "$hostname.pmtpa.wmnet": }

	include base,
		ganglia,
		ntp::client,
		exim::simple-mail-sender,
		misc::nfs-server::home,
		misc::nfs-server::home::backup,
		misc::nfs-server::home::rsyncd,
		misc::syslog-server,
		misc::mediawiki-logger,
		ldap::server::wmf-cluster,
		ldap::client::wmf-cluster,
		backup::client

	monitor_service { "$hostname ldap cert": description => "Certificate expiration", check_command => "check_cert!$hostname.pmtpa.wmnet!636!wmf-ca.pem", critical => "true" }
}

node "owa1.wikimedia.org" {
	system_role { "owa::processing": description => "OWA processing node" }
	$cluster = "misc"
	$gid=500
	$lvs_realserver_ips = [ "208.80.152.6" ]
	sudo_user { nimishg: user => "nimishg", privileges => ['ALL = NOPASSWD: ALL'] }
	include base,
		ganglia,
		ntp::client,
		exim::simple-mail-sender,
		memcached,
		owa::processing,
		generic::geoip::files,
		lvs::realserver,
		groups::wikidev,
		accounts::nimishg
}

node "owa2.wikimedia.org" {
	system_role { "owa::processing": description => "OWA processing node" }
	$cluster = "misc"
	$gid=500
	$lvs_realserver_ips = [ "208.80.152.6" ]
	sudo_user { nimishg: user => "nimishg", privileges => ['ALL = NOPASSWD: ALL'] }
	include base,
		ganglia,
		ntp::client,
		exim::simple-mail-sender,
		memcached,
		owa::processing,
		generic::geoip::files,
		lvs::realserver,
		groups::wikidev,
		accounts::nimishg
}

node "owa3.wikimedia.org" {
	system_role { "owa::processing": description => "OWA processing node. Also temporary OWA db for now." }
	$cluster = "misc"
	$gid=500
	$lvs_realserver_ips = [ "208.80.152.6" ]
	sudo_user { nimishg: user => "nimishg", privileges => ['ALL = NOPASSWD: ALL'] }
	include base,
		ganglia,
		ntp::client,
		exim::simple-mail-sender,
		memcached,
		owa::processing,
		generic::geoip::files,
		lvs::realserver,
		owa::database,
		groups::wikidev,
		accounts::nimishg
}

node /^payments[1-4]\.wikimedia\.org$/ {
	$cluster = "payments"
	$lvs_realserver_ips = [ "208.80.152.7" ]

	if $hostname =~ /^payments[12]$/ {
		$ganglia_aggregator = "true"
	}

	system_role { "misc::payments": description => "Fundraising payments server" }

	include base::remote-syslog,
		base::sysctl,
		base::resolving,
		base::motd,
		base::monitoring::host,
		lvs::realserver,
		ganglia
}

node "pdf1.wikimedia.org" {
	$ganglia_aggregator = "true"
	$cluster = "pdf"

	include	base,
		ganglia,
		ntp::client,
		exim::simple-mail-sender,
		groups::wikidev,
		accounts::file_mover
}

node "pdf2.wikimedia.org" {
	$ganglia_aggregator = "true"
	$cluster = "pdf"

	include	base,
		ganglia,
		ntp::client,
		exim::simple-mail-sender,
		groups::wikidev,
		accounts::file_mover
}

node "pdf3.wikimedia.org" {
	$cluster = "pdf"

	include	base,
		ganglia,
		ntp::client,
		exim::simple-mail-sender,
		groups::wikidev,
		accounts::file_mover
}

node "project1.wikimedia.org" {
	$cluster = "misc"

	include base,
		ganglia,
		ntp::client,
		exim::simple-mail-sender
}

node "project2.wikimedia.org" {
	$cluster = "misc"

	include base,
		ganglia,
		ntp::client,
		exim::simple-mail-sender,
		groups::wikidev,
		accounts::reedy
}

node "sanger.wikimedia.org" {
	$gid = 500
	$ldapincludes = ['openldap']
	$ldap_certificate = "sanger.wikimedia.org"
	install_certificate{ "sanger.wikimedia.org": }

	include base,
		ganglia,
		ntp::client,
		nrpe,
		ldap::server::wmf-corp-cluster,
		ldap::client::wmf-corp-cluster,
		groups::wikidev,
		accounts::jdavis,
		backup::client

	## hardy doesn't support augeas, so we can't do this. /stab
	#include ldap::server::iptables

	monitor_service { "$hostname ldap cert": description => "Certificate expiration", check_command => "check_cert!$hostname.wikimedia.org!636!wmf-ca.pem", critical => "true" }
}

node /search[12]?[0-9]\.pmtpa\.wmnet/ {
	if $hostname == "search1.pmtpa.wmnet" {
		$ganglia_aggregator = "true"
	}

	include searchserver
}

node "searchidx1.pmtpa.wmnet" {
	$ganglia_aggregator = "true"

	include searchindexer
}

node "searchidx2.pmtpa.wmnet" {
	include searchindexer,
		mediawiki::packages
}

node "singer.wikimedia.org" {
	$cluster = "misc"
	$gid=500
	include base,
		ganglia,
		svn::client,
		ntp::client,
		exim::simple-mail-sender,
		certificates::star_wikimedia_org,
		groups::wikidev,
		accounts::austin,
		accounts::awjrichards


	install_certificate{ "star.wikimedia.org": }
	monitor_service { "secure cert": description => "Certificate expiration", check_command => "check_cert!secure.wikimedia.org!443!Equifax_Secure_CA.pem", critical => "true" }
}

node "sockpuppet.pmtpa.wmnet" {
	$cluster = "misc"
	$is_puppet_master = "true"

	include base,
		ganglia,
		ntp::client,
		exim::simple-mail-sender,
		misc::puppetmaster,
		backup::client
}

node "sodium.wikimedia.org" {

	include base,
		ganglia,
		nrpe,
		exim::listserve,
		mailman::base,
		spamassassin,
		backup::client,
		certificates::star_wikimedia_org

	install_certificate{ "star.wikimedia.org": }
}

node "spence.wikimedia.org" {
	$ganglia_aggregator = "true"
	$nagios_server = "true"

	include base,
		ganglia,
		nagios::monitor,
		nagios::monitor::pager,
		nagios::bot,
		nagios::ganglia::monitor::enwiki,
		nagios::ganglia::ganglios,
		ntp::client,
		nfs::home,
		exim::simple-mail-sender,
		admins::roots,
		certificates::wmf_ca,
		backup::client,
		misc::udpprofile::collector,
		certificates::star_wikimedia_org

	install_certificate{ "star.wikimedia.org": }
}

node "srv151.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv152.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv153.pmtpa.wmnet" {
	$ganglia_aggregator = "true"
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv154.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv155.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv156.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv157.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv158.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv159.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached::disabled
}

node "srv160.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv161.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv162.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached::disabled
}

node "srv163.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv164.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv165.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv166.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv167.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv168.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv169.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv170.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv171.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached::disabled
}

node "srv172.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv174.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached::disabled
}

node "srv175.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv176.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv177.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv178.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv179.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv180.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv181.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv182.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv183.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached::disabled
}

node "srv184.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv185.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv186.pmtpa.wmnet" {
	include applicationserver::homeless,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv187.pmtpa.wmnet" {
	include applicationserver::api,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv188.pmtpa.wmnet" {
	include applicationserver::api,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv189.pmtpa.wmnet" {
	include applicationserver::api,
		#applicationserver::jobrunner,
		memcached::disabled
}

node "srv190.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv191.pmtpa.wmnet" {
	$ganglia_aggregator = "true"

	include applicationserver::bits,
		memcached
}

node "srv192.pmtpa.wmnet" {
	$ganglia_aggregator = "true"

	include applicationserver::bits,
		memcached
}

# srv193 is test.wikipedia.org
node "srv193.pmtpa.wmnet" {
	include applicationserver::home,
		memcached
}

node "srv194.pmtpa.wmnet" {
	include applicationserver::homeless,
		memcached
}

node "srv195.pmtpa.wmnet" {
	include applicationserver::homeless,
		memcached
}

node "srv196.pmtpa.wmnet" {
	include applicationserver::homeless,
		memcached
}

node "srv197.pmtpa.wmnet" {
	include applicationserver::homeless,
		memcached
}

node "srv198.pmtpa.wmnet" {
	include applicationserver::homeless,
		memcached
}

node "srv199.pmtpa.wmnet" {
	include applicationserver::homeless,
		memcached
}

node "srv200.pmtpa.wmnet" {
	include applicationserver::homeless,
		memcached
}

node "srv201.pmtpa.wmnet" {
	include applicationserver::homeless,
		memcached
}

node "srv202.pmtpa.wmnet" {
	include applicationserver::homeless,
		memcached
}

node "srv203.pmtpa.wmnet" {
	include applicationserver::homeless,
		memcached
}

node "srv204.pmtpa.wmnet" {
	include applicationserver::homeless,
		memcached
}

node "srv205.pmtpa.wmnet" {
	include applicationserver::homeless,
		memcached
}

node "srv206.pmtpa.wmnet" {
	include applicationserver::homeless,
		memcached
}

node "srv207.pmtpa.wmnet" {
	include applicationserver::homeless,
		memcached
}

node "srv208.pmtpa.wmnet" {
	include applicationserver::homeless,
		memcached
}

node "srv209.pmtpa.wmnet" {
	include applicationserver::homeless,
		memcached
}

node "srv210.pmtpa.wmnet" {
	include applicationserver::homeless,
		memcached
}

node "srv211.pmtpa.wmnet" {
	include applicationserver::homeless,
		memcached
}

node "srv212.pmtpa.wmnet" {
	include applicationserver::homeless,
		memcached
}

node "srv213.pmtpa.wmnet" {
	include applicationserver::homeless,
		memcached
}

node "srv214.pmtpa.wmnet" {
	include applicationserver::api,
		memcached
}

node "srv215.pmtpa.wmnet" {
	include applicationserver::api,
		memcached
}

node "srv216.pmtpa.wmnet" {
	include applicationserver::api,
		memcached
}

node "srv217.pmtpa.wmnet" {
	include applicationserver::api,
		memcached
}

node "srv218.pmtpa.wmnet" {
	include applicationserver::api,
		memcached
}

node "srv219.pmtpa.wmnet" {
	$ganglia_aggregator = "true"
	include imagescaler
}

node "srv220.pmtpa.wmnet" {
	include imagescaler
}

node "srv221.pmtpa.wmnet" {
	include imagescaler
}

node "srv222.pmtpa.wmnet" {
	include imagescaler
}

node "srv223.pmtpa.wmnet" {
	include imagescaler
}

node "srv224.pmtpa.wmnet" {
	include imagescaler
}

node "srv225.pmtpa.wmnet" {
	#$dist = "lucid"
	include applicationserver::homeless,
		memcached
}

node "srv226.pmtpa.wmnet" {
	$ganglia_aggregator = "true"
	include applicationserver::homeless,
		memcached
}

node "srv227.pmtpa.wmnet" {
	include applicationserver::homeless,
		memcached
}

node "srv228.pmtpa.wmnet" {
	include applicationserver::homeless,
		memcached
}

node "srv229.pmtpa.wmnet" {
	include applicationserver::homeless,
		memcached
}

node "srv230.pmtpa.wmnet" {
	include applicationserver::homeless,
		memcached
}

node "srv231.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv232.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv233.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv234.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv235.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv236.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv237.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv238.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv239.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv240.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv241.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv242.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv243.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv244.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv245.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv246.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv247.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv248.pmtpa.wmnet" {
	include applicationserver::bits,
		memcached
}

node "srv249.pmtpa.wmnet" {
	include applicationserver::bits,
		memcached
}

node "srv250.pmtpa.wmnet" {
	include applicationserver::api,
		memcached
}

node "srv251.pmtpa.wmnet" {
	include applicationserver::api,
		memcached
}

node "srv252.pmtpa.wmnet" {
	include applicationserver::api,
		memcached
}

node "srv253.pmtpa.wmnet" {
	include applicationserver::api,
		memcached
}

node "srv254.pmtpa.wmnet" {
	$ganglia_aggregator = "true"

	include applicationserver::api
}

node "srv255.pmtpa.wmnet" {
	$ganglia_aggregator = "true"

	include applicationserver::api
}

node "srv256.pmtpa.wmnet" {
	include applicationserver::api
}

node "srv257.pmtpa.wmnet" {
	include applicationserver::api
}

node "srv258.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv259.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv260.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv261.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv262.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv263.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv264.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv265.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv266.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv267.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv268.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv269.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv270.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv271.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv272.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv273.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv274.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv275.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv276.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv277.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv278.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv279.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv280.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv281.pmtpa.wmnet" {
	#include applicationserver::homeless,
	#	applicationserver::jobrunner,
	#	 memcached
	include admins::roots,
		admins::mortals,
		apaches::pybal-check,
		imagescaler
}

node "srv282.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv283.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv284.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv285.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv286.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv287.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv288.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv289.pmtpa.wmnet" {
	include applicationserver::homeless,
		applicationserver::jobrunner,
		memcached
}

node "srv290.pmtpa.wmnet" {
	include applicationserver::api,
		memcached
}

node "srv291.pmtpa.wmnet" {
	include applicationserver::api
}

node "srv292.pmtpa.wmnet" {
	include applicationserver::api
}

node "srv293.pmtpa.wmnet" {
	include applicationserver::api
}

node "srv294.pmtpa.wmnet" {
	include applicationserver::api
}

node "srv295.pmtpa.wmnet" {
	include applicationserver::api
}

node "srv296.pmtpa.wmnet" {
	include applicationserver::api
}

node "srv297.pmtpa.wmnet" {
	include applicationserver::api
}

node "srv298.pmtpa.wmnet" {
	include applicationserver::api
}

node "srv299.pmtpa.wmnet" {
	include applicationserver::api
}

node "srv300.pmtpa.wmnet" {
	include applicationserver::api
}

node "srv301.pmtpa.wmnet" {
	include applicationserver::api
}

node /ssl[1-4]\.wikimedia\.org/ {
	$cluster = "ssl"
	if $hostname =~ /^ssl[12]$/ {
		$ganglia_aggregator = "true"
	}
	if $hostname =~ /^ssl1$/ {
		$enable_ipv6_proxy = true
	}

	include base,
		ganglia,
		ntp::client,
		certificates::wmf_ca,
		protoproxy::proxy_sites
}

node /ssl100[1-4]\.wikimedia\.org/ {
	$cluster = "ssl"
	if $hostname =~ /^ssl100[12]$/ {
		$ganglia_aggregator = "true"
	}
	if $hostname =~ /^ssl1001$/ {
		$enable_ipv6_proxy = true
	}

	include base,
		ganglia,
		ntp::client,
		certificates::wmf_ca,
		protoproxy::proxy_sites
}

node /ssl300[1-4]\.esams\.wikimedia\.org/ {
	$cluster = "ssl_esams"
	if $hostname =~ /^ssl300[12]$/ {
		$ganglia_aggregator = "true"
	}
	if $hostname =~ /^ssl3001$/ {
		$enable_ipv6_proxy = true

		include protoproxy::ipv6_labs
	}

	include base,
		ganglia,
		ntp::client,
		certificates::wmf_ca,
		protoproxy::proxy_sites
}

#sq31-sq36 are api squids
node /sq(3[1-6])\.wikimedia\.org/ {
	$cluster = "squids_api"
	$squid_coss_disks = [ 'sda5', 'sdb5', 'sdc', 'sdd' ]
	if $hostname =~ /^sq3[15]$/ {
		$ganglia_aggregator = "true"
	}
	include text-squid
}


# sq37-40 are text squids
node /sq(3[7-9]|40)\.wikimedia\.org/ {
	$squid_coss_disks = [ 'sda5', 'sdb5', 'sdc', 'sdd' ]

	include text-squid
}

# sq41-50 are old 4 disk upload squids
node /sq(4[1-9]|50)\.wikimedia\.org/ {
	$squid_coss_disks = [ 'sdb5', 'sdc', 'sdd' ]
	if $hostname =~ /^sq4[12]$/ {
		$ganglia_aggregator = "true"
	}

	include upload-squid
}

# sq51-58 are new ssd upload squids
node /sq5[0-8]\.wikimedia\.org/ {
	$squid_coss_disks = [ 'sdb5' ]
	include upload-squid
}

# sq59-66 are text squids
node /sq(59|6[0-6])\.wikimedia\.org/ {
	$squid_coss_disks = [ 'sda5', 'sdb5' ]
	if $hostname =~ /^sq(59|60)$/ {
		$ganglia_aggregator = "true"
	}

	include text-squid,
		lvs::realserver
}

# sq67-70 are varnishes for bits.wikimedia.org
node /sq(6[7-9]|70)\.wikimedia\.org/ {
	if $hostname =~ /^sq6[68]$/ {
		$ganglia_aggregator = "true"
	}

	include cache::bits
}

# eqiad varnish for m.wikipedia.org
node /cp104[3-4].wikimedia.org/ { 
	$ganglia_aggregator = "true"
	include cache::mobile
}

# sq71-78 are text squids
node /sq7[1-8]\.wikimedia\.org/ {
	$squid_coss_disks = [ 'sda5', 'sdb5' ]

	include text-squid,
		lvs::realserver
}

# sq79-86 are upload squids
node /sq(79|8[0-6])\.wikimedia\.org/ {
	$squid_coss_disks = [ 'sdb5' ]

	include upload-squid
}

node "stat1.wikimedia.org" {
	include base,
		ganglia,
		ntp::client,
		exim::simple-mail-sender,
		admins::roots,
		accounts::ezachte,
		accounts::reedy
}

node "storage1.wikimedia.org" {

	include standard
}

node "storage2.wikimedia.org" {
	include	base,
		ganglia,
		ntp::client,
		exim::simple-mail-sender
}

node "storage3.pmtpa.wmnet" {
	include db::core,
		svn::client,
		groups::wikidev,
		accounts::nimishg,
		accounts::rfaulk,
		accounts::awjrichards,
		accounts::logmover
}

node "streber.wikimedia.org" {
	system_role { "misc": description => "network monitoring server" }

	include base,
		ganglia,
		ganglia::collector,
		ntp::client,
		admins::roots,
		exim::rt,
		misc::rt::server,
		certificates::star_wikimedia_org


	install_certificate{ "star.wikimedia.org": }
	monitor_service { "lighttpd http": description => "Lighttpd HTTP", check_command => "check_http" }
}

node "snapshot1.pmtpa.wmnet" {
	$gid=500
	include base,
		ntp::client,
		ganglia,
		mediawiki::sync,
		snapshots::packages,
		snapshots::sync,
		snapshots::files,
		snapshots::noapache,
		admins::roots,
		admins::mortals,
		nfs::data,
		groups::wikidev
}

node "snapshot2.pmtpa.wmnet" {
	$gid=500
	include base,
		ntp::client,
		ganglia,
		mediawiki::sync,
		snapshots::packages,
		snapshots::sync,
		snapshots::files,
		snapshots::noapache,
		admins::roots,
		admins::mortals,
		nfs::data,
		groups::wikidev
}

node "snapshot3.wikimedia.org" {
	$gid=500
	include base,
		ntp::client,
		ganglia,
		applicationserver::home,
		nfs::data,
		groups::wikidev
}

node "snapshot4.pmtpa.wmnet" {
	$gid=500
	include base,
		ntp::client,
		ganglia,
		mediawiki::sync,
		snapshots::packages,
		snapshots::sync,
		snapshots::files,
		snapshots::noapache,
		admins::roots,
		admins::mortals,
		nfs::data,
		groups::wikidev
}

node "thistle.pmtpa.wmnet" {
	$ganglia_aggregator = "true"
	include db::core
}

node "transcode1.wikimedia.org" {
	include base,
		ganglia,
		ntp::client,
		exim::simple-mail-sender,
		misc::dc-cam-transcoder
}		

node "tridge.wikimedia.org" {
	include base,
		backup::server
}

node "virt1.wikimedia.org" {

	$is_puppet_master = "true"
	$is_labs_puppet_master = "true"
	$ldap_server_bind_ips = "127.0.0.1 $ipaddress_eth0"
	$ldap_certificate = "star.wikimedia.org"
	$ldap_first_master = "true"
	$dns_auth_ipaddress = "208.80.153.131"
	$dns_auth_soa_name = "virt1.wikimedia.org"

	install_certificate{ "star.wikimedia.org": }

	include standard,
		exim::simple-mail-sender,
		dns::auth-server-ldap,
		openstack::controller
}

node /virt[2-4].pmtpa.wmnet/ {
	include standard,
		exim::simple-mail-sender,
		openstack::compute
}

node "williams.wikimedia.org" {
	include base,
		ganglia,
		ntp::client,
		certificates::star_wikimedia_org

	install_certificate{ "star.wikimedia.org": }
}

node  "yongle.wikimedia.org" {
	$gid=500
	include	base,
		ganglia,
		ntp::client,
		groups::wikidev,
		accounts::catrope,
		exim::simple-mail-sender
}

node "yvon.wikimedia.org" {
	include base,
		ganglia,
		ntp::client,
		certificates::wmf_ca
}

node default {
	include	standard
}
