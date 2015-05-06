Sample Perl Scripts
===================

These are a number of scripts I wrote for an Operations team and a Test team


perfupload.pl
=============

Script used to upload performance test results from a Jmeter generated summary file into the
performance test database manually after a performance test run

Usage from the script :

This script requires a project name, a results file to parse, a recipients
list and a location where the results will be permanently stored.

Parameters :  
    --project | -p => Name of project that is being tested.  
    --file | -f => Results file to be parsed and uploaded.  
    --date | -d => Date of the test run, defaults to NOW if not set.  
    --note | -n => Notes, description of the test run.  
    --dur |  -u => Duration of the test run.  

e.g. perl perfupload.pl -p *project name* -f *resultsfile* -d '2013-12-12 09:01:00' -n '1000 auth users only' -u 3600


logparse.pl
===========

Script that parses an Apache access log and summarizes the number of 404s in the file.  This was executed on a as needed 
basis when we were experiencing problems with Drupal Sites.

Usage from the script :

This script requires a results file to parse and will display the top 20 hits  
Parameters :  
    --file | -f => Results file to be parsed and summarised.  
    --topx | -t => How many to display.  
    --days | -d => How many days of data to include.  

e.g. perl logparse.pl -f *filename* -t 10 -d 1


gather_image_urls.pl
====================

Script that will recursively read a folder full of HTML files and extract all of the image 
files that they reference.  It will then write the results to file, including a list of HTML files
that had problem image links.

Usage from the script :

This script will traverse a directory (recursively) of HTML files, generating a list of image URLs  
Parameters :  
    --basedir | -b => Folder of files to be parsed and summarised.  
    --file    | -f => File to write URL list to  

e.g. perl gather_image_urls.pl -d *source directory* -f *output filename*


test_image_urls.pl
==================

Script that consumes the output file from gather_image_urls.pl and will test all the valid 
URLs from the list using mechanize.  Actually, it will take any file that contains URLs if 
the URL starts at the beginning of each line.

Usage from the script :

This script requires an input file containing a list of URLs to test.
It will then output the results to the specified file.  

Parameters :  
    --file    | -f => File to read URL list from  
    --ofile   | -o => File to read URL list from  

e.g. perl test_image_urls.pl -f *input file* -o *output filename*


get_build_list.pl
=================

Usage from the script :

This script requires an input file containing a list of sites to check
for version numbers in the build.txt file on the local servers.
It will then output the results to the specified file as an HTML page.

Parameters :  
    --ifile   | -f => File to read URL list from  
    --ofile   | -o => File to read URL list from  

e.g. perl get_build_list.pl -f *input file* -o *output filename*


reaper.pl
=========

Usage from the script :

This script will scan processes for the named process (default varnishd), tell you the pid of the process that
has the most CPU time, and ask if you want to kill it unless you specified no prompt.  
Parameters :  
    --prompt | -p => Y for yes, N for JFDI  
    --sleep  | -s => In seconds, default is 60  
    --thresh | -t => In seconds, default is 600  

e.g. perl reaper.pl -p Y -s 120 -t 600


get_scheduled_versions.pl
=========================

This script was set up on a cron so it would mail the stakeholders every Monday morning showing what was 
shipping this week, what was overdue, and what the stat holidays were this week.

Usage from the script :

This script requires a configuration file to provide a project list.
It will use this list to query JIRA for all the unreleased versions
in each of our projects.  It will then send out the results in an HTML Mail.  
Parameters :  
    --cfg     | -c => file to load list of projects from  

e.g. perl get_scheduled_versions.pl -c get_scheduled_versions.cfg


resultsmailer.pl
=========================

This script was originally written to parse automated cucumber test results and mail the results to the test team.
It was later updated to also send the results to a DB as well using a PHP page.

Usage from the script :

This script requires a test name, a results file to parse, a recipients
list and a location where the results will be permanently stored.
Parameters :  
    --test | -t => Name of test that is being executed.  
    --link | -l => Global link to permanent storage of results.  
    --file | -f => Results file to be parsed and mailed.  
    --recip | -r => semi-colon separated list of mail recipients.  
    --mail | -m => location of a file containing a list of mail recipients.  

 e.g. perl resultsmailer.pl -t 'test name' -f 'resultsfile' -l 'link to permanent location' -r 'recip1\@test.com;recip2\@test.com' -m project_maillist
 
