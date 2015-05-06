#!/usr/bin/perl
use strict;
use warnings;
use Time::localtime;
use Time::Local;
use Net::SMTP;
use Getopt::Long;
use LWP::Simple;

my @errorrecip = ('sanitized');
my $toplaintext = "TestResultsStakeholders";
my $test = '';
my $link = '';
my $filename = '';
my $recipients = '';
my $maillist = '';
my @recipients;
my $help;

#where to send the results for DB Storage for use anywhere other than Rackspace
#my $httphost = 'http://sanitized/testauto/data/addrow.php';

#where to send the results for DB Storage for use at Rackspace
my $httphost = 'sanitized';
 
 
my $result = GetOptions("test|t=s" => \$test,
                        "link|l=s" => \$link,
                        "file|f=s" => \$filename,
                        "recip|r:s" => \$recipients,
                        "mail|m:s" => \$maillist, 
                        "help|h" => \$help
                        );

sub usage() {
	print "This script requires a test name, a results file to parse, a recipients\n";
	print "list and a location where the results will be permanently stored.\n\n";
	print "Parameters :\n";
	print "\t--test | -t => Name of test that is being executed.\n";
	print "\t--link | -l => Global link to permanent storage of results.\n";
	print "\t--file | -f => Results file to be parsed and mailed.\n";
	print "\t--recip | -r => semi-colon separated list of mail recipients.\n\n";
	print "\t--mail | -m => location of a file containing a list of mail recipients.\n\n";
	
	print "e.g. perl resultsmailer.pl -t 'test name' -f 'resultsfile' -l 'link to permanent location' -r 'recip1\@test.com;recip2\@test.com' -m project_maillist\n";
	
	exit 0;
}	

if ($help) {
	usage();
}

if (!($test && $link && $filename && ($recipients || $maillist))) { # Force all the required parameters
	usage();
}


# Put together and send the DB row to the remote server

sub senddbupdate {
    my $testname = shift;
    my $elapsedline = shift;
    my $sumline = shift;

    my $hours = 0;
    my $minutes = 0;
    my $seconds = 0;
    my $elapsed = 0;

    # handle a run that takes more than an hour
    if ($elapsedline =~ m/Finished in (\d+)h(\d+)m(\d+)./) {
        $hours = $1;
        $minutes = $2;
        $seconds = $3;
    } else {
        # handle the standard case
        $elapsedline =~ m/Finished in (\d+)m(\d+)./;
        $minutes = $1;
        $seconds = $2;
    }

    # how maby seconds it took
    $elapsed = ($hours * 3600) + ($minutes * 60) + $seconds;

    my $scen_count = 0;
    my $scen_passed = 0;
    my $scen_failed = 0;
    my $scen_skip = 0;
    
    my $steps_count = 0;
    my $steps_passed = 0;
    my $steps_failed = 0;
    my $steps_skip = 0;

    # scenarios and steps come in on seperate lines
    my @sumlines = split ("\n", $sumline);

    foreach my $line (@sumlines) {
        # extract the data from the Scenarios Line
        if ($line =~ m/scenario/) {
           # handle the case with a failure and skipped
           if ($line =~ m/(\d+) scenario.*\((\d+) failed, (\d+) skipped, (\d+) passed/) {
               $scen_count = $1;
               $scen_failed = $2;
               $scen_skip = $3;
               $scen_passed = $4;
           } elsif ($line =~ m/(\d+) scenario.*\((\d+) failed, (\d+) passed/) {
               #handle the case of passed and failed only
               $scen_count = $1;
               $scen_failed = $2;
               $scen_passed = $3;
           } elsif ($line =~ m/(\d+) scenario.*\((\d+) skipped, (\d+) passed/) {
               #handle the case of skipped and  passed only
               $scen_count = $1;
               $scen_skip = $2;
               $scen_passed = $3;
           } elsif ($line =~ m/(\d+) scenario.*\((\d+) failed, (\d+) skipped/) {
               #handle the case with failed and skipped cases
               $scen_count = $1;
               $scen_failed = $2;
               $scen_skip = $3;
           } elsif ($line =~ m/(\d+) scenario.*\((\d+) skipped/) {
               #handle the case with skipped cases only
               $scen_count = $1;
               $scen_skip = $2;
            } elsif ($line =~ m/(\d+) scenario.*\((\d+) failed/) {
               #handle the case with failed cases only
               $scen_count = $1;
               $scen_failed = $2;
              } else {
               #handle the case with no failures no skipped
               $line =~ m/(\d+) scenario.*\((\d+) passed/;
               $scen_count = $1;
               $scen_passed = $2;
           }
        } # now handle the steps
        if ($line =~ m/step/) {
           # handle the case with a failure and skipped
           if ($line =~ m/(\d+) step.*\((\d+) failed, (\d+) skipped, (\d+) passed/) {
               $steps_count = $1;
               $steps_failed = $2;
               $steps_skip = $3;
               $steps_passed = $4;
           } elsif ($line =~ m/(\d+) step.*\((\d+) failed, (\d+) passed/) {
               $steps_count = $1;
               $steps_failed = $2;
               $steps_passed = $3;
            } elsif ($line =~ m/(\d+) step.*\((\d+) skipped, (\d+) passed/) {
               #handle the case with no failure but skipped cases
               $steps_count = $1;
               $steps_skip = $2;
               $steps_passed = $3;
           } elsif ($line =~ m/(\d+) step.*\((\d+) failed, (\d+) skipped/) {
               #handle the case with failed and skipped cases
               $steps_count = $1;
               $steps_failed = $2;
               $steps_skip = $3;
           } elsif ($line =~ m/(\d+) step.*\((\d+) skipped/) {
               #handle the case with skipped cases only
               $steps_count = $1;
               $steps_skip = $2;
            } elsif ($line =~ m/(\d+) step.*\((\d+) failed/) {
               #handle the case with failed cases only
               $steps_count = $1;
               $steps_failed = $2;
            } else {
               #handle the case with no failures no skipped
               $line =~ m/(\d+) steps \((\d+) passed/;
               $steps_count = $1;
               $steps_passed = $2;
           }
        }

     } 

    # Was there a failure, 0 is failed, 1 is all Passed
    my $success = 1;
 
    if ($steps_failed > 0) {
        $success = 0;
    } 

    #put together the URL we are going to post the data to
    my $url = $httphost . "?test=$test&sc_count=$scen_count&sc_pass=$scen_passed&sc_fail=$scen_failed&sc_skip=$scen_skip&st_count=$steps_count&st_pass=$steps_passed&st_fail=$steps_failed&st_skip=$steps_skip&elapsed=$elapsed&success=$success"; 

    my $content = get($url);
    
    print "ERROR: Can't GET $url\n\n" if (! defined $content);
 
}

sub sendmessage {
    my $subject = shift;
    my $text = shift;
    my @recip = @{$_[0]};
    
    # use the following line if you are testing this script 
    # inside the Firewall
    #my $smtp = Net::SMTP->new('sanitized, Timeout => 60);
    
    # use the following line when using this on a Jenkins Server
    my $smtp = Net::SMTP->new('localhost', Timeout => 60);

    $smtp->mail('sanitized');  # this is the FROM
    $smtp->to(@recip);

    $smtp->data();
    $smtp->datasend("To:$toplaintext\n");
    $smtp->datasend("Subject:$subject\n");

    $smtp->datasend("\n");

    $smtp->datasend($text);
    $smtp->dataend();
    $smtp->quit;
    
    print "Message has been sent!\n";
    print "Email recipients are:\n";
	foreach(@recip)
	{
    	    print "$_\r\n";
	}
    print $subject . "\n";
    print $text . "\n";
}

if ($recipients) {
    # Split the recipient list into an array
    @recipients = split(";", $recipients);	
    chomp(@recipients);
}

if ($maillist) {
    my $mailin;

    unless (open $mailin, '<', $maillist) {
       my $deadsubject = "$test : FAILED!";
       my $deadbody = "$deadsubject\n\n";
       $deadbody .= "Could not read mail list file $maillist\n\n";
       $deadbody .= "The Error returned was : $!\n\n"; 
       $deadbody .= "Thanks,\n";  # sign off
       $deadbody .= "\tThe Automated Test Team\n\n";
       
       sendmessage($deadsubject, $deadbody, \@errorrecip); # send the message...

       exit 1;
    };

   my @maillist = <$mailin>;
   
   close $mailin;       

   foreach my $name (@maillist) {
       # skip commented out mail addresses in the file
       if ($name =~ m/^\s*#/) {
           #do nothing
       } else {
           push(@recipients, $name);
       }
   }
 
}

my $summaryline = '';
my $timeline = '';
my $osline = '';
my $infile;

unless (open $infile, '<', $filename) {
   my $deadsubject = "$test : FAILED!";
   my $deadbody = "$deadsubject\n\n";
   $deadbody .= "There was an error with file $filename\n\n";
   $deadbody .= "The Error returned was : $!\n\n"; 
   $deadbody .= "Thanks,\n";  # sign off
   $deadbody .= "\tThe Automated Test Team\n\n";

   sendmessage($deadsubject, $deadbody, \@errorrecip); # send the message...

   exit 1;
};

my @content = <$infile>;  # read in the result file

close $infile;

foreach my $line (@content) {                        # go through every line
	if ($line =~ m/(Mozilla\/.*?)<\/li>/ ) { # grab the system information
            $osline = $1;
        }
	if ($line =~ m/getElementById\('duration'\)/ ) { # only care if the line referenced getElementbyID and duration
		my @parts = split(';', $line);               # break up the line into usable parts
		chomp(@parts);
		
		foreach my $part (@parts) {                  # go through every part
			
			if ($part =~ m/getElementById\('duration'\).*= "(.*)"/) {  # grab the duration information
				$timeline = $1;
			}
			if ($part =~ m/getElementById\('totals'\).*= "(.*)"/) {    # grab the totals information
				$summaryline = $1;
			}
                }
	}
}

my $mailsubject = "$test : ";  # start the subject line
my $failedcount = 1;
my $mailbody = "";
my $passfail = "PASSED!";

$summaryline =~ s/<br \/>/\n/g;   # remove the HTML br tag from the summary information and replace it with a linebreak

if ($summaryline =~ m/\((.*) failed,/) {  # how many failed tests
	$failedcount = $1;
	chomp($failedcount);
	
	$failedcount = scalar($failedcount); # text to number

	if ($failedcount > 0) { # where there any failures? Finish the subject line
		$passfail = "FAILED!"
	} 
}

$mailsubject .= $passfail;

$mailbody = $mailsubject . "\n\n";  # add the subject as the first line of the body

if ($osline) {

    my $os = '';
    my $browser = '';

    # Deal with the fact that MS can not play well with others.... 
    if ($osline =~ m/MSIE/) {
        $osline =~ m/\((.*?)\)/;
        
        my @UAParts = split(';', $1);
        $os = join(";", $UAParts[2], $UAParts[3], $UAParts[4]);
        $browser = join(";", $UAParts[1], $UAParts[0], $UAParts[5]);
    } else {
        $osline =~ m/\((.*?)\) (.*)$/;
        $os = $1;
        $browser = $2;
    }

    chomp($os);
    chomp($browser);

    $mailbody .= "OS Info : $os\n";
    $mailbody .= "Browser Info : $browser\n\n";
};

$mailbody .= "$summaryline\n\n";     # add the summary line

$timeline =~ s/<strong>//g;         # remove the strong HTM tags
$timeline =~ s/<\/strong>//g;

$mailbody .= "$timeline\n\n";       # add the time elapsed

senddbupdate($test, $timeline, $summaryline);

# add in the link to the permanent storage location for the results
$mailbody .= "The complete results are can be found here:\n";
$mailbody .= "$link\n\n";

$mailbody .= "Thanks,\n";  # sign off
$mailbody .= "\tThe Automated Test Team\n\n";

sendmessage($mailsubject, $mailbody, \@recipients); # send the message...

exit 0;
