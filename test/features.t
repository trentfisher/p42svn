#!/usr/bin/env perl
#
# dump with the new features turned on, load it into a repository
# and then dump it back out... just kind of a 'smoke test'
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

#------------------------------------------------------------------------
rmtree($repos);
ok(not -d $repos);
system("svnadmin create $repos");
ok(-f $repos."/format");

system("perl ../p42svn.pl --save-changenum prop,comm --rawcharset cp1252 --fix-case map --label all | svnadmin load -q $repos");
ok($?, 0);

# clean up
rmtree($repos);
ok(not -d $repos);

exit 0;
