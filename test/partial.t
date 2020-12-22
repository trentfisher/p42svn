#!/usr/bin/env perl
# test case for inconsistent info from perforce or incomplete transactions
# on incremental imports.  In particular, make sure these are handled:
# - add a file which exists in SVN
# - edit a file which does not exist in SVN
#
$|=1;

use Test;
use File::Path;
use File::Basename;
use File::Spec;
use File::Temp;

BEGIN { plan tests => 11, todo => [] }

my $repos = $0; $repos =~ s/\.\S$//;
$repos = File::Spec->rel2abs($repos);

use subs 'system';
sub system { print join(" ", @_),"\n"; CORE::system(@_); }

ok(1);

# import to rev 178

rmtree($repos);
ok(not -d $repos);
system("svnadmin create $repos");
ok($?, 0);
ok(-d $repos."/db");
system("perl ../p42svn.pl --branch //depot= --save-changenum both --changes 1-178 | svnadmin load -q $repos");
ok($?, 0);

# Add /Jam/MAIN/src/jam.ps... it will get added in 179
# remove /Jam/MAIN/src/scan.h... it will get edited in 180
system("svn import -m test $0 file://$repos/Jam/MAIN/src/jam.ps");
ok($?, 0);
system("svn rm -m test file://$repos/Jam/MAIN/src/scan.h");
ok($?, 0);

# try to import rev 179,180 and on up to 201 for the next test
my $files = File::Temp->new(TEMPLATE => $repos."filesXXXXXX");
system("svnlook tree --full-paths $repos > ".$files->filename);
my $revs = File::Temp->new(TEMPLATE => $repos."revsXXXXXX");
system("svn log --xml --with-all-revprops file://$repos > ".$revs->filename);

system("perl ../p42svn.pl --branch //depot= --save-changenum both --changes 179-201 ".
       "--existing-files ".$files->filename." --existing-revs ".$revs->filename.
       " | svnadmin load -q $repos");
ok($?, 0);

# now remove a file which is about to get deleted in rev 202
system("svn rm -m test file://$repos/Jam/MAIN/src/jambase.c");
ok($?, 0);

# now import the rest
system("svnlook tree --full-paths $repos > ".$files->filename);
system("svn log --xml --with-all-revprops file://$repos > ".$revs->filename);

system("perl ../p42svn.pl --branch //depot= --save-changenum both --changes 202-203 ".
       "--existing-files ".$files->filename." --existing-revs ".$revs->filename.
       " | svnadmin load -q $repos");
ok($?, 0);

# clean up
rmtree($repos);
ok(not -d $repos);

exit 0;
