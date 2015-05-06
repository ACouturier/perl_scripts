#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Time::Local;

$| = 1;

my $name = 'varnishd';

my $help = '';
my $prompt = '';
my $sleep = 60;
my $threshold = 600;

my $result = GetOptions("prompt|p=s" => \$prompt,
                        "sleep|s:i"  => \$sleep,
                        "thresh|t:i" => \$threshold,
                        "help|h"     => \$help
                        );

sub usage() {
	print "This script will scan processes for the named process (default varnishd), tell you the pid of the process that\n";
	print "has the most CPU time, and ask if you want to kill it unless you specified no prompt.\n";
	
        print "Parameters :\n";
	print "\t--prompt | -p => Y for yes, N for JFDI\n";
	print "\t--sleep  | -s => In seconds, default is 60\n";
	print "\t--thresh | -t => In seconds, default is 600\n";
	
	print "e.g. perl reaper.pl -p Y -s 120 -t 600\n\n";
	
	exit 0;
}	

if ($help) {
	usage();
}

if (!( $prompt )) { # Force all the required parameters
	usage();
}

sub getSeconds {
    my $time = shift;
    my $totalseconds = 0;
 
    my ($hours, $minutes, $seconds) = split(/:/, $time);

    $totalseconds = ($hours * 3600) + ($minutes * 60) + $seconds;

    return $totalseconds;
    
}

sub getHighestCPU {
    my (@array) = @_;
    my $highpid = 0;
    my $highseconds = 0;

    foreach my $line (@array) {
        chomp($line);

        my @items = split(/ +/, $line);
     
        my $pid = $items[1];
        my $parentpid = $items[2];
        my $lwppid = $items[3];

        # if lwpid matches either of the first two pids, this is not a killable child
        if (($lwppid != $pid) && ($lwppid != $parentpid)) {
 
            my $seconds = 0;
            $seconds = getSeconds($items[8]);
            
            # is this the new king?
            if (($seconds >= $threshold) && ($seconds > $highseconds)) {
                 $highseconds = $seconds;
                 $highpid = $items[3];
            }
        }
    }
    return ($highpid, $highseconds);
}

sub killpid {
    my $deadpid = shift;

    print "Killing $deadpid\n"; 

    system("kill", '-9',  $deadpid);

    if ( $? == -1 ) {
        print "command failed: $!\n";
    } else {
        printf "command exited with value %d\n", $? >> 8;
    }   
    
}

###############################################################
# Main 
###############################################################
chomp($prompt);

while (1 == 1) {

    my $command = "ps -eLf | grep $name"; # put together the command line

    my @data = `$command`;  # run it

    my ($highestpid, $highseconds) = getHighestCPU(@data); # do we have a runaway
    
    if ($highestpid != 0) {  # will be 0 if nothing is over threshold or killable

        print "$highestpid is over the with $highseconds seconds.\n";

        if (lc($prompt) ne 'n') {   # does someone else want to be responsible??
            print "Would you like to kill $highestpid? (y/n):\n";
            my $check = <STDIN>;
            chomp($check); 

            if (lc($check) eq 'y') {
                killpid($highestpid);  # kill it with fire
            }

        } else {
            killpid($highestpid);  # kill it with fire
        }
    
    } 
    sleep($sleep);    

}

exit 0;



