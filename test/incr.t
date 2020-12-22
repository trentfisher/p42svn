#!/usr/bin/env perl
#
# test case for incremental imports
# We do an export from perforce in segments.  The revisions which cause
# trouble are as follows
#  96,233,236,238,240,242,244,246,248,266,268,280,296,299... add Jam
# This also tests the --syncrevs option as when the whole import is done,
# the final rev numbers for p4 and svn must be identical
#
$|=1;

use Test;
use File::Path;
use File::Basename;
use File::Spec;
use File::Temp;

BEGIN { plan tests => 517, todo => [] }

my $repos = $0; $repos =~ s/\.\S$//;
$repos = File::Spec->rel2abs($repos);

use subs 'system';
sub system { print join(" ", @_),"\n"; CORE::system(@_); }

ok(1);

#------------------------------------------------------------------------
rmtree($repos);
ok(not -d $repos);
system("svnadmin create $repos");
ok(-f $repos."/format");

my @out = qx(p4 changes -m 1);
my $lastp4 = (split(/\s+/, $out[0]))[1];

# this increment was chosen to hit the problematic versions mentioned above
# can override on cmd line if needed
my $incr = 95 || $ARGV[0];

for (my $i = 1; $i < $lastp4; $i+=$incr)
{
    system("svnlook tree --full-paths $repos > $repos.filelist");
    ok(-f "$repos.filelist");
    system("svn log --xml --with-all-revprops file://$repos > $repos.log");
    ok(-f "$repos.log");
    my $endrev = $i+$incr-1;
    $endrev = $lastp4 if $endrev > $lastp4;
    system("perl ../p42svn.pl --rawcharset cp1252 --syncrevs".
           " --changes $i-$endrev".
           " --existing-files $repos.filelist --existing-revs $repos.log".
           " --branch //depot= --save-changenum prop,comm | svnadmin load -q $repos");
    ok($?, 0);
    ok(lastsvnrev($repos), $endrev);
}

ok(lastsvnrev($repos), $lastp4);

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
