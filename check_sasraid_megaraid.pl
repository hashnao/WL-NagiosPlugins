#!/usr/bin/perl -wT
#
# ============================== SUMMARY =====================================
#
# Program : check_sasraid_megaraid.pl (also known as check_megaraid.pl)
# Version : 1.92
# Date    : June 15, 2012
# Author  : William Leibzon - william@leibzon.org
# Copyright: (C) 2002 ibiblio (C) 2006-2012 William Leibzon
# Summary : This is a nagios plugin to monitor LSI MegaRAID and attached disks
#           and report status of the logical and physical drives and disk errors.
#           Newer cards are called MTPFusion and many of these cards are
#           sold by Dell under their own brand name 'PERC' (PERC3 - PERC6)
#           Some are SCSI RAID cards and newer ones are SAS RAID cards.
# Licence : GPL - summary below, full text at http://www.fsf.org/licenses/gpl.txt
# =========================== PROGRAM LICENSE ================================
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GnU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
# ===================== INFORMATION ABOUT THIS PLUGIN ========================
#
# check_sasraid_megaraid | check_megaraid | check_sasraid
#
# This Nagios plugin checks a LSI/Dell Megaraid & SAS RAID cards
# and reports the status of the logical and physical drives and
# any disk and other volume errors.
#
# Requires that Net::SNMP be installed on the machine performing the monitoring
# and that the megaraid snmp agent be set up on the machine to be monitored.
#
# All latest versions are maintained by William Leibzon and released at:
#    http://william.leibzon.org/nagios/
# Original 0.8 version (last changed 2004) is by John Reuning, find it at:
#    http://www.ibiblio.org/john/megaraid/
#
# =============================== SETUP NOTES ================================
# 
# Recommended that you run this with '-h' to see all avaiable options.
#
# This originally started as check_megaraid plugin but now has been extended
# to work with various other cards. You must specify what card you have with
# '-T' option. The following are acceptable types:
#   megaraid|sasraid|perc3|perc4|perc5|perc6|mptfusion|sas6ir|sas6 
#
# You will need to have SNMP package installed appropriate for your card.
# If you have SASRaid (also known as PERC5, PERC6) you will need
# sasraid LSI package (lsi_mrdsnmpd unix service). This driver is available at
#   http://www.lsi.com/storage_home/products_home/internal_raid/megaraid_sas/megaraid_sas_8480e/index.html
#
# For LSI Megaraid (Dell PERC3 and PERC4 cards) the driver package is
# called percsnmp and you either find it on Dell's support site or at
#   http://www.lsi.com/storage_home/products_home/internal_raid/megaraid_scsi/
#
# For other cards please check with vendor you bought the card from for
# an appropriate SNMP driver package.
#
#  Here is an example of how to specify that in nagios config
#  (note that $USER1$ and $USER6$ are defined in resource.cfg,
#   $USER1$ is path to plugin directory and $USER6$ is community string
#   also "" around macros in commands.cfg are on purpose, don't forget them):
#
# define command {
#        command_name check_megaraid
#        command_line $USER1$/check_megaraid.pl -T megaraid -e -o -i -s 1 -H $HOSTADDRESS$ -C $USER6$ -P "$SERVICEPERFDATA$" -S "$SERVICESTATE$,$SERVICESTATETYPE$"
# }
# define service{
#        host_name                       list of target hosts
#        service_description             Megaraid Status
#        check_command                   check_megaraid
#        ...
# }
#
# =========================== VERSION HISTORY ================================
#
#   0. [0.8 - ? 2002] Version 0.8 of check_megaraid plugin was released by
#                     John Reuning in 2002. His plugin can still be found at
#		      http://www.ibiblio.org/john/megaraid/
# 
#   This was starting point for this plugin. However less than 10% of the code
#   is now from original John's plugin and since he has not been involved,
#   I've moved him from author to contributor. This note has been added in 2012.
#
#   1. [0.9 - ? 2006] Check consistancy has been downgraded to WARNING
#   2. [0.9 - ? 2006] The message in the output is now more detailed
#   3. [0.9 - ? 2006] The number of drives is now displayed in the output
#   4. [1.1 - Feb 2007] Plugin now retrieves snmp oid for read and write errors
#                       and reports an alert if its not 0 or -1
#   5. [1.2 - Feb 2007] Plugin now checks 'medium' and 'other' errors for
#      all physical drives. This data is returned as performance output and
#      in order to detect changes you need to send previous performance results
#      as a parameter in the command to this plugin. If your nagios is set to
#      send notifications after multiple subsequent non-OK alerts then you
#      also need to send previous state so as to force notification
#      (performance data would be same as original until non-OK HARD state)
#   6. [1.3  - Apr 2007] Reworked reporting of physical id to report it as 
#      "control/channel/id" when more then one controller is present or as
#      "channnel/id" when one controller and more then one channel
#      Also for persnmp5 if you have multiple luns (which should not happen
#      with disk drives) it will in theory add lun# as ".lun" to physical id
#   7. [1.35 - Apr 2007] Changed reporting of 'medium' and 'other' errors as
#      WARNING. Changed output system so that old performance data is
#      reported even for UNKNOWN
#   8. [1.4  - Apr 2007] Added specifying SNMP version and changed default
#      to v1 because as I found out this actually gets executed faster.
#      Also added capability to profile time it takes for this plugin
#      to execute with "--debug_time" option
#   9. [1.45 - May 2007] Modifications to output +num of physical or logical
#      drive errors when they happen instead of total number of errors 
#      Also plugin now reports WARNING when array is degraded but one
#      of the disks is being rebuilt
#      [1.46 - Jun 2007] Minor bug fixes
#   10. [1.5 - Oct 2007] Additional command-line option added to enable
#      extra drive error checks I've written (see above) i.e.
#      you now have to pass on "-e" option to enable checks for
#      medium & other errors. In reality this was already done as option
#      before as you had to pass on "-P" with old performance data to
#      make use of it, but now it also has to be specifically enabled
#      with '-e' or '--drive_errors" option.
#      Also new option '-i' ('--extra_info') which is enable information-only
#      data in plugin output. For 1.5 this is drive rebuilt rate info.
#   11. [1.6 - Oct 2007] Additional option '-o' ('--snmp_optimize') to minimize
#      number of SNMP queries when extra data is needed. When this is given
#      only one extra query is made for specific OIDs that are needed
#      instead of multiple SNMP table walks. Note that despite this type
#      of optimization working very well for number of my other plugins,
#      it is not clear if it actually better with percsnmp or not. Use at
#      your own risk and do some trials with '--debug_time' option to
#      if it is better for you.
#   12. [1.7 - Nov 2007] Some code cleanup and addition of -O to set base oid.
#      The only reason you might want this is if you modified /etc/snmp/snmpd
#      to have line other then "pass .1.3.6.1.4.1.3582 /usr/sbin/percmain".
#      And the only reason to do such modificatins is if you have both
#      PERC3/4 SCSI Megaraid card(s) and PERC5 SAS card which use sassnmp
#      driver by LSI (by default that will also try to use 1.3.6.1.4.1.3582).
#   13. [1.72 - Nov 2007] Changing of megaraid OIDs to SASRAID. This is mostly
#      quick hack as in the near future I plan to merge both check_megaraid
#      and check_sasraid back into one plugin with -T option specifying
#      what type of card you want to check 
#   14. [1.75 - Dec 2007] Code fixes and merger of
#      check_megaraid and check_sasraid plugins. Support for -T
#   15. [1.8 - Nov 2010, release Dec 15, 2010] patch by Vitaly Pecharsky:
#      Added support for mptsas devices, such as Dell SAS6i/R and other
#      similar LSI Logic / Symbios Logic SAS1068E PCI-Express Fusion-MPT SAS
#      (and possibly other). Use -T mptfusion|sas6|sas6ir switches for 
#      these cards. Both arrays (logical + physical) and standalone
#      (unconfigured physical only) drive configurations are supported.
#      Added explicit support for PERC 6 and PERC H700 controllers,
#      which are already supporting through sasraid path.
#   16. [1.901 - Dec 25, 2011] Support for SNMP v3. 
#      Bunch of new options added to support v3.
#      There is also an incompatible change in that default community is no longer
#      'public'. You must now specify community if you use snmp v1 or v2
#      This is all for better security for those few who do use this plugin
#   17. [1.902 - Jan 12, 2012] Documentation fixes
#   18. [1.91 - Feb 8, 2012] Bug fixes with 1.9 release (forgot to include verb() function)
#   19. [1.92 - Jun 15, 2012] Bug fixes when no SNNP version is specified
#	                      Verb function & option updated to allow debug info go to file
#			      specified as a parameter to -v rather than just stdout
#
# ========================== START OF PROGRAM CODE ===========================

my $version = "1.92";

use strict;
use Getopt::Long;
use Time::HiRes qw(time);

our $no_snmp=0;
eval 'use Net::SNMP';
if ($@) {
  $no_snmp=1;
}

# Nagios specific
use lib "/usr/lib/nagios/plugins";
our $TIMEOUT;
our %ERRORS;
eval 'use utils qw(%ERRORS $TIMEOUT)';
if ($@) {
 $TIMEOUT = 20;
 %ERRORS = ('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
}

# some defaults, most can be overriden by input parameters too
my $cardtype="sasraid";   # default card type, can be "megaraid", "mptfusion" or "sasraid"
my $baseoid=".1.3.6.1.4.1.3582";
my $timeout=$TIMEOUT;      # default is nagios exported $TIMEOUT variable
my $DEBUG = 0;             # to print debug messages, set this to 1
my $MAX_OUTPUTSTR = 512;   # maximum number of characters in otput

# Login and other options specific to SNMP
my $port =              161;    # SNMP port
my $o_community =       undef;  # community - this used to default to 'public' but no more
my $o_login=            undef;  # Login for snmpv3
my $o_passwd=           undef;  # Pass for snmpv3
my $v3protocols=        undef;  # V3 protocol list.
my $o_authproto=        'md5';  # Auth protocol
my $o_privproto=        'des';  # Priv protocol
my $o_privpass=         undef;  # priv password

########## CORE PLUGIN CODE (do not change below this line) ##################

# global variables (too many, but I do not want to bother cleaning it up now)
my(
$session,
$error,
$line,
$foo,			# represents an unused string
$host,
$alert,
$code,			# code value returned by snmp
$logdrv_id,		# drive id
$phydrv_id,
$nagios_status,		# nagios return status code, starts with "OK"
$opt_H,
$opt_p,
$opt_t,
$opt_a,
$opt_P,
$opt_snmpversion,
$opt_debug,
$opt_perfdata,
$opt_prevstate,
%pdrv_status,
%curr_perf,
%prev_perf,
@prev_state,
$opt_debugtime,
$opt_drverrors,
%debug_time,
$total_merr,
$total_oerr,
$opt_optimize,
$opt_extrainfo,
$opt_baseoid,
$opt_cardtype,
$o_help,
$o_version,
$logdrv_status_tableoid,
$phydrv_status_tableoid,
$phydrv_mediumerrors_tableoid,
$phydrv_othererrors_tableoid,
$phydrv_rebuildstats_tableoid,
$readfail_oid,
$writefail_oid,
$adpt_readfail_oid,
$adpt_writefail_oid,
%LOGDRV_CODES,
%PHYDRV_CODES
);

# Functions
sub help;
sub print_version;
sub print_usage;
sub process_perf;
sub print_output;
sub usage;
sub set_oids;
sub check_options;
sub create_snmp_session;

# Setting some initial values
$nagios_status = "OK";

# Function to set values for OIDs that are used (has to be a function as $baseoid is a parameter now)
sub set_oids {
  if ($cardtype eq 'megaraid') {
    $logdrv_status_tableoid = $baseoid . ".1.1.2.1.3";           # megaraid logical
    $phydrv_status_tableoid = $baseoid . ".1.1.3.1.4";           # megaraid physical
    $phydrv_mediumerrors_tableoid = $baseoid . ".1.1.3.1.12";    # megaraid medium errors
    $phydrv_othererrors_tableoid = $baseoid . ".1.1.3.1.15";     # megaraid other errors
    $phydrv_rebuildstats_tableoid = $baseoid . ".1.1.3.1.11";
    $readfail_oid = $baseoid . ".1.1.1.1.13";
    $writefail_oid = $baseoid . ".1.1.1.1.14";
    $adpt_readfail_oid = $baseoid . ".1.1.1.1.15";
    $adpt_writefail_oid = $baseoid . ".1.1.1.1.16";

    %LOGDRV_CODES = (
        0 => ['offline', 'drive is offline', 'NONE' ],
        1 => ['degraded', 'array is degraded', 'CRITICAL' ],
        2 => ['optimal', 'functioning properly', 'OK' ],
        3 => ['initialize', 'currently initializing', 'WARNING' ],
        4 => ['checkconsistency', 'array is being checked', 'WARNING' ],
    );
    %PHYDRV_CODES = (
        1 => ['ready'],
        3 => ['online'],
        4 => ['failed'],
        5 => ['rebuild'],
        6 => ['hotspare'],
        20 => ['nondisk'],
    );
  }
  elsif ($cardtype eq 'mptfusion') { 
    $logdrv_status_tableoid = $baseoid . ".5.1.4.3.1.2.1.5";       # mptfusion logical
    # $sas_logdrv_name_tableoid = $baseoid . ".4.1.4.3.1.2.1.6";   # sas virtual device name
    $phydrv_status_tableoid = $baseoid . ".5.1.4.2.1.2.1.10";      # mptfusion physical
    $phydrv_mediumerrors_tableoid = $baseoid . ".5.1.4.2.1.2.1.7"; # mptfusion medium errors
    $phydrv_othererrors_tableoid = $baseoid . ".5.1.4.2.1.2.1.8";  # mptfusion other errors

    ## Status codes for phyisical drives - these are specifically for MPTFUSION
    %PHYDRV_CODES = (
        0 => ['unconfigured_good'],
        1 => ['unconfigured_bad'],
        2 => ['hotspare'],
        16 => ['offline'],
        17 => ['failed'],
        20 => ['rebuild'],
        24 => ['online'],
    );
    %LOGDRV_CODES = ( 
        0 => ['offline', 'volume is offline', 'NONE' ],
        1 => ['degraded', 'parially degraded', 'CRITICAL' ],
        2 => ['degraded', 'fully degraded', 'CRITICAL' ],
        3 => ['optimal', 'functioning properly', 'OK' ]
    );
  }
  else { # $cardtype eq sasraid'
    $logdrv_status_tableoid = $baseoid . ".4.1.4.3.1.2.1.5";       # sasraid logical
    # $sas_logdrv_name_tableoid = $baseoid . ".4.1.4.3.1.2.1.6";   # sas virtual device name
    $phydrv_status_tableoid = $baseoid . ".4.1.4.2.1.2.1.10";      # sasraid physical
    $phydrv_mediumerrors_tableoid = $baseoid . ".4.1.4.2.1.2.1.7"; # sasraid medium errors
    $phydrv_othererrors_tableoid = $baseoid . ".4.1.4.2.1.2.1.8";  # sasraid other errors

    ## Status codes for phyisical drives - these are specifically for SASRAID
    %PHYDRV_CODES = (
        0 => ['unconfigured_good'],
        1 => ['unconfigured_bad'],
        2 => ['hotspare'],
        16 => ['offline'],
        17 => ['failed'],
        20 => ['rebuild'],
        24 => ['online'],
    );
    %LOGDRV_CODES = ( 
        0 => ['offline', 'volume is offline', 'NONE' ],
        1 => ['degraded', 'parially degraded', 'CRITICAL' ],
        2 => ['degraded', 'fully degraded', 'CRITICAL' ],
        3 => ['optimal', 'functioning properly', 'OK' ]
    );
  }
}

# For verbose output (updated 06/06/12 to write to debug file if specified)
sub verb {
    my $t=shift;
    if (defined($opt_debug)) {
        if ($opt_debug eq "") {
                print $t;
        }
        else {
            if (!open (DEBUGFILE, ">>$opt_debug")) {
                print $t;
            }
            else {
                print DEBUGFILE $t,"\n";
                close DEBUGFILE;
            }
        }
    }
}

# Function to parse command line arguments
sub check_options {
  Getopt::Long::Configure('bundling', 'no_ignore_case');
  GetOptions (
	'h'	=> \$o_help,		'help'		=> \$o_help,
	'V'	=> \$o_version,		'version'	=> \$o_version,
	'H:s'	=> \$opt_H,		'hostname:s'	=> \$opt_H,
        'O:s'   => \$opt_baseoid,	'oid:s'         => \$opt_baseoid,
	't:s'   => \$opt_t,		'timeout:s'	=> \$opt_t,
	'a:s'	=> \$opt_a,		'alert:s'	=> \$opt_a,
	'v:s'	=> \$opt_debug,		'verbose:s'	=> \$opt_debug,
	'd:s'	=> \$opt_debug,		'debug:s'	=> \$opt_debug,
					'debug_time'	=> \$opt_debugtime,
	'P:s'   => \$opt_perfdata,	'perf:s'	=> \$opt_perfdata,
	'S:s'	=> \$opt_prevstate,	'state:s'	=> \$opt_prevstate,
	'e'	=> \$opt_drverrors,	'drive_errors'	=> \$opt_drverrors,
	'o'	=> \$opt_optimize,	'snmp_optimize'	=> \$opt_optimize,
	'i'	=> \$opt_extrainfo,	'extra_info'	=> \$opt_extrainfo,
	'T:s'	=> \$opt_cardtype,	'controller_type:s' => \$opt_cardtype,
        'C:s'   => \$o_community,       'community:s'   => \$o_community,
        's:s'   => \$opt_snmpversion,   'snmp_version:s' => \$opt_snmpversion,
	'p:s'	=> \$opt_p,		'port:s'	=> \$opt_p,
        'l:s'   => \$o_login,           'login:s'       => \$o_login,
        'x:s'   => \$o_passwd,          'passwd:s'      => \$o_passwd,
        'X:s'   => \$o_privpass,        'privpass:s'    => \$o_privpass,
        'L:s'   => \$v3protocols,       'protocols:s'   => \$v3protocols
  );

  if (defined($o_help)) { help(); exit $ERRORS{"UNKNOWN"}; };
  if (defined($o_version)) { print_version(); exit $ERRORS{"UNKNOWN"}; };

  # hostname
  if ($opt_H) {
  	$host = $1 if ($opt_H =~ m/^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+|[a-zA-Z][-a-zA-Z0-9]*(\.[a-zA-Z][-a-zA-Z0-9]*)*)$/);
  	usage("Invalid hostname: $opt_H\n") if !$host;
  }
  else {
     usage("Hostname or IP address not specified\n");
  }

  if ($no_snmp) {
     print "Can't locate Net/SNMP.pm\n"; exit $ERRORS{"UNKNOWN"};
  }

  # port number - defaults to 161
  if ($opt_p) {
        ($opt_p =~ m/^[0-9]+$/) || usage("Invalid port number: $opt_p\n");
        $port = $opt_p;
  }
  # snmp version parameter, default auto-detect with version 1 if community is specified
  if (!defined($opt_snmpversion)) {
	if (defined($o_community) && !defined($o_login) && !defined($o_passwd)) {
		$opt_snmpversion = '1';
	}
	elsif (!defined($o_community) && defined($o_login) && defined($o_passwd)) {
		$opt_snmpversion = '3';
	}
	else {
		usage("Can not autodetect SNMP version when -C and -l are both specified\n");
	}
  }
  if ($opt_snmpversion eq '2' || $opt_snmpversion eq '2c') {
        $opt_snmpversion='2';
  }
  elsif ($opt_snmpversion ne '1' && $opt_snmpversion ne '3') {
        usage("Invalid or unsupported value ($opt_snmpversion) for SNMP version\n");
  }
  if (defined($o_login) || defined($o_passwd)) {
	if (defined($o_community)) { usage("Can't mix snmp v1,2c,3 protocols!\n"); }
	if ($opt_snmpversion ne '3') { usage("Incorrect snmp version specified!\n"); }
  }
  if (defined($o_community)) {
	if ($opt_snmpversion eq '3') { usage("SNMP version 3 does not use community\n"); }
  }
  if (defined ($v3protocols)) {
        if (!defined($o_login)) { usage("Put snmp V3 login info with protocols!\n"); }
        my @v3proto=split(/,/,$v3protocols);
        if ((defined ($v3proto[0])) && ($v3proto[0] ne "")) { $o_authproto=$v3proto[0]; } 
        if (defined ($v3proto[1])) {$o_privproto=$v3proto[1];}   # Priv  protocol
        if ((defined ($v3proto[1])) && (!defined($o_privpass)))
          { usage("Put snmp V3 priv login info with priv protocols!\n"); }
  }

  # cart type parameter
  if (defined($opt_cardtype)) {
     if ($opt_cardtype eq 'megaraid' || $opt_cardtype eq 'perc3' || $opt_cardtype eq 'perc4') {
	$cardtype='megaraid';
     }
     elsif ($opt_cardtype eq 'sasraid' || $opt_cardtype eq 'perc5' || $opt_cardtype eq 'perc6' || $opt_cardtype eq 'perch700') {
	$cardtype='sasraid';
     }
     elsif ($opt_cardtype eq 'mptfusion' || $opt_cardtype eq 'sas6ir' || $opt_cardtype eq 'sas6') {
	$cardtype='mptfusion';
     }
     else {
	usage("Invalid controller type specified");
     }
  }

  # set baseoid, default is ".1.3.6.1.4.1.3582" and then based on it set all other oids
  $baseoid = $opt_baseoid if $opt_baseoid;
  set_oids();

  # timeout - defaults to nagios timeout
  if ($opt_t) {
  	($opt_t =~ m/^[0-9]+$/) || usage("Invalid timeout value: $opt_t\n");
  	$timeout = $opt_t;
  }

  # alert - defaults to "crit"
  if (!$opt_a) {
 	$alert="CRITICAL";
  } elsif ($opt_a =~ /warn/) {
	$alert = "WARNING";
  } elsif ($opt_a =~ /crit/) {
	$alert = "CRITICAL";
  } else {
	usage("Invalid alert: $opt_a\n");
  }

  # previos performance data string and previous state
  %prev_perf=process_perf($opt_perfdata) if $opt_perfdata;
  @prev_state=split(',',$opt_prevstate) if $opt_prevstate;

  $DEBUG=$opt_debug if defined($opt_debug) && $opt_debug;
  $debug_time{plugin_start}=time() if $opt_debugtime;
  if ($DEBUG) {
	print "hostname: $host\n";
	print "community: $o_community\n" if defined($o_community);
	print "port: $port\n";
	print "timeout: $timeout\n";
	print "alert: $alert\n";
	print "prev_state: $opt_prevstate\n" if $opt_prevstate;
	# print "perf: $opt_perfdata \n" if $opt_perfdata;
  }
}

sub create_snmp_session {
  my ($session,$error);

  if ($opt_snmpversion eq '3') {
    # SNMPv3 login
    if (!defined ($o_privpass)) {
     verb("SNMPv3 AuthNoPriv login : $o_login, $o_authproto");
     ($session, $error) = Net::SNMP->session(
      -hostname         => $host,
      -version          => '3',
      -port             => $port,
      -username         => $o_login,
      -authpassword     => $o_passwd,
      -authprotocol     => $o_authproto,
      -timeout          => $timeout
     );
    } else {
     verb("SNMPv3 AuthPriv login : $o_login, $o_authproto, $o_privproto");
     ($session, $error) = Net::SNMP->session(
      -hostname         => $host,
      -version          => '3',
      -username         => $o_login,
      -port             => $port,
      -authpassword     => $o_passwd,
      -authprotocol     => $o_authproto,
      -privpassword     => $o_privpass,
      -privprotocol     => $o_privproto,
      -timeout          => $timeout
     );
    }
  }
  elsif ($opt_snmpversion eq '2') {
    # SNMPv2c Login
      verb("SNMP v2c login");
      ($session, $error) = Net::SNMP->session(
       -hostname  => $host,
       -version   => 2,
       -community => $o_community,
       -port      => $port,
       -timeout   => $timeout
      );
  } else {
    # SNMPV1 login
      verb("SNMP v1 login");
      ($session, $error) = Net::SNMP->session(
       -hostname  => $host,
       -community => $o_community,
       -port      => $port,
       -timeout   => $timeout
      );
  }
  if (!defined($session)) {
     printf("ERROR opening session: %s.\n", $error);
     exit $ERRORS{"UNKNOWN"};
  }

  return $session;
}

################## START OF THE MAIN CODE ##############################

check_options();

# set the timeout
$SIG{'ALRM'} = sub {
	if(defined($session)) {
		$session->close;
	}
	print_output("UNKNOWN","snmp query timed out");
	exit $ERRORS{"UNKNOWN"};
};
alarm($timeout);

my ($snmp_result,$logdrv_data_in,$phydrv_data_in,$phydrv_merr_in,$phydrv_oerr_in);

$session = create_snmp_session();

# fetch snmp data, first optional readfail & writefail values - SASRAID MIB does not have this
if ($cardtype eq 'megaraid' && defined($opt_drverrors)) {
	$debug_time{snmpretrieve_readwritefailoids}=time() if $opt_debugtime;
	$snmp_result=$session->get_request(-Varbindlist => [ $readfail_oid, $writefail_oid, $adpt_readfail_oid, $adpt_writefail_oid ]);
	$debug_time{snmpretrieve_readwritefailoids}=time()-$debug_time{snmpretrieve_readwritefailoids} if $opt_debugtime;
	$error.="could not retrieve snmp data OIDs" if !$snmp_result;
}

# 2nd are logical disk drive status
$debug_time{snmpgettable_logdrvstatus}=time() if $opt_debugtime;
$logdrv_data_in = $session->get_table(-baseoid => $logdrv_status_tableoid) if !$error;
$debug_time{snmpgettable_logdrvstatus}=time()-$debug_time{snmpgettable_logdrvstatus} if $opt_debugtime;

# allow this to not be found for mptfusion cards, as they may have drives which aren't part of any array
if ($cardtype ne 'mptfusion') {
	$error.= "could not retrieve snmp table $logdrv_status_tableoid" if !$logdrv_data_in && !$error;
}

# 3rd are physical disk drive status
$debug_time{snmpgettable_phydrvstatus}=time() if $opt_debugtime;
$phydrv_data_in = $session->get_table(-baseoid => $phydrv_status_tableoid) if !$error;
$debug_time{snmpgettable_phydrvstatus}=time()-$debug_time{snmpgettable_phydrvstatus} if $opt_debugtime;
$error.= "could not retrieve snmp table $phydrv_status_tableoid" if !$phydrv_data_in && !$error;

# last are medium and "other" errors reported for physical drives
if (defined($opt_drverrors) && defined($opt_perfdata) && !defined($opt_optimize)) {
	$debug_time{snmpgettable_mederrors}=time() if $opt_debugtime;
	$phydrv_merr_in = $session->get_table(-baseoid=>$phydrv_mediumerrors_tableoid) if !$error;
	$debug_time{snmpgettable_mederrors}=time()-$debug_time{snmpgettable_mederrors} if $opt_debugtime;
	$error.= "could not retrieve snmp table $phydrv_mediumerrors_tableoid" if !$phydrv_merr_in && !$error;
	$debug_time{snmpgettable_odrverrors}=time() if $opt_debugtime;
	$phydrv_oerr_in = $session->get_table(-baseoid=>$phydrv_othererrors_tableoid) if !$error;
	$debug_time{snmpgettable_odrverrors}=time()-$debug_time{snmpgettable_odrverrors} if $opt_debugtime;
	$error.= "could not retrieve snmp table $phydrv_othererrors_tableoid" if !$phydrv_oerr_in && !$error;
}

if ($error) {
	if ($DEBUG) {
		printf("snmp error: %s\n", $session->error());
	}
	$session->close;
	print_output("UNKNOWN",$error);
	exit $ERRORS{'UNKNOWN'};
}

#--------------------------------------------------#
# parse the data and determine status

# set the initial output string and ok status
my $output_data = "";
my $output_data_end = "";

if ($DEBUG && $cardtype eq 'megaraid') {
	print "adpt_readfail: ". $adpt_readfail_oid ." = ". $snmp_result->{$adpt_readfail_oid} ."\n" if exists($snmp_result->{$adpt_readfail_oid});
	print "adpt_writefail: ". $adpt_writefail_oid ." = ". $snmp_result->{$adpt_writefail_oid} ."\n" if exists($snmp_result->{$adpt_writefail_oid});
	print "readfail_sec: ". $readfail_oid ." = ". $snmp_result->{$readfail_oid} ."\n" if exists($snmp_result->{$readfail_oid});
	print "writefail_sec: ". $writefail_oid ." = ". $snmp_result->{$writefail_oid} ."\n" if exists($snmp_result->{$writefail_oid});
}
if (defined($opt_drverrors) && $cardtype ne 'sasraid' && $cardtype ne 'mptfusion') {
  if (exists($snmp_result->{adpt_readfail_oid}) && $snmp_result->{$adpt_readfail_oid}>0) {
	$output_data=$snmp_result->{$adpt_readfail_oid}." adapter read failures";
	$nagios_status=$alert;
  }
  if (exists($snmp_result->{adpt_writefail_oid}) && $snmp_result->{$adpt_writefail_oid}>0) {
	$output_data.= ", " if $output_data;
        $output_data=$snmp_result->{$adpt_writefail_oid}." adapter write failures";
        $nagios_status=$alert;
  }
  if (exists($snmp_result->{write_oid}) && $snmp_result->{$writefail_oid}>0) {
        $output_data.= ", " if $output_data;
        $output_data=$snmp_result->{$writefail_oid}." write failures";
        $nagios_status=$alert;
  }
  if (exists($snmp_result->{readfail_oid}) && $snmp_result->{$readfail_oid}>0) {
        $output_data.= ", " if $output_data;
        $output_data=$snmp_result->{$readfail_oid}." read failures";
        $nagios_status=$alert;
  }
}

# physical drive states
my $phydrv_total=0;
my ($controller_id, $channel_id, $drive_id, $lun_id);
my %h_controllers=();
my %h_channels=();
my @extra_oids=();
my $phy_skipids=0;

# first loop to load data (and find controller, channel, drive ids) for all drives into our hash
foreach $line (Net::SNMP::oid_lex_sort(keys(%{$phydrv_data_in}))) {
	$code = $phydrv_data_in->{$line};
	  print "phydrv_status: $line = $code" if $DEBUG;
	$line = substr($line,length($phydrv_status_tableoid)+1);
	($controller_id,$channel_id,$drive_id,$lun_id) = split(/\./,$line,4);
	if (!$drive_id) {
		if (!$channel_id) {
			$drive_id = $controller_id;
			$controller_id = 0;
			$channel_id = 0;
		}
		else {
			$drive_id = $channel_id;
			$channel_id = $controller_id;
			$controller_id = 0;
		}
		# this is for SASRAID to skip first id if its non-disk
		# (I think they fixed this bug in newest release though)
		if ($cardtype eq 'sasraid' || $cardtype eq 'mptfusion') {
		    $phy_skipids++ if $code==0;
		    $drive_id-=$phy_skipids;
		}
	}
	$lun_id = 0 if !defined($lun_id);
	  print " | suffix = $line, controller = $controller_id, channel = $channel_id, drive = $drive_id, lun = $lun_id\n" if $DEBUG;
	$h_controllers{$controller_id}=1;
	$h_channels{$controller_id.'_'.$channel_id}=1;
	if (!$pdrv_status{$line}) {
		$pdrv_status{$line} = { 'status' => $code, 'controller' => $controller_id, 'channel' => $channel_id, 'drive' => $drive_id, 'lun' => $lun_id };
	}
	else {
		print_output("UNKNOWN","processing error, physical drive $line found in SNMP result 2nd time");
        	exit $ERRORS{'UNKNOWN'};
	}
	# find which additional OIDs should be queried if snmp query optimization is enabled
	if (defined($opt_optimize)) {
	   if (defined($opt_drverrors) && defined($opt_perfdata)) {
		push @extra_oids, $phydrv_mediumerrors_tableoid.'.'.$line;
		push @extra_oids, $phydrv_othererrors_tableoid.'.'.$line;
	   }
	   if (defined($opt_extrainfo) && defined($phydrv_rebuildstats_tableoid)) {
		push @extra_oids, $phydrv_rebuildstats_tableoid.'.'.$line;
	   }
	}
}
my $num_controllers = scalar(keys %h_controllers);
my $num_channels = scalar(keys %h_channels);

# Now we can do additional SNMP query (for now its here as currently all additional queries are related to physical drives)
if (defined($opt_optimize) && scalar(@extra_oids)>0) {
  $error="";
  $debug_time{snmpretrieve_extraoids}=time() if $opt_debugtime;
  $snmp_result=$session->get_request(-Varbindlist => \@extra_oids);
  $debug_time{snmpretrieve_extraoids}=time()-$debug_time{snmpretrieve_extraoids} if $opt_debugtime;
  if (!$snmp_result) {
	$error.=sprintf("could not retrieve extra data snmp OIDs: %s\n", $session->error());
	$session->close;
	print_output('UNKNOWN',$error);
	exit $ERRORS{'UNKNOWN'};
  }
  if (defined($opt_drverrors)) {
      $phydrv_merr_in = $snmp_result;
      $phydrv_oerr_in = $snmp_result;
  }
}

# 2nd loop as we now can find what physical id to use
my $phd_nagios_status = $nagios_status;
foreach $line (Net::SNMP::oid_lex_sort(keys(%{$phydrv_data_in}))) {
	$line = substr($line,length($phydrv_status_tableoid)+1);
	if ($num_controllers > 1) {
		$phydrv_id = $pdrv_status{$line}{controller}.'/'.$pdrv_status{$line}{channel}.'/'.$pdrv_status{$line}{drive};
	}
	elsif ($num_channels > 1) {
		$phydrv_id = $pdrv_status{$line}{channel}.'/'.$pdrv_status{$line}{drive};
	}
	else {
		$phydrv_id = $pdrv_status{$line}{drive};
	}
	$phydrv_id .= '.'.$pdrv_status{$line}{lun} if ($pdrv_status{$line}{lun} != 0);
	$pdrv_status{$line}{phydrv_id}=$phydrv_id;

	$code= $pdrv_status{$line}{status};
	# check status (catch if state is either "failed" (4) or "rebuild" (5))
	if (!defined($PHYDRV_CODES{$code})) {
                $output_data.=", " if $output_data;
                $output_data.= "phy drv($phydrv_id) unknown code $code";
                $nagios_status = $alert; # maybe this should not be an alert???
		$pdrv_status{$line}{'status_str'} = $code;
        }
	else {
		$pdrv_status{$line}{'status_str'} = $PHYDRV_CODES{$code};
		if ($PHYDRV_CODES{$code}[0] eq 'failed' || $PHYDRV_CODES{$code}[0] eq 'rebuild' || $PHYDRV_CODES{$code}[0] eq 'unconfigured_bad') {
			$output_data .= ", " if $output_data;
			$output_data .= "phy drv($phydrv_id) ".$PHYDRV_CODES{$code}[0];
			if ($PHYDRV_CODES{$code}[0] eq 'rebuild') {
				$phd_nagios_status = "WARNING" if $phd_nagios_status eq 'OK';
				# optionally check rate of rebuild
				if (defined($opt_extrainfo)) {
					my $eoid = $phydrv_rebuildstats_tableoid.'.'.$line;
					if (!defined($opt_optimize)) {
  						$debug_time{'snmpretrieve_rebuild_'.$phydrv_id}=time() if $opt_debugtime;
  						$snmp_result=$session->get_request(-Varbindlist => [ $eoid ]);
  						$debug_time{'snmpretrieve_rebuild_'.$phydrv_id}=time()-$debug_time{'snmpretrieve_rebuild_'.$phydrv_id} if $opt_debugtime;
						if (!$snmp_result) {
        						$error=sprintf("could not retrieve OID $eoid: %s\n", $session->error());
        						$session->close;
        						print_output('UNKNOWN',$error);
        						exit $ERRORS{'UNKNOWN'};
  						}
					}
					$output_data.= ' ('.$snmp_result->{$eoid}.')' if defined($snmp_result->{$eoid});
				}
			}
			else { # failed state
				$phd_nagios_status = $alert; 
			}
		}
		$phydrv_total++ if ($PHYDRV_CODES{$code}[0] ne 'nondisk' && ($cardtype ne 'sasraid' || $cardtype ne 'mptfusion' || $code>0));  # only count disks for output
	}
}

# check logical drive status
foreach $line (Net::SNMP::oid_lex_sort(keys(%{$logdrv_data_in}))) {
        $code = $logdrv_data_in->{$line};
        if ($DEBUG) {
                print "logdrv_status: $line = $code";
        }
        $line = substr($line,length($logdrv_status_tableoid)+1);
        ($foo,$logdrv_id) = split(/\./,$line,2);
	$logdrv_id=$foo if !$logdrv_id;
        if ($DEBUG) {
                print " | logdrv_id = $logdrv_id\n";
        }
        # check status (catch if status is not "optimal" (2))
        if (!defined($LOGDRV_CODES{$code})) {
                $output_data.=", " if $output_data;
                $output_data.= "log drv($logdrv_id) unknown code $code";
                $nagios_status = $alert; # maybe this should not be an alert???
        }
        elsif ($LOGDRV_CODES{$code}[0] ne 'optimal') {
                $output_data.= ", " if $output_data;
                $output_data .= "log drv($logdrv_id) ".$LOGDRV_CODES{$code}[0]." (".$LOGDRV_CODES{$code}[1].")";
                if ($LOGDRV_CODES{$code}[0] eq 'checkconsistency' || $LOGDRV_CODES{$code}[0] eq 'initialize') {
                        $nagios_status = "WARNING" if $nagios_status eq "OK";
                }
                else {
			# below is to force WARNING in case when array is degraded but disk is already being rebuild
			if ($LOGDRV_CODES{$code}[0] eq 'degraded' && $phd_nagios_status eq 'WARNING' && $nagios_status ne $alert) {
				$nagios_status='WARNING';
			}
			else {
                        	$nagios_status = $alert;
			}
                }
        }
}

# physical drive errors
$total_merr=0;
$total_oerr=0;
my $nerr=0;
my $ndiff=0;

if (defined($opt_perfdata)) {
    foreach $line (keys %pdrv_status) {
	# first process medium errors
        $nerr = $phydrv_merr_in->{$phydrv_mediumerrors_tableoid.'.'.$line};
          print "phydrv_mediumerr: $phydrv_mediumerrors_tableoid.$line = $nerr" if $DEBUG;
	if ($pdrv_status{$line}{status_str} ne 'nondisk' && ($cardtype ne 'sasraid' || $cardtype ne 'mptfusion' || $pdrv_status{$line}{status}>0)) {
		  print " | suffix = $line, phydrv_id = ".$pdrv_status{$line}{phydrv_id} if $DEBUG;
		$curr_perf{'merr_'.$line}=$nerr;
		if ($nerr!=0 && (!defined($prev_perf{'merr_'.$line}) || $prev_perf{'merr_'.$line} < $nerr)) {
			$ndiff=$nerr;
			$ndiff-=$prev_perf{'merr_'.$line} if defined($prev_perf{'merr_'.$line});
			$output_data .= ", " if $output_data;
                        $output_data .= "phy drv(".$pdrv_status{$line}{phydrv_id}.") +$ndiff medium errors";
			$phd_nagios_status = 'WARNING' if $phd_nagios_status eq 'OK';
		}
                if ($nerr!=0) {
			$total_merr+=$nerr;
                        $output_data_end .= ", " if $output_data_end;
                        $output_data_end .= "phy drv(".$pdrv_status{$line}{phydrv_id}.") $nerr medium errors";
                }
	}
	  print "\n" if $DEBUG;
	# now process other errors 
	$nerr = 0;
        $nerr = $phydrv_oerr_in->{$phydrv_othererrors_tableoid.'.'.$line};
          print "phydrv_othererr: $phydrv_othererrors_tableoid.$line = $nerr" if $DEBUG;
	if ($pdrv_status{$line}{status_str} ne 'nondisk' && ($cardtype ne 'sasraid' ||$pdrv_status{$line}{status}>0)) {
		  print " | suffix = $line, phydrv_id = ".$pdrv_status{$line}{phydrv_id} if $DEBUG;
		$curr_perf{'oerr_'.$line}=$nerr;
		if ($nerr!=0 && (!defined($prev_perf{'oerr_'.$line}) || $prev_perf{'oerr_'.$line} < $nerr)) {
			$ndiff=$nerr;
			$ndiff-=$prev_perf{'oerr_'.$line} if defined($prev_perf{'oerr_'.$line});
                	$output_data .= ", " if $output_data;
                        $output_data .= "phy drv(".$pdrv_status{$line}{phydrv_id}.") +$ndiff other errors";
			$phd_nagios_status = 'WARNING' if $phd_nagios_status eq 'OK';
		}
                if ($nerr!=0) {
			$total_oerr+=$nerr;
                        $output_data_end .= ", " if $output_data_end;
                        $output_data_end .= "phy drv(".$pdrv_status{$line}{phydrv_id}.") $nerr other errors";
                }
	}
	  print "\n" if $DEBUG;
    }
}

# close SNMP session (before it was done a lot earlier)
$session->close if !defined($opt_optimize);

$debug_time{plugin_finish}=time() if $opt_debugtime;
$debug_time{plugin_totaltime}=$debug_time{plugin_finish}-$debug_time{plugin_start} if $opt_debugtime;

# output text results
$output_data.= " - " if $output_data;
$output_data.= sprintf("%d logical disks, %d physical drives, %d controllers found", scalar(keys %{$logdrv_data_in}), $phydrv_total, $num_controllers);
$output_data.= " - ". $output_data_end if $output_data_end;

# netsaint doesn't like output strings larger than 256 chars
# [William: modified it so that number of characters is now $MAX_OUTPUTSTR
#           defined top of the file, if you set it to undef this is not checked]
$output_data = substr($output_data,0,$MAX_OUTPUTSTR) if defined($MAX_OUTPUTSTR) && length($output_data) > $MAX_OUTPUTSTR;

# combine status from checking physical and logical drives and print everything
$nagios_status = $phd_nagios_status if $ERRORS{$nagios_status}<$ERRORS{$phd_nagios_status};
print_output($nagios_status,$output_data);
exit $ERRORS{"$nagios_status"};

################## END OF MAIN CODE ######################################

# version flag function
sub print_version {
	print "$0 version $version\n";
}

# display help information
sub help {
        print_version();
        print "GPL licence, (c)2002 iBiblio, (c) 2006-2012 William Leibzon\n";
        print "code by William Leibzon, John Reuning, Vitaly Pecharsky\n\n";
        print "This plugin uses SNMP to check logical and physical drive status of a RAID controllers\n";
	print "sold under LSI, MPTFusion, Dell PERC Megaraid, Dell PERC SASRaid brands.\n";
	print "\n";
        print_usage();
        print "\n";
	print "Options:\n";
	print "  -h, --help\n";
	print "    Display help\n";
	print "  -V, --version\n";
	print "    Display version\n";
	print "  -T, --controller_type <type>\n";
	print "    Type of controller - can be: megaraid|sasraid|perc3|perc4|perc5|perc6|perch700|mptfusion|sas6ir|sas6\n";
	print "    (megaraid=perc3,perc4; sasraid=perc5,perc6,perch700; mptfusion=sas6ir,sas6)\n";
	print "  -O, --oid <base oid>\n";
	print "    Base OID for megaraid is .1.3.6.1.4.1.3582 and you almost never need to change it\n";
	print "    (the only case is when you might is when you have both percsnmp and sassnmp cards)\n";
	print "  -a, --alert <alert level>\n";
	print "    Alert status to use if an error condition is found\n";
	print "    Accepted values are: \"crit\" and \"warn\" (defaults to crit)\n";
	print "  -i, --extra_info\n";
	print "    Extra additional information in output (such as rebuild rate)\n";
	print "  -o, --snmp_optimize\n";
	print "	   Try to minimize number of SNMP queries replacing snmp_walk with retrieval of specific OIDs at once\n";
	print "    !! EXPERIMENTAL, USE AT YOUR OWN RISK (and use --debug_time to make sure it is actually faster) !!!\n";
	print "  -e, --drive_errors\n";
	print "    Do additonal checks for medium and other errors on each drive.\n";
	print "    This is about 2x as many SNMP check and so can slow plugin down.\n";
	print "    !!! You will need to use pass to plugin previous PERF and STATE data with -P and -S options !!!\n";
	print "  -P, --perf <performance data>\n";
	print '    The results of previous check performance data ($SERVICEPERFDATA$ macro)'."\n";
	print "    which contains number of medium and other errors that were before\n";
	print "    if this is not the same now then ALERT is sent\n";
	print "  -S, --state <STATE,STATETYPE>\n";
	print "    If you use -P and you have notifications sent to be sent at > 1 alerts\n";
	print "    then you need to send previous state and type (HARD or SOFT) and then\n";
	print "    this plugin would continue to report non-OK state until STATETYPE changes\n";
	print "    to HARD thereby making sure user receives NOTIFICATION\n";
	print "    Proper use of this is have '-S ".'"$SERVICESTATE$,$SERVICESTATETYPE$"'."' in your commands.cfg\n";
	print "\nSNMP Access Options:\n";
        print "  -H, --hostname <host>\n";
        print "    Hostname or IP address of target to check\n";
        print "  -C, --community <community>\n";
        print "    SNMP community string\n";
        print "  -s, --snmp_version 1 | 2 | 2c | 3\n";
        print "    Version of SNMP protocol to use (default is 1 if -C and 3 if -l specified)";
        print "  -p, --port <port>\n";
        print "    SNMP port (defaults to 161)\n";
        print "  -l, --login=LOGIN ; -x, --passwd=PASSWD\n";
        print "    Login and auth password for snmpv3 authentication\n";
        print "    If no priv password exists, implies AuthNoPriv\n";
        print "  -X, --privpass=PASSWD\n";
        print "    Priv password for snmpv3 (AuthPriv protocol)\n";
        print "  -L, --protocols=<authproto>,<privproto>\n";
        print "    <authproto> : Authentication protocol (md5|sha : default md5)\n";
        print "    <privproto> : Priv protocols (des|aes : default des)\n";
        print "  -t, --timeout <timeout>\n";
        print "    Seconds before timing out (defaults to Nagios timeout value)\n";
	print "\nDebug Options:\n";
	print "  --debug[=FILENAME] || --verbose[=FILENAME]\n";
	print "    Enables verbose debug output printing exactly what data was retrieved from SNMP\n";
	print "    This is mainly for manual checks when testing this plugin on the console\n";
	print "	   If filename is specified instead of STDOUT the debug data is written to that file\n";
	print "  --debug_time \n";
	print "    This must be used with '-P' option and provides data on how long each SNMP data retrieval operation took\n";
	print "    The data is output together with 'performance' data so this can be used when calling from nagios\n";
	print "    (although I'd not expect it to be graphed, you can look at it from nagios status cgi)\n";
	print "\n";
}

sub usage {
	print $_."\n" foreach @_;
	print_usage();
	exit $ERRORS{'UNKNOWN'};
}

# display usage information
sub print_usage {
        print "Usage:\n";
        print "$0 [-s <snmp_version>] -H <host> (-C <snmp_community>) | (-l login -x passwd [-X pass -L <authp>,<privp>) [-p <port>] [-t <timeout>] [-O <base oid>] [-a <alert level>] [--extra_info] [--drive_errors -P <previous performance data> -S <previous state>] [-v [DebugLogFile] || -d [DebugLogFile]] [--debug_time] [--snmp_optimize] [-T megaraid|sasraid|perc3|perc4|perc5|perc6|mptfusion|sas6ir|sas6]\n";
        print "$0 --version | $0 --help (use this to see better documentation of above options)\n";
}

# process previous performance data - William
sub process_perf {
 my %pdh;
 foreach (split(' ',$_[0])) {
   if (/(.*)=(\d+)/) {
	print "prev_perf: $1 = $2\n" if $DEBUG;
	$pdh{$1}=$2 if $1 !~ /^time_/;
   }
 }
 return %pdh;
}

# print output and performance data
sub print_output {
   my ($out_status,$out_str)=@_;

   print "Megaraid $out_status";
   print " - $out_str" if $out_str;
   if (defined($opt_perfdata)) {
	print " |";
	# below is done to force notification on alert condition when you have notifications after 2 or more alerts
	if (scalar(keys %curr_perf)!=0 && (!defined($opt_prevstate) || scalar(keys %prev_perf)==0 || (defined($prev_state[0]) && $prev_state[0] ne 'OK' && (!defined($prev_state[1]) || $prev_state[1] eq 'HARD')))) {
		print " ". $_  ."=". $curr_perf{$_} foreach keys %curr_perf;
        }
	else {
		print " ". $_  ."=". $prev_perf{$_} foreach keys %prev_perf;
	}
	print " total_merr=".$total_merr if defined($total_merr);
	print " total_oerr=".$total_oerr if defined($total_oerr);
	if ($opt_debugtime) {
		print " time_".$_ ."=". $debug_time{$_} foreach keys %debug_time;
	}
   }
   print "\n";
}
