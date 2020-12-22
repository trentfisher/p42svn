#!/usr/bin/env perl
# test case for damaged files in perforce
#
$|=1;

use Test;
use File::Path;
use File::Basename;
use File::Spec;
use File::Temp;

BEGIN { plan tests => 11, todo => [] }

my $repos = $0; $repos =~ s/\.\S$//;
$repos = File::Spec->rel2abs($repos);

use subs 'system';
sub system { print join(" ", @_),"\n"; CORE::system(@_); }

ok(1);

rmtree($repos);
ok(not -d $repos);
system("svnadmin create $repos");
ok(-f $repos."/format");

my $cache = "$repos.cache";
rmtree($cache);
ok(not -d $cache);

# this run should fill up the cache
system("perl ../p42svn.pl --branch //depot= --rawcharset cp1252 --contentcache $cache --save-changenum prop,comm --label all | tee $repos.svndump1 | svnadmin load -q $repos");
ok($?, 0);

# this run should pull content exclusively from the cache... we will
# verify this by closing off the ,v files in the depot
rmtree($repos);
ok(not -d $repos);
system("svnadmin create $repos");
ok(-f $repos."/format");
ok(-d $ENV{P4ROOT}."/depot");
chmod 0, $ENV{P4ROOT}."/depot";
system("perl ../p42svn.pl --branch //depot= --rawcharset cp1252 --contentcache $cache --save-changenum prop,comm --label all | tee $repos.svndump2 | svnadmin load -q $repos");
ok($?, 0);

chmod 0755, $ENV{P4ROOT}."/depot";
system("diff -q $repos.svndump1 $repos.svndump2");
ok($?, 0);

# clean up
rmtree($repos);
ok(not -d $repos);

exit 0;
