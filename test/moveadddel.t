#!/usr/bin/env perl
#
$|=1;

use Test;
use File::Path;
use File::Basename;
use File::Spec;
use File::Temp;

BEGIN { plan tests => 8, todo => [] }

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
system("perl ../p42svn.pl --branch //depot/www=www | svnadmin load -q $repos");
ok($?, 0);

my @out = qx(svn log file://$repos/www/dev/Jelly.html);
ok($#out, 14);
@out = qx(svn log file://$repos/www/dev/index.html);
ok($#out, 15);
@out = qx(svn log file://$repos/www/dev/index.htm);
ok($#out, 19);

# clean up
rmtree($repos);
ok(not -d $repos);

exit 0;

