#!/usr/bin/env perl
# test case for label imports
#
$|=1;

use Test;
use File::Path;
use File::Basename;
use File::Spec;
use File::Temp;

BEGIN { plan tests => 41, todo => [] }

my $repos = $0; $repos =~ s/\.\S$//;
$repos = File::Spec->rel2abs($repos);

use subs 'system';
sub system { print join(" ", @_),"\n"; CORE::system(@_); }

ok(1);

#------------------------------------------------------------------------
# test a partial label... when importing only a part of the tree
rmtree($repos);
ok(not -d $repos);
system("svnadmin create $repos");
ok(-f $repos."/format");
system("perl ../p42svn.pl --branch //depot/www= --save-changenum prop,comm --label '.*=//depot=/tags' | svnadmin load -q $repos");
ok($?, 0);
my @out = qx(svnlook tree $repos);
ok($#out, 32);
@out = qx(svnlook tree -N $repos tags);
ok($#out, 1);

#------------------------------------------------------------------------
# tests for multiple branches and tags
rmtree($repos);
ok(not -d $repos);
system("svnadmin create $repos");
ok(-f $repos."/format");
system("perl ../p42svn.pl  --branch //depot/Talkhouse=Talkhouse --branch //depot/Jam=Jam --branch //depot/Jamgraph=Jamgraph --label each --save-changenum prop,comm | svnadmin load -q $repos");
ok($?, 0);
@out = qx(svnlook tree -N $repos tags 2> /dev/null);
ok($#out, -1);
@out = qx(svnlook tree -N $repos tags/Talkhouse 2> /dev/null);
ok($#out, -1);
@out = qx(svnlook tree -N $repos Jam/tags);
ok($#out, 5);
@out = qx(svnlook tree -N $repos Jamgraph/tags);
ok($#out, 1);

#------------------------------------------------------------------------
# test for all labels going into a sigle global tags directory
#
rmtree($repos);
ok(not -d $repos);
system("svnadmin create $repos");
ok(-f $repos."/format");
system("perl ../p42svn.pl  --branch //depot/Talkhouse=Talkhouse --branch //depot/Jam=Jam --branch //depot/Jamgraph=Jamgraph --label all --save-changenum prop,comm | svnadmin load -q $repos");
ok($?, 0);
@out = qx(svnlook tree -N $repos tags);
ok($#out, 2);
# this one has no labels
@out = qx(svnlook tree -N $repos tags/Talkhouse 2> /dev/null);
ok($#out, -1);
@out = qx(svnlook tree -N $repos tags/Jam);
ok($#out, 5);
@out = qx(svnlook tree -N $repos tags/Jamgraph);
ok($#out, 1);
# these should not be present
@out = qx(svnlook tree -N $repos Jam/tags 2> /dev/null);
ok($#out, -1);
@out = qx(svnlook tree -N $repos Jamgraph/tags 2> /dev/null);
ok($#out, -1);

#------------------------------------------------------------------------
# test multiple imports with the --label option:
# what if we run a full import, with labels, and then do the same thing,
#  with --changes
rmtree($repos);
ok(not -d $repos);
system("svnadmin create $repos");
ok(-f $repos."/format");
system("perl ../p42svn.pl --branch //depot/Jam= --save-changenum prop,comm | svnadmin load -q $repos");
ok($?, 0);
# no labels yet
@out = qx(svnlook tree -N $repos tags 2> /dev/null);
ok($#out, -1);
@out = qx(svnlook tree -N $repos Jam/tags 2> /dev/null);
ok($#out, -1);
my $beforelabelrev = lastsvnrev($repos);

# now import the labels
system("svnlook tree --full-paths $repos > $repos.filelist");
ok(-f "$repos.filelist");
system("svn log --xml --with-all-revprops file://$repos > $repos.log");
ok(-f "$repos.log");
system("perl ../p42svn.pl --branch //depot/Jam= --label all ".
       "--existing-files $repos.filelist --existing-revs $repos.log ".
       "--changes ".(lastp4rev($repos)+1).
       " --save-changenum prop,comm | svnadmin load -q $repos");
ok($?, 0);
# make sure the labels are now there
# if the label wasn't created right, there will be no history on this file
@out = qx(svn log file://$repos/tags/jam-2.1.0-mac-export/MAIN/src/variable.h);
ok($#out, 28);
@out = qx(svnlook tree -N $repos tags);
ok($#out, 5);
@out = qx(svnlook tree -N $repos Jam/tags 2> /dev/null);
ok($#out, -1);
ok(lastsvnrev($repos), $beforelabelrev+5);

# do it again, this time there should be almost nothing in the dump file
system("svnlook tree --full-paths $repos > $repos.filelist");
system("svn log --xml --with-all-revprops file://$repos > $repos.log");
system("perl ../p42svn.pl --branch //depot/Jam= --label all ".
       "--existing-files $repos.filelist --existing-revs $repos.log ".
       "--changes ".(lastp4rev($repos)+1).
       " --save-changenum prop,comm | svnadmin load -q $repos");
ok($?, 0);
ok(lastsvnrev($repos), $beforelabelrev+5);
@out = qx(svnlook tree -N $repos tags);
ok($#out, 5);

# now run it again with --redolabels, now it should have a lot of stuff in it
system("perl ../p42svn.pl --branch //depot/Jam= --label all ".
       "--existing-files $repos.filelist --existing-revs $repos.log ".
       "--redolabels --changes ".(lastp4rev($repos)+1).
       " --save-changenum prop,comm | svnadmin load -q $repos");
ok($?, 0);
ok(lastsvnrev($repos), $beforelabelrev+10);
@out = qx(svnlook tree -N $repos tags);
ok($#out, 5);

# clean up
rmtree($repos);
ok(not -d $repos);

exit 0;

sub lastsvnrev
{
    my $repos = shift;
    my @out = qx(svnlook youngest $repos);
    chomp @out;
    return $out[0];
}
sub lastp4rev
{
    my $repos = shift;
    open(my $l, "svn log --xml --with-all-revprops file://$repos |") or
        warn "Error: svn log $repos: $!\n";
    my $found;
    while(<$l>)
    {
        $found=$1 if not $found and m,name="p42svn:changenum">(\d+)</property>,;
    }
    return $found;
}
