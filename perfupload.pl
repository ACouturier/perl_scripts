#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use LWP::Simple;
use POSIX;

my $project = '';
my $filename = '';
my $datein;
my $notein = '';
my $duration;
my $help;

#where to send the results for DB Storage
my $httphost = 'http://sanitized/perf/data/addrow.php';
 
 
my $result = GetOptions("project|p=s" => \$project,
                        "file|f=s" => \$filename,
                        "date|d:s" => \$datein,
                        "note|n:s" => \$notein,
                        "dur|u:i" => \$duration,
                        "help|h" => \$help
                        );

sub usage() {
	print "This script requires a project name, a results file to parse, a recipients\n";
	print "list and a location where the results will be permanently stored.\n\n";
	print "Parameters :\n";
	print "\t--project | -p => Name of project that is being tested.\n";
	print "\t--file | -f => Results file to be parsed and uploaded.\n";
	print "\t--date | -d => Date of the test run, defaults to NOW if not set.\n";
	print "\t--note | -n => Notes, description of the test run.\n";
	print "\t--dur |  -u => Duration of the test run.\n\n";
	
	print "e.g. perl perfupload.pl -p 'project name' -f 'resultsfile' -d '2013-12-12 09:01:00' -n '1000 auth users only' -u 3600\n\n";
	
	exit 0;
}	

if ($help) {
	usage();
}

if (!($project && $filename )) { # Force all the required parameters
	usage();
}


# Put together and send the DB row to the remote server

sub senddbupdate {
    my $date = shift;
    my $proj = shift;
    my $dur = shift;
 
    my $infile;

    unless (open $infile, '<', $filename) {
        print "There was an error with file $filename\n\n";
        exit 1;
    };

    my @filecontents = <$infile>;  # read in the result file

    close $infile;
    
    my $page      = '';
    my $count     = 0;
    my $average   = 0;
    my $median    = 0;
    my $nperc     = 0;
    my $min       = 0;
    my $max       = 0;
    my $perc      = 0.0;
    my $tps       = 0.0;
    my $bandwidth = 0.0;

    foreach my $line (@filecontents) {      # go through every line
         if ($line =~ m/sampler_label,/ ) { # skip the header
             next;  # do nothing
         }

         $page      = '';
         $count     = 0;
         $average   = 0;
         $median    = 0;
         $nperc     = 0;
         $min       = 0;
         $max       = 0;
         $perc      = 0.0;
         $tps       = 0.0;
         $bandwidth = 0.0;

         chomp($line);

         my @columns = split(',', $line);
 
         $page      = $columns[0];
         $count     = $columns[1];
         $average   = $columns[2];
         $median    = $columns[3];
         $nperc     = $columns[4];
         $min       = $columns[5];
         $max       = $columns[6];
         $perc      = $columns[7];
         $tps       = $columns[8];
         $bandwidth = $columns[9];
         
         chomp($bandwidth);

         #put together the URL we are going to post the data to
         my $url = $httphost . "?date=$date&project=$proj&page=$page&count=$count&average=$average&median=$median&nperc=$nperc&min=$min&max=$max&perc=$perc&tps=$tps&bandwidth=$bandwidth&duration=$dur";
        
         if ($notein) {
            $url = $url . "&note=$notein";
         }

         my $content = '';
         $content = get($url);

         #print $url . "\n"; 
         #print $content . "\n";
   
         print "ERROR: Can't GET $url\n\n" if (! defined $content);
     };


}

if (! defined $datein) {
    $datein = strftime "%Y-%m-%d %H:%M:%S", localtime;
}

if (! defined $duration) {
    $duration = 3600;
}

senddbupdate($datein, $project, $duration);

exit 0;
