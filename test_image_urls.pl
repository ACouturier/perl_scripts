#! \usr\bin\perl
use strict;
use warnings;
use Getopt::Long;	# For extracting command line options
use WWW::Mechanize;

my $basedir = '';
my $outfile = '';
my $infile = '';
my $help = '';


my $result = GetOptions("base|b=s" => \$basedir,
                        "ifile|f=s" => \$infile,
                        "ofile|o=s" => \$outfile,
                        "help|h"   => \$help
                        );

sub usage() {
        print "This script requires an input file containing a list of URLs to test.\n";
        print "It will then output the results to the specified file.\n";

        print "Parameters :\n";
        print "\t--file    | -f => File to read URL list from\n";
        print "\t--ofile   | -o => File to read URL list from\n";

        print "e.g. perl test_image_urls.pl -f <input file> -o <output filename>\n\n";

        exit 0;
}

if ($help) {
        usage();
}

if (!($outfile && $infile)) { # Force all the required parameters
        usage();
}


# main function

{           

    my %imageUrls;
    my $urlCount = 0;
    my $filein;
    my $totalPassed = 0;
    my @badUrls;

    unless (open $filein, '<', $infile) {
        print "There was an error with file $infile\n\n";
        exit 1;
    };

    my @fileContents = <$filein>;  # read in the result file

    close $filein;

    foreach my $line (@fileContents) {      # go through every line
        chomp($line);

        if ($line =~ m/(^http.*?)\s?==/) {
            my $url = $1;
            chomp($url);
            $urlCount++;
            $imageUrls{$url} = 'FAILED';
        }
    }

    for my $testUrl (keys %imageUrls) {

        my @matches = $testUrl =~ /(http)/g;
        my $count = @matches;
 
        if ($count > 1) {
            print "Invalid URL : $testUrl";
            push(@badUrls, $testUrl);
            next;
        }

        my $mech = WWW::Mechanize->new();

        $mech->get( $testUrl );

        while (!($mech->success())) {
             sleep(100);
        }
 
        my $status = $mech->status();
        
        if ($status == 200) {
             $imageUrls{$testUrl} = 'PASSED';
             $totalPassed++;
	}

        print "Status code $status for $testUrl.\n";
    }

    print "\n\n"; 
    print "Test Completed!  See $infile for results.\n\n";

    print "$urlCount \ttotal image urls tested\n";
    print "$totalPassed \ttotal image urls passed!\n";
    print scalar @badUrls . "\ttotal BAD URLS\n";

    open (OUTFILE, "> $outfile");

    print OUTFILE "$urlCount \ttotal image urls tested\n";
    print OUTFILE "$totalPassed \ttotal image urls passed!\n";
    print OUTFILE "". scalar @badUrls . "\ttotal BAD URLS\n";
    print OUTFILE "\n\n";

    print OUTFILE "Bad URL List:\n";
    for my $bad (@badUrls) {
        print OUTFILE "$bad\n";
    }
 
    print OUTFILE "\nResults\n";

    for my $reqout (keys %imageUrls)  {
        print OUTFILE "$reqout ==> $imageUrls{$reqout}\n";
    }

    close (OUTFILE); 

}
###############################################################################
