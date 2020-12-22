#!/usr/bin/env perl
#
$|=1;

use Test;
use File::Basename;
use File::Spec;
use File::Temp;

BEGIN { plan tests => 4, todo => [] }

my $repos = $0; $repos =~ s/\.\S$//;
$repos = File::Spec->rel2abs($repos);

use subs 'system';
sub system { print join(" ", @_),"\n"; CORE::system(@_); }

ok(1);

#------------------------------------------------------------------------
# do a dump using the old version of p42svn
system("perl ../p42svn.pl.orig --branch //depot/Talkhouse= > before.svndump");
ok($?, 0);
system("perl ../p42svn.pl --branch //depot/Talkhouse= > after.svndump");
ok($?, 0);

open(my $diff, "diff before.svndump after.svndump |")
    or die "Error: diff before.svndump after.svndump: $!\n";
my $diffcnt = 0;
while(<$diff>)
{
    chomp;
    # here's what we expect, because of timezone fixes in the new version
    # 19741c19741
    # < 2008-11-14T07:23:40.000000Z
    # ---
    # > 2008-11-14T15:23:40.000000Z
    if (/^\d+c\d+$/ or /^-+$/ or /^[<>] \d+-\d+-\d+T\d+:\d+:\d+\.\d+Z$/)
    {}
    else
    {
        warn "Unexpected diff output: $_\n";
        $diffcnt++;
    }
}
ok($diffcnt, 0);
exit 0;
