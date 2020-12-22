#!/usr/bin/env perl
#
$|=1;

use Test;
use File::Path;
use File::Basename;
use File::Spec;
use File::Temp;

BEGIN { plan tests => 5, todo => [] }

my $repos = $0; $repos =~ s/\.\S$//;
$repos = File::Spec->rel2abs($repos);

use subs 'system';
sub system { print join(" ", @_),"\n"; CORE::system(@_); }

ok(1);

rmtree($repos);
ok(not -d $repos);
system("svnadmin create $repos");
ok(-f $repos."/format");

# do NOT include the --label option as it will mess up the rev numbers
system("perl ../p42svn.pl --branch //depot/Jam= --syncrevs --save-changenum prop,comm | svnadmin load -q $repos");
ok($?, 0);
ok(lastsvnrev($repos), lastp4rev($repos));

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
