#!/usr/bin/env perl
# test case for damaged files in perforce
#
$|=1;

use Test;
use File::Path;
use File::Basename;
use File::Spec;
use File::Temp;

BEGIN { plan tests => 17, todo => [] }

my $repos = $0; $repos =~ s/\.\S$//;
$repos = File::Spec->rel2abs($repos);

use subs 'system';
sub system { print join(" ", @_),"\n"; CORE::system(@_); }

ok(1);

# first create some damage
my $damagedfile = "PerforceSample/depot/Misc/marketing/time_value.xls,d/1.1.gz";
rename($damagedfile, $damagedfile.".broken") || warn;
ok(not -f $damagedfile);

#------------------------------------------------------------------------
# try an import... we expect it to bomb
rmtree($repos);
ok(not -d $repos);
system("svnadmin create $repos");
system("perl ../p42svn.pl --branch //depot/Misc= --save-changenum both | svnadmin load -q $repos");
ok($?, 0);

# the partial rev got in
my $y = qx(svnlook youngest $repos); chomp $y;
ok($y+0, 2);
my @c = qx(svnlook changed -r2 $repos); chomp @c;
ok($#c, 2);
ok(not grep(/time_value/, @c));

#------------------------------------------------------------------------
# now do it again, but now don't allow the partial rev
rmtree($repos);
ok(not -d $repos);
system("svnadmin create $repos");
system("perl ../p42svn.pl --nopartialrev --branch //depot/Misc= --save-changenum both | svnadmin load -q $repos");
ok($? > 0);

# the partial rev shouldn't be there
$y = qx(svnlook youngest $repos); chomp $y;
ok($y+0, 1);

#------------------------------------------------------------------------
# try an import... we expect it to bomb
rmtree($repos);
ok(not -d $repos);
system("svnadmin create $repos");
system("perl ../p42svn.pl --nopartialrev --skipcorrupt --branch //depot/Misc= --save-changenum both | svnadmin load -q $repos");
ok($?, 0);

# the rev got in with placeholder text
$y = qx(svnlook youngest $repos); chomp $y;
ok($y+0, 9);
@c = qx(svnlook changed -r2 $repos); chomp @c;
ok($#c, 4);
ok(grep(/time_value/, @c));
# check that the file contains the placeholder
@c = qx(svnlook cat -r2 $repos marketing/time_value.xls);
ok($c[0], qr/^VERSION CORRUPTED in P4 Depot/);

#------------------------------------------------------------------------
# Test over... put the damaged file back
rename($damagedfile.".broken", $damagedfile) || warn;

# clean up
rmtree($repos);
ok(not -d $repos);

exit 0;
