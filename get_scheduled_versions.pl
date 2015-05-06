#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;	# For extracting command line options
use JSON qw( decode_json );
use Time::Local;
use Net::SMTP;
use Data::Dumper;               # Perl core module

#Mail Constants
my $mailserver  = 'sanitized';
my @recipients  = ('sanitized);
my @errorrecip  = ('sanitized');
my $mail_from   = 'sanitized';
my $toplaintext = 'sanitized';
my $mailsubject = "Running Deployment Schedule (as of " . getNiceTime() . ")";

# JIRA Constants
my $family_gwp    = 'sanitized;
my $family_p4f    = 'sanitized';
my $GWPbaseurl    = "sanitized";
my $P4Fbaseurl    = "sanitized";
my $apiurl        = "sanitized";
my $username      = "sanitized";
my $password      = "sanitized";
my $stat_projcode = "sanitized";

# HTML color constants
my $bgcolor_header = "#61A1FA";
my $bgcolor_stat   = "#F5B356";
my $bgcolor_table  = "#BCEAF7";

# Command line parameters
my $cfgfile  = '';
my $help     = '';

my $result = GetOptions("cfg|c=s"  => \$cfgfile,
                        "help|h"   => \$help
                        );

sub usage() {
        print "This script requires a configuration file to provide a project list.\n";
        print "It will use this list to query JIRA for all the unreleased versions \n";
        print "in each of our projects.  It will then send out the results in an HTML Mail.\n";

        print "Parameters :\n";
        print "\t--cfg     | -c => file to load list of projects from\n";

        print "e.g. perl get_scheduled_versions.pl -c get_scheduled_versions.cfg\n\n";

        exit 0;
}

if ($help) {
        usage();
}

if (!$cfgfile) { # Force all the required parameters
        usage();
}


# Take in a Perl Date/Time field and return a user readable date.
sub formatTime {
    my $time_in = shift;

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime($time_in);

    my @mon_array = qw( January February March April May June July August September October November December );
    my $month = $mon_array[$mon];

    my $nice_timestamp = sprintf ( "$month %02d, %04d", $mday , $year+1900);

    return $nice_timestamp;
}

# Grab todays date, stripping off the time portion
sub getToday {

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);

    my $st_time = timelocal(0,0,0,$mday,$mon,$year);

    return $st_time;
}

# Return a user readable date using the current date time
sub getNiceTime {

    my $nice_timestamp = formatTime(time);

    return $nice_timestamp;
}

# Convert the date recieved from Jira into a standard perl date/time field
sub convertDate {
    my $date_in = shift;

    my ($year, $mon, $mday) = split('-', $date_in);

    my $time = timelocal(0,0,0,$mday,$mon-1,$year);

    return $time;
}

# convert the data recieved from Jira (in a hash table) into HTML
sub generateHtml {
    my ($hashin) = @_;
    
    my %workhash = %$hashin;

    my $retval;

    my $today = getNiceTime();
    my $title = "Release Schedule (as of $today)";

    $retval .= "<!doctype html>\n";
    $retval .= "<html>\n";
    $retval .= "<head>\n";
    $retval .= "<title>$title</title>\n";
    $retval .= "</head>\n";
    $retval .= "<body>\n";
    $retval .= "<h2><font face=\"Calibri, sans-serif\">$title</h2></font>\n";

    $retval .= "<ul>\n";
    $retval .= "<font face=\"Calibri, sans-serif\">\n";
    $retval .= "    <li><font color='blue'>Releases in blue</font> are scheduled for today.\n"; 
    $retval .= "    <li><font color='red'>Releases in red</font> are late.</li>\n";
    $retval .= "    <li><font color='orange'>Orange background</font> indicates a stat holiday. Releases may be delayed or unavailable on Stat Holidays.</li> <br>\n";
    $retval .= "</font>\n";
    $retval .= "</ul>\n";

    $retval .= "<table style='border-left: 1px solid black; border-top: 1px solid black; width:90%' cellspacing='0' cellpadding='3'>\n";
    $retval .= "    <tr bgcolor=\"$bgcolor_header\">\n";
    $retval .= "        <td style='border-right: 1px solid black;border-bottom:1px solid black;'><font face=\"Calibri, sans-serif\"><b>Release Date</b></font></td>\n";
    $retval .= "        <td style='border-right: 1px solid black;border-bottom:1px solid black;'><font face=\"Calibri sans-serif\"><b>Project</b></font></td>\n";
    $retval .= "        <td style='border-right: 1px solid black;border-bottom:1px solid black;'><font face=\"Calibri sans-serif\"><b>Project Owner</b></font></td>\n";
    $retval .= "        <td style='border-right: 1px solid black;border-bottom:1px solid black;'><font face=\"Calibri sans-serif\"><b>Release</b></font></td>\n";
    $retval .= "        <td style='border-right: 1px solid black;border-bottom:1px solid black;'><font face=\"Calibri sans-serif\"><b>Decription</b></font></td>\n";
    $retval .= "    </tr>\n";

    foreach my $date (sort keys %workhash) {
        my $fontcolor = 'black';

        my $displaydate = $date;

        my $converteddate = convertDate($date); 

        if ($converteddate < getToday()) {
            $fontcolor = 'red';
        } elsif ($converteddate == getToday()) {
            $fontcolor = 'blue';
        }            

        foreach my $projectcode (sort keys $workhash{$date}) {
           foreach my $projrelname (sort keys $workhash{$date}{$projectcode}) {
               if ($projectcode eq $stat_projcode) {
                   $retval .= "    <tr bgcolor=\"$bgcolor_stat\">\n";
                   if ($workhash{$date}{$projectcode}{$projrelname}{'stdate'}) {
                       $displaydate = "$workhash{$date}{$projectcode}{$projrelname}{'stdate'} - " . $displaydate;
                   }
               } else {
                   $retval .= "    <tr  bgcolor=\"$bgcolor_table\">\n";
               }

               $retval .= "        <td style='border-right: 1px solid black;border-bottom:1px solid black;'><font color=$fontcolor face=\"Calibri, sans-serif\">$displaydate</font></td>\n";
               $retval .= "        <td style='border-right: 1px solid black;border-bottom:1px solid black;'><font color=$fontcolor face=\"Calibri, sans-serif\">$workhash{$date}{$projectcode}{$projrelname}{'name'}:$projectcode</font></td>\n";
               $retval .= "        <td style='border-right: 1px solid black;border-bottom:1px solid black;'><font color=$fontcolor face=\"Calibri, sans-serif\">$workhash{$date}{$projectcode}{$projrelname}{'owner'}</font></td>\n";
               $retval .= "        <td style='border-right: 1px solid black;border-bottom:1px solid black;'><font color=$fontcolor face=\"Calibri, sans-serif\">$projrelname </font></td>\n";
               $retval .= "        <td style='border-right: 1px solid black;border-bottom:1px solid black;'><font color=$fontcolor face=\"Calibri, sans-serif\">$workhash{$date}{$projectcode}{$projrelname}{'desc'} </font></td>\n";

               $retval .= "    </tr>\n";
           }
        } 
    }

    $retval .= "</table>\n";
    $retval .= "</body>\n";
    $retval .= "</html>\n";
    return $retval;

}

sub sendMessage {
    my $subject = shift;
    my $text = shift;
    my @recip = @{$_[0]};

    # use the following line if you are testing this script
    # inside the Firewall
    my $smtp = Net::SMTP->new($mailserver, Timeout => 60);

    # use the following line when using this on a Jenkins Server
    #my $smtp = Net::SMTP->new('localhost', Timeout => 60);

    $smtp->mail($mail_from);  # this is the FROM
    $smtp->to(@recip);

    $smtp->data();
    $smtp->datasend("MIME-Version: 1.0\nContent-Type: text/html; charset=UTF-8");
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
}

# small function to allow for pulling data for different projects from different JIRA installations
# pass any non zero value for the last parameter to get the versions list
sub getData {
    my $pfamily = shift;
    my $pcode   = shift;
    my $verreq  = shift;
    
    my $baseurl = '';

    if ($pfamily eq $family_gwp) {
        $baseurl = $GWPbaseurl; 
    } elsif ($pfamily eq $family_p4f) {
        $baseurl = $P4Fbaseurl;
    }

    my $projurl = $baseurl . $apiurl . $pcode;  # put together the URL to request
    
    if ($verreq) {
        $projurl .= "/versions";
    }

    # grab the project data
    my $json = `curl -ss -u $username:$password -X GET -H "Content-Type: application/json" $projurl`;

    my $decoded_json = 'NONE'; 
    
    if ($json ne '') {

        eval {
            # Decode the entire JSON
            $decoded_json = decode_json( $json );
            1;
        } or do {
            my $e = $@;
            print "$e\n";
        }

    }

    return $decoded_json;

}


# main function

{ 

    # Read in project list from file into an array 
    my $filein;         
    my %datedlist;

    unless (open $filein, '<', $cfgfile) {
        print "There was an error with file $cfgfile\n\n";
        exit 1;
    };

    my @projects = <$filein>;  # read in the result file

    close $filein;

    # for every project code listed in the array
    foreach my $projcodeinfo (@projects) {
        my $projectcode;
        my $projectfamily;

        chomp($projcodeinfo);

        if ($projcodeinfo =~ m/\#/) {  # check for a commented line and skip it
            next;
        }

        chomp($projcodeinfo);  # clean the line

        #seperate the indicator that defines which jira to read from the project code
        ($projectfamily, $projectcode) = split(":", $projcodeinfo);
       
        $projectcode =~ s/[ \t]+$//; # strip end tabs too

        # get the owner information for the project, zero in the last param says ignore the versions for now
        my $projdata = getData($projectfamily, $projectcode, 0);    
        
        # Skip if there is any issue with the URL or returned JSON
        if ($projdata eq 'NONE') {
            next;
        }
 
        # grab the owner name and JIRA URL for them
        my $owner = $projdata->{'lead'}->{'displayName'};
        my $name  = $projdata->{'name'};

        # get the version information for the project, 1 in the last param says get the versions
        my $versiondata = getData($projectfamily, $projectcode, 1);
        
        # Skip if there is any issue with the URL or returned JSON
        if ($versiondata eq 'NONE') {
            next;
        }
     
        # run through all the versions($projectcode eq $stat_projcode)o
        foreach my $record (@$versiondata) {
            if ( !$record->{'released'}) { # only care about the projects that have not been released
                my $relname  = 'NONE';
                my $reldesc  = 'NONE';
                my $reldate  = 'NONE';
                my $relstart = '';
                my $relurl   = 'NONE';
                my $relover  = 'NO';
 
                if ( $record->{'name'}) { # this is the proper name of the release
                    $relname = $record->{'name'};
                }
                if ( $record->{'description'}) { # this is the description of the release
                    $reldesc = $record->{'description'};
                }
                if ( $record->{'releaseDate'}) { # this is the release date for the given release
                    $reldate = $record->{'releaseDate'};
                }
                if ( $record->{'startDate'}) { # this is the start date for the given release
                    $relstart = $record->{'startDate'};
                }
                 if ( $record->{'self'} ) { # this is the JIRA URL for the given release 
                    $relurl  = $record->{'self'};
                }
                if ( $record->{'overdue'} ) {
                    $relover = 'YES';
                }
                
                # push the data into a hash table if it is a stat or matches the release naming convention
                if (($projectcode eq $stat_projcode) || ($relname =~ m/^R\s*\d*\./))  {
                    $datedlist{$reldate}{$projectcode}{$relname}{'owner'} = $owner;
                    $datedlist{$reldate}{$projectcode}{$relname}{'name'} = $name;
                    $datedlist{$reldate}{$projectcode}{$relname}{'date'} = $reldate;
                    $datedlist{$reldate}{$projectcode}{$relname}{'stdate'} = $relstart;
                    $datedlist{$reldate}{$projectcode}{$relname}{'relurl'} = $relurl;
                    $datedlist{$reldate}{$projectcode}{$relname}{'desc'} = $reldesc;
                }
            }
        }
    }

    my $mailbody = generateHtml(\%datedlist);

    sendMessage($mailsubject, $mailbody, \@recipients); # send the message...

exit 0;
}
###############################################################################
