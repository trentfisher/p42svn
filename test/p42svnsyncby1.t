#!/usr/bin/env perl
# just a simple test to do a full load and then do it one rev at a time
# they should end up the same
#
$|=1;

use Test;
use File::Path;
use File::Basename;
use File::Spec;
use File::Temp;

BEGIN { plan tests => 15, todo => [] }

my $repos = $0; $repos =~ s/\.\S$//;
$repos = File::Spec->rel2abs($repos);

use subs 'system';
sub system { print join(" ", @_),"\n"; CORE::system(@_); }

ok(1);

#------------------------------------------------------------------------
# do a simple, full, replication
#
rmtree($repos);
ok(not -d $repos);
system("svnadmin create $repos");
ok($?, 0);
ok(-d $repos."/db");
system("perl ../p42svnsync init $repos --branch //depot= --save-changenum both --rawcharset cp1252");
ok($?, 0);

# this should sync everything
system("perl ../p42svnsync sync $repos");
ok($?, 0);
system("perl ../p42svnsync info $repos");
# exclude rev 0 as it is always different
system("svnadmin dump -r1:HEAD -q $repos > $repos.svndumpall");
ok($?, 0);
my ($uuid) = qx(svnlook uuid $repos); chomp $uuid;

# now do the whole thing over, one rev at a time
rmtree($repos);
ok(not -d $repos);
system("svnadmin create $repos");
ok($?, 0);
system("svnadmin setuuid $repos $uuid");
ok($?, 0);
ok(-d $repos."/db");
system("perl ../p42svnsync init $repos --branch //depot= --save-changenum both --rawcharset cp1252");
ok($?, 0);

my @out = qx(p4 changes -m 1);
my $lastp4 = (split(/\s+/, $out[0]))[1];

while (lastp4rev($repos) < $lastp4)
{
    system("perl ../p42svnsync -n1 sync $repos");
}
system("perl ../p42svnsync info $repos");
system("svnadmin dump -r1:HEAD -q $repos > $repos.svndumpone");
ok($?, 0);

system("diff -q $repos.svndumpall $repos.svndumpone");
ok($?, 0);

rmtree($repos);
ok(not -d $repos);

exit 0;

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
