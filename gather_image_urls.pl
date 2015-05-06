#! \usr\bin\perl
use strict;
use warnings;
use File::Find;		# For file finding
use File::Path;		# For directory path creation
use Getopt::Long;	# For extracting command line options

my $basedir = '';
my $outfile = '';
my $help = '';


my $result = GetOptions("base|b=s" => \$basedir,
                        "file|f=s" => \$outfile,
                        "help|h"   => \$help
                        );

sub usage() {
        print "This script will traverse a directory (recursively) of HTML files, generating a list of image URLs\n";

        print "Parameters :\n";
        print "\t--basedir | -b => Folder of files to be parsed and summarised.\n";
        print "\t--file    | -f => File to write URL list to\n";

        print "e.g. perl gather_image_urls.pl -d <source directory> -f <output filename>\n\n";

        exit 0;
}

if ($help) {
        usage();
}

if (!( $outfile )) { # Force all the required parameters
        usage();
}


###############################################################################
# Main routine
###############################################################################

{
	# Find all files (store names indexed by path)
	my %fileNamesByPath;
	find(
		sub
		{	# Skip the base directory
			if(-d)
			{	return;}
			$fileNamesByPath{$File::Find::name}=$_;
                }
		,$basedir
        );

	# Arrange file paths so deepest level done first
	# (Since paths to deeper levels may change with higher level directories
	#  being renamed. Doing it this way not simply by 'File::finddepth'
	#  because that not allow pruning unlike 'File::find'.)
	my @filePaths = reverse(sort(keys %fileNamesByPath));
        
        my %badFiles;
        my $filecount = 0;
        my %imageUrls;
        my $infile;
        my $totallines = 0;
        my $imagecount = 0;

        foreach my $filein (@filePaths) {
            
            unless (open $infile, '<', $filein) {
                print "There was an error with file $filein\n\n";
                next;
            };

            $filecount++;

            my @filecontents = <$infile>;  # read in the result file

            close $infile;

            foreach my $line (@filecontents) {      # go through every line
                chomp($line);

                $totallines++;

                while ($line =~ m/img src=\"(.*?)\"\s/g) {
                    my $image = $1;
                    chomp($image);
        

                    my @matches = $image =~ /(http)/g;
                    my $count = @matches;

                    if ($count != 1) {
                        $badFiles{$filein}++;  #Write the filename to the list, increment if more than one
                        next;
                    }
                    
            
                    $imagecount++;
                    $imageUrls{$image}++;
                }
            }
        } 

    
        open (OUTFILE, "> $outfile");
 
            print OUTFILE "$filecount \ttotal files of html scanned\n";
            print OUTFILE "$totallines \ttotal lines of html scanned\n";
            print OUTFILE "$imagecount \ttotal image urls found\n";
            print OUTFILE scalar(keys %imageUrls) . "\tunique image URLs found\n\n";

            print OUTFILE "Files with problem image URLs:\n\n";
  
            for my $badFile (keys %badFiles) {
                print OUTFILE "$badFile ==> $badFiles{$badFile} Errors.\n";
            }
            
            print OUTFILE "\n\n";
            print OUTFILE "Image URLs:\n\n";

            for my $reqout ( sort { $imageUrls{$b} <=> $imageUrls{$a} || $b cmp +$a } (keys %imageUrls))  {
                print OUTFILE "$reqout ==> $imageUrls{$reqout} requests.\n";
            }

       close (OUTFILE); 

}
###############################################################################
