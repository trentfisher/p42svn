#!/usr/bin/env perl
#
# test case for proper timezone handling
#
$|=1;

use Test;
use File::Path;
use File::Basename;
use File::Spec;
use File::Temp;
use Date::Parse;

BEGIN { plan tests => 366, todo => [] }

my $repos = $0; $repos =~ s/\.\S$//;
$repos = File::Spec->rel2abs($repos);

use subs 'system';
sub system { print join(" ", @_),"\n"; CORE::system(@_); }

ok(1);

my $depot = "//depot/Jam";

rmtree($repos);
ok(not -d $repos);
system("svnadmin create $repos");
ok($?, 0);
ok(-d $repos."/db");
system("perl ../p42svn.pl --branch $depot= --save-changenum both --dry-run --syncrevs | svnadmin load -q $repos");
ok($?, 0);

# get all the revisions and dates out of svn
my $revdates = {};
open(my $svnlog, "-|", "svn", "log", "file://".$repos) or
    die "Error: svn log $repos: $!\n";
while(<$svnlog>)
{
    # r1 | earl | 1999-09-23 07:19:47 -0700 (Thu, 23 Sep 1999) | 4 lines
    if (/^r(\d+) \| .+? \| (.+?) \|/)
    {
        $revdates->{$1}{svn} = str2time($2);
        printf "svn rev %d %s => %s\n", $1, $2,  $revdates->{$1}{svn};
    }
}
# get all revisions and dates out of perforce
open(my $p4log,  "-|", "p4", "changes", "-t", "$depot/...") or
    die "Error: p4 changes $repos: $!\n";
while (<$p4log>)
{
    # Change 1 on 1999/09/23 14:19:47 by earl@earl-dev-guava 'Initial revision '
    if (/^Change (\d+) on (.+?) by /)
    {
        $revdates->{$1}{p4} = str2time($2);
        printf "p4 rev %d %s => %s\n", $1, $2, $revdates->{$1}{svn};
    }
}

# now compare the times for each revision, since we used --syncrevs above
# the revision numbers should match up (so I guess this is a test case for
# --syncrevs as well :)
foreach my $rev (sort {$a <=> $b} %$revdates)
{
    next unless defined $revdates->{$rev}{svn} and
        defined $revdates->{$rev}{p4};
    ok($revdates->{$rev}{svn}, $revdates->{$rev}{p4});
}

# clean up
rmtree($repos);
ok(not -d $repos);

exit 0;
