#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;	# For extracting command line options
use WWW::Mechanize;
use Time::Local;

my $user = 'testauto';
my $pass = 'testauto2EA!';

my $outfile = '';
my $infile = '';
my $help = '';


my $result = GetOptions("ifile|f=s" => \$infile,
                        "ofile|o=s" => \$outfile,
                        "help|h"   => \$help
                        );

sub usage() {
        print "This script requires an input file containing a list of sites to check\n";
        print "for version numbers in the build.txt file on the local servers.\n";
        print "It will then output the results to the specified file as an HTML page.\n";

        print "Parameters :\n";
        print "\t--ifile\t| -f => File to read URL list from\n";
        print "\t--ofile\t| -o => File to read URL list from\n";

        print "e.g. perl get_build_list.pl -f <input file> -o <output filename>\n\n";

        exit 0;
}

if ($help) {
        usage();
}

if (!($outfile && $infile)) { # Force all the required parameters
        usage();
}

sub formatTime {
    my $time_in = shift;

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime($time_in);
    my $nice_timestamp = sprintf ( "%04d-%02d-%02d %02d:%02d:%02d",
                                   $year+1900,$mon+1,$mday,$hour,$min,$sec);

    return $nice_timestamp;
}

sub getNiceTime {

    my $nice_timestamp = formatTime(time);

    return $nice_timestamp;
}

sub parse_version {
    my $versionInfo = shift;
    
    chomp($versionInfo);

    if ($versionInfo =~ m/build_id=(.*)\S?\n/) {
        $versionInfo = ($1);
    }

    return $versionInfo;
}

sub generate_html {
    my %urlListIn = @_;

    my %sites;

    for my $req (keys %urlListIn)  {
        my $version = $urlListIn{$req};

        $req =~ m/http:\/\/(.*?)\.(.*?)\./;

        my $environment = $1;
        my $site = $2;

        $sites{$site}{$environment} = $version;
    }

    print "Update Completed!  See $outfile for results.\n";

    open (OUTFILE, "> $outfile");
    
    print OUTFILE "<html> <body> <h1>Welcome to the Site Build Version Page</h1> <br>\n";

    print OUTFILE "Last Run : " . getNiceTime() . "<br>";

    for my $site (sort { $sites{$b} <=> $sites{$a} || $b cmp +$a } (keys %sites)) {
        print OUTFILE "<h2>" . uc($site) . "</h2>";

        print OUTFILE "<table border=\"1\" cellspacing=\"2\" cellpadding=\"2\">\n";
        print OUTFILE "<tr>\n";
        print OUTFILE "<td><font face=\"Arial, Helvetica, sans-serif\"><b>Environment</b></font></td>\n";
        print OUTFILE "<td><font face=\"Arial, Helvetica, sans-serif\"><b>Build Number</b></font></td>\n";

        for my $environment (keys $sites{$site}) {
            print OUTFILE "</tr>\n";
            print OUTFILE "<td><font face=\"Arial, Helvetica, sans-serif\"><a href='http://$environment.$site.com/build.txt'>$environment</a></font></td>\n";
            print OUTFILE "<td><font face=\"Arial, Helvetica, sans-serif\">$sites{$site}{$environment}</font></td>\n";

            print OUTFILE "</tr>\n";
        }

        print OUTFILE "</table><br>\n";
    }

    print OUTFILE "</body> </html>";

    close (OUTFILE); 

}

# main function

{           

    my %urlList;
    my $filein;

    unless (open $filein, '<', $infile) {
        print "There was an error with file $infile\n\n";
        exit 1;
    };

    my @fileContents = <$filein>;  # read in the result file

    close $filein;

    foreach my $line (@fileContents) {      # go through every line
        chomp($line);

        if ($line =~ m/(^http.*)/) {
            my $url = $1;
            chomp($url);
            if ($url =~ m/\/$/) {
                $url = $url . 'build.txt';
            } else {
                $url = $url . '/build.txt';
            }
            $urlList{$url} = 'FAILED';
        }
    }

    for my $testUrl (keys %urlList) {

        my $mech = WWW::Mechanize->new(autocheck => 0);

        $mech->credentials($user, $pass);

        my $result = $mech->get( $testUrl );

        if ($result->is_success) {

            my $status = $mech->status();
       
            if ($status == 200) {
                my $verInfo = $mech->content(format => 'text');

                $verInfo = parse_version($verInfo);

                $urlList{$testUrl} = $verInfo;
	    }

            #print "Status code $status for $testUrl.\n";

        } else {
            #print "Error retrieving $testUrl\n";
        }
    }

    generate_html(%urlList);

}
###############################################################################
