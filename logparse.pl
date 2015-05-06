#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Time::Local;

my $filename = '';
my $help = '';
my $topx = 20;
my $days = 1; 

my $result = GetOptions("file|f=s" => \$filename,
                        "topx|t:i" => \$topx,
                        "days|d:i" => \$days,
                        "help|h"   => \$help
                        );

sub usage() {
	print "This script requires a results file to parse and will display the top 20 hits";
	
        print "Parameters :\n";
	print "\t--file | -f => Results file to be parsed and summarised.\n";
	print "\t--topx | -t => How many to display.\n";
	print "\t--days | -d => How many days of data to include.\n";
	
	print "e.g. perl logparse.pl -f <filename> -t 10 -d 1\n\n";
	
	exit 0;
}	

if ($help) {
	usage();
}

if (!( $filename )) { # Force all the required parameters
	usage();
}

sub formatTime {
    my $time_in = shift;

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime($time_in);
    my $nice_timestamp = sprintf ( "%04d-%02d-%02d %02d:%02d:%02d",
                                   $year+1900,$mon+1,$mday,$hour,$min,$sec);

    return $nice_timestamp;
}

sub getStartTime {

    my $st_time = time;
    $st_time = $st_time - (86400 * $days);
    
    return $st_time;
}

sub getNiceTime {

    my $nice_timestamp = formatTime(time);
 
    return $nice_timestamp;
}

sub convertTime {
    my $date_in = shift;

    my ($mday,$mon,$year,$hour,$min,$sec) = split(/[\/.:]+/, $date_in);

    my @mon_array = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
    my $search_for = "$mon";
    my( $month )= grep { $mon_array[$_] eq $search_for } 0..$#mon_array;

    my $time = timelocal($sec,$min,$hour,$mday,$month,$year);

    return $time;
}

sub parseFile {
 
    my $infile;
    my %count_of;
    my $counter; 
    my $totallines = 0;
    my $total404s = 0;
    my $request = '';
    my $start_time = getStartTime();

    unless (open $infile, '<', $filename) {
        print "There was an error with file $filename\n\n";
        exit 1;
    };

    my @filecontents = <$infile>;  # read in the result file

    close $infile;

    foreach my $line (@filecontents) {      # go through every line

        if ($line =~ m/\[(.*)\s.*\]/) {
            my $file_time = $1;

	    chomp($file_time);

	    my $line_time = convertTime($file_time);
		
	    next if $line_time < $start_time;
            
            $totallines++;

	    chomp($line);
		
	    if ($line =~ m/\ 404\ /) {
                $total404s++;
	        $line =~ m/"GET (.*)\ HTTP/;
	        $request = $1;
	        $count_of{$request}++;
	    }
        }
    }

    print "\n\n";
    my $timestamp = getNiceTime();
    print "Executed at $timestamp.\n";
    print "All lines checked were more recent than " . formatTime($start_time) . "\n\n";
    print "$totallines lines in the the file met the criteria.\n";
    print "$total404s 404 requests in file.\n";
    
    my $perc404 = 0;
    if ($totallines > 0) {
        $perc404 = ($total404s / $totallines) * 100;
    }

    print sprintf("%.2f", $perc404) . " of the requests in log were 404's\n\n";
 
    print "Top $topx requested 404 URLs and their counts: \n\n";
    $counter = 1;
    for my $reqout (sort { $count_of{$b} <=> $count_of{$a} || $b cmp +$a } (keys %count_of) ) {
        print "$reqout ==> $count_of{$reqout} requests.\n";
        if ($counter++ >= $topx) { last; };
    }
}


parseFile();

exit 0;
