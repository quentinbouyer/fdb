#!/usr/bin/perl -w
## Original version to 1.03.2 made by Cedric HUSIANYCIA
## 1.01-2 adding a loop to fill the hash table with tab entries
## 1.01-3 Uniligne "if" conditions with $flag value
## 1.01-4 Help updated
## 1.01-5 Adding sub-function ... looks cleaner
## 1.02-1 Now support a couplet
## 1.02-2 modified parsing_ips
## 1.03-1 adding import and export config capabilities
## 1.03-2 You don't need the -i option if you read a dumped config with -r ...

## Made by Quentin Bouyer
## 2.0 Lot of correction due to modif of show pd output - change display


use Data::Dumper;
use Getopt::Long;
use Net::SSH::Expect;
use Storable;

my $tmp         = 60;
my $activity    = "read";
my $Debug       = 0;
my $help        = 0;
my $Version     = "2.0";
my $SFA_IPs     = "";
my $user        = "user";
my $passwd      = "user";
my $short       = 0;
my $write_c     = "";
my $read_c      = "";
my %hash;

##
# GetOptions
##

sub getCLOptions {
        Getopt::Long::Configure('noignore_case');
        unless (
                GetOptions (
                                'debug|d'               => \$Debug,
                                'help|h'                => \$help,
                                'sfa_ips|i=s'           => \$SFA_IPs,
                                'activity|a=s'          => \$activity,
                                'tmp|t=s'               => \$tmp,
                                'user|u=s'              => \$user,
                                'passwd|p=s'            => \$passwd,
                                'short|s'               => \$short,
                                'write_config|w=s'      => \$write_c,
                                'read_conf|r=s'         => \$read_c,
                         )
              )
      {
          die "Error : Incorrect option \n";
      }
}

##
# Print help
##

sub print_help {

    print <<EOF;

        Script name             : $0 - Chasing slow disks !
        Version                 : $Version
        Description             : This script will report you an output like a "show pd * counters" on DDN S2A products.

      Options:

        --help  | -h            Print this help.

        --debug | -d            Debug mode

        --sfa_ips | -i          This option is a mandatory option that allow you to specify the IP Addresses of you controllers.
                                The IP addresses must be separated by the dash caracter.

                                Example :

                                $0 -i "10.0.0.2-10.0.0.3"

                                --> 10.0.0.2 is my sfa1 and 10.0.0.3 is the second sfa.

        --activity | -a         This option allows you to select if you want read or write delay values. Due to the current SFA OS
                                architecture, you can't just have both. The default is read, for write use "-a write"

        --tmp | -t              This option is the time in seconds while you are gathering informations. Default is 60 seconds.

        --user | -u             User to use to login your controllers. Default is "user".

        --password | -p         Password to use to login your controllers. Default is "user".

        --write_conf | -w       Write the gathered configuration to a file - this will allow you to re-use the exact same config
                                without to rescan the configuration - you'll save a couple of minutes each run.

        --read_conf | -r        Read the exported dump from the "--write_conf" option.

        Contact : Quentin Bouyer ( quentin.bouyer\@eviden.com )

EOF
}

##
# Print result and hash table if debug is on.
##
sub flushing {
        print Dumper(\%hash) if ($Debug);

         foreach my $vd (sort {$a <=> $b} keys(%{$hash{"vd"}})) {
                print "Virtual Disk ".$vd." Delay - Raid ".$hash{"vd"}{$vd}{"raid"}." (Pool : ".$hash{"vd"}{$vd}{"pool"}." - Name : ".$hash{"vd"}{$vd}{"name"}." )\n\n";
                print "PD(Idx)\t\tAVG(us)\t\t4ms\t8ms\t16ms\t32ms\t64ms\t128ms\t256ms\t512ms\t1024ms\t4096ms\t+4096ms\n";
                foreach my $id (1...$hash{"ctl"}) {
                        foreach my $pd (sort {$a <=> $b} keys(%{$hash{"vd"}{$vd}{"pd_list"}})) {
                                print $hash{"vd"}{$vd}{"pd_list"}{$pd};
                                print "\t\t".$hash{"vd"}{$vd}{"pd_list"}{$pd}{$id}{"AVG(ms)"};
                                print "\t\t".$hash{"vd"}{$vd}{"pd_list"}{$pd}{$id}{4};
                                print "\t".$hash{"vd"}{$vd}{"pd_list"}{$pd}{$id}{8};
                                print "\t".$hash{"vd"}{$vd}{"pd_list"}{$pd}{$id}{16};
                                print "\t".$hash{"vd"}{$vd}{"pd_list"}{$pd}{$id}{32};
                                print "\t".$hash{"vd"}{$vd}{"pd_list"}{$pd}{$id}{64};
                                print "\t".$hash{"vd"}{$vd}{"pd_list"}{$pd}{$id}{128};
                                print "\t".$hash{"vd"}{$vd}{"pd_list"}{$pd}{$id}{256};
                                print "\t".$hash{"vd"}{$vd}{"pd_list"}{$pd}{$id}{512};
                                print "\t".$hash{"vd"}{$vd}{"pd_list"}{$pd}{$id}{1024};
                                print "\t".$hash{"vd"}{$vd}{"pd_list"}{$pd}{$id}{4096};
                                print "\t".$hash{"vd"}{$vd}{"pd_list"}{$pd}{$id}{+4096}."\n";
                        }
                }
                print "\n";
        }
}


##
# This function will parse the sfa_ips option and store it in our main hash table
##

sub parsing_ips {
        print "IP Address(es) of your controller(s) : ".$SFA_IPs."\n";
        my @listsfa = split(/\-/, $SFA_IPs);
        my $counter = 1;
        foreach my $sfa (@listsfa) {
                if ($sfa =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/) {
                        $hash{"sfa".$counter} = $1;
                        $counter++;
                }
        }
        $counter--;
        $hash{"ctl"} = $counter;
}

##
# This function will parse the show pd * all command to store the slots where are the disks belonging to
##

sub pd_all {
        my $ssh = shift;
        my $pd_all = $ssh->exec("show pd * all");
        my @tab = split (/\n/, $pd_all);
        chomp(@tab);
        my $pdidx = 0;
        foreach my $line (@tab) {
                if ($line =~ /^\s+Index\:\s+(\d+)/) {
                        $pdidx = $1;
                }
                if ($line =~ /Disk Slot\:\s+\d{1,2}\s+\((.*)\)/i) {
                        $hash{"pdlist"}{$pdidx} = $1;
                        $pdidx = 0;
                }
        }
        return ($ssh);
}

##
# Connection to our SFA(s)
##

sub connect_to_sfa {

        my $id = shift;
        my $ssh = Net::SSH::Expect->new (
                host => $hash{"sfa".$id},
                password => $passwd,
                user => $user,
                raw_pty => 1);

        return ($ssh);
}

##
# This function will initiate a login to the controller
##

sub test_connect {

        my $ssh = shift;

        my $login_output = $ssh->login();
        if ($login_output !~ /RAID\[\d\]\$/) {
                die "Login has failed. Login output was $login_output";
        }

        return ($ssh);

}

##
# This function will initiate our read of write counters
##

sub init_counters {

        my $ssh = shift;

        $ssh->exec("show pd * count ".$activity."_l");

        return ($ssh);
}

##
# This function will be used to fill up our hash table
##

sub filling_hash {

        my $ssh = shift;

        my $vd = $ssh->exec("show vd");
        my @tab = split(/\n/, $vd);
        my $flag = 0;
        foreach my $line (@tab) {
                $flag = 0 if ($line =~ /^\r$/ );
                if ($flag) {
                        $line =~ s/\r//;
                        my @tmp = split(/ +/, $line);

                        $hash{"vd"}{$tmp[1]}{"name"} = $tmp[2];

                        $hash{"vd"}{$tmp[1]}{"pool"} = $tmp[4];

                        $hash{"vd"}{$tmp[1]}{"raid"} = $tmp[5];
                }
                $flag++ if ($line =~ /-{80}/);
        }

        return ($ssh);
}

##
# Function used to make the translation between VDs, pools and PDs Indexes
##

sub vd_pd {

        my $ssh = shift;

        foreach my $vd (sort {$a <=> $b} keys(%{$hash{"vd"}})) {
                my $cmd = "show pool ".$hash{"vd"}{$vd}{"pool"}." pd";
                my $pool_pd = $ssh->exec($cmd);
                my @tab = split(/\n/, $pool_pd);
                my $flag = 0;
                my $pdid = 0;
                foreach my $line (@tab) {
                        $flag = 0 if ($line =~ /^\r$/ );

                        if (($flag) && !($line =~ /-{80}/) && ($flag < 2)) {
                                $line =~ s/\r//;

                                my @tmp = split(/ +/, $line);

                                if ($line =~ /SSD/ ) {
                                        $hash{"vd"}{$vd}{"pd_list"}{$pdid} = $tmp[15];
                                } else {
                                        $hash{"vd"}{$vd}{"pd_list"}{$pdid} = $tmp[14];
                                }
                                $pdid++;
                        }
                        $flag++ if ($line =~ /-{80}/ );
                }
        }
        return ($ssh);
}

##
# This function is used to get the results in our main hash table
##

sub getting_datas {

        my $id = shift;
        my $ssh = shift;

        my $cmd = "show pd * count ".$activity."_l";
        my $all_delay = $ssh->exec($cmd);

        my @tab_delay = split(/\n/, $all_delay);

        my $flag = 0;
        foreach my $line (@tab_delay) {
                $flag = 0 if ($line !~ /^ / );
                if ($flag) {
                        $line =~ s/\r//;
                        my @tmp_delay = split(/ +/, $line);
                        foreach my $vd (sort {$a <=> $b} keys(%{$hash{"vd"}})) {
                                foreach my $pd (sort {$a <=> $b} keys(%{$hash{"vd"}{$vd}{"pd_list"}})) {
                                        if ($tmp_delay[1] eq $hash{"vd"}{$vd}{"pd_list"}{$pd}) {
                                                $hash{"vd"}{$vd}{"pd_list"}{$pd}{$id}{"AVG(ms)"} = $tmp_delay[2];
                                                $hash{"vd"}{$vd}{"pd_list"}{$pd}{$id}{"+4096"} =  $tmp_delay[14];
                                                foreach my $t (3...13) {
                                                                my $h = 2 ** ($t - 1);
                                                                $hash{"vd"}{$vd}{"pd_list"}{$pd}{$id}{$h} = $tmp_delay[$t];
                                                }
                                        }
                                }
                        }
                }
                $flag++ if ($line =~ /-{80}/);
        }

        return ($ssh);
}

##
# Here is where we will talk with our SFA !
##

sub expecting {

        my @ssh;

        unless ($read_c && -f $read_c) {
                foreach my $sfa (1...$hash{"ctl"}) {
                        $ssh[$sfa] = connect_to_sfa($sfa);
                        $ssh[$sfa] = test_connect($ssh[$sfa]);
                        if ($sfa == 1) {
                                $ssh[$sfa] = filling_hash($ssh[$sfa]);
                                $ssh[$sfa] = pd_all($ssh[$sfa]);
                                $ssh[$sfa] = vd_pd($ssh[$sfa]);
                        }
                        $ssh[$sfa] = init_counters($ssh[$sfa]);
                }

                if ($write_c ne "") {
                        store (\%hash, $write_c);
                        print "Configuration dumped to file name ".$write_c."\n";
                        print "Please use the option \"-r ".$write_c."\" to retore it.\n";
                        exit;
                }
        }

        if ($read_c && -f $read_c) {
                print "Reading the config file : ".$read_c." ... wait a moment please.\n";
                my $hashret = retrieve($read_c);
                %hash = %{$hashret};
                foreach my $sfa (1...$hash{"ctl"}) {
                        $ssh[$sfa] = connect_to_sfa($sfa);
                        $ssh[$sfa] = test_connect($ssh[$sfa]);
                        $ssh[$sfa] = init_counters($ssh[$sfa]);
                }
        }
        print "Now waiting for ".$tmp." seconds ...\n";
        sleep($tmp);

        foreach my $sfa (1...$hash{"ctl"}) {
                $ssh[$sfa] = getting_datas($sfa, $ssh[$sfa]);
                $ssh[$sfa]->close();
        }
}

##
# Main function ... Let's start with that.
##

sub main {

        if (scalar(@ARGV)) {
                getCLOptions();
        } else {
                print_help();
                exit 1;
        }

        if ($help) {
                print_help();
                exit 1;
        }
        $Debug = "DEBUG" if ( $Debug );
        parsing_ips unless ($read_c);
        expecting;
        flushing;
}

main;
