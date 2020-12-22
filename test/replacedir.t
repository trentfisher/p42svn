#!/usr/bin/env perl
#
# test case for when a directory is replaced with a file and then back again
#

use Test;
use File::Spec;
use File::Path;

BEGIN { plan tests => 6, todo => [] }

my $repos = $0; $repos =~ s/\.\S$//;
$repos = File::Spec->rel2abs($repos);

rmtree($repos);
ok(not -d $repos);
system("svnadmin create $repos");
ok($?, 0);
ok(-d $repos."/db");
system("perl ../p42svn.pl --branch //depot/chgtests= --save-changenum both --dry-run --syncrevs | svnadmin load -q $repos");
ok($?, 0);

my @files = qx(svnlook tree --full-paths $repos);
chomp @files;

ok(grep(m,^d2f$,, @files));
ok(grep(m,^d2s$,, @files));

ok(grep(m,^f2d/dummy$,, @files));
ok(grep(m,^f2s$,, @files));

ok(grep(m,^s2f$,, @files));
ok(grep(m,^s2d/dummy$,, @files));


exit 0;
