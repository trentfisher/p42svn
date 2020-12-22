#!/usr/bin/env perl
# test case for damaged files in perforce
#
$|=1;

use Test;
use File::Path;
use File::Basename;
use File::Spec;
use File::Temp;

BEGIN { plan tests => 6, todo => [] }

my $repos = $0; $repos =~ s/\.\S$//;
$repos = File::Spec->rel2abs($repos);

use subs 'system';
sub system { print join(" ", @_),"\n"; CORE::system(@_); }

ok(1);

# do a conversion, but just of part of the repos
rmtree($repos);
ok(not -d $repos);
system("svnadmin create $repos");
system("perl ../p42svn.pl --branch //depot= --save-changenum both --changes 1-800 | svnadmin load -q $repos");
ok($?, 0);

# now verify what we imported
system("svn log --xml --with-all-revprops -v file://$repos > $repos.log");
my @out = qx(perl ../p42svn.pl --branch //depot= --verify --existing-revs $repos.log --changes 1-800 2>&1);
warn @out if @out;
ok($#out, -1);

# now try with a wider range of revs, we should now show 5 revs missing
@out = qx(perl ../p42svn.pl --branch //depot= --verify --existing-revs $repos.log --changes 1-900 2>&1);
warn @out if @out;
ok($#out, 5);

# clean up
rmtree($repos);
ok(not -d $repos);

exit 0;
