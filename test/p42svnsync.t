#!/usr/bin/env perl
# test case for inconsistent info from perforce or incomplete transactions
# on incremental imports.  In particular, make sure these are handled:
# - add a file which exists in SVN
# - edit a file which does not exist in SVN
#
$|=1;

use Test;
use File::Path;
use File::Basename;
use File::Spec;
use File::Temp;

BEGIN { plan tests => 22, todo => [] }

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
system("perl ../p42svnsync init $repos --branch //depot= --save-changenum both --label all");
ok($?, 0);

# this should sync everything
system("perl ../p42svnsync sync $repos --rawcharset cp1252");
ok($?, 0);

my @out = qx(perl ../p42svnsync info $repos);
print @out;
my ($lastp4before) = map(/last p4 rev synced: (\d+)/, @out);
# last p4 rev must be a positive number
ok($lastp4before > 0);
# make sure no lock file is left
ok(scalar(grep(/Sync process /, @out)), 0);

system("perl ../p42svnsync sync $repos --rawcharset cp1252");
ok($?, 0);

# make sure no revs got added
@out = qx(perl ../p42svnsync info $repos);
print @out;
my ($lastp4after) = map(/last p4 rev synced: (\d+)/, @out);
ok($lastp4after, $lastp4before);
# make sure no lock file is left
ok(scalar(grep(/Sync process /, @out)), 0);

#------------------------------------------------------------------------
# test locking, start with a fresh sync
#
rmtree($repos);
ok(not -d $repos);
system("svnadmin create $repos");
ok($?, 0);
ok(-d $repos."/db");
system("perl ../p42svnsync init $repos --branch //depot= --save-changenum both --label all");
ok($?, 0);

my $pid = fork();
if (not $pid)
{
    # this should sync everything
    print "child fork $pid\n";
    system("perl ../p42svnsync sync $repos --rawcharset cp1252");
    exit $?;
}

sleep 2;  # hopefully long enough for the child to get started
print "parent fork, child is $pid\n";
@out = qx(perl ../p42svnsync info $repos);
print @out;
ok(scalar(grep(/Sync process /, @out)), 1);

# this should fail as the other one is running
system("perl ../p42svnsync sync $repos --rawcharset cp1252");
ok($?);

print "waiting for child import to finish\n";
ok(wait(), $pid);
ok($?, 0);  # status of the child sync

# make sure everything got imported
@out = qx(perl ../p42svnsync info $repos);
print @out;
($lastp4after) = map(/last p4 rev synced: (\d+)/, @out);
ok($lastp4after, $lastp4before);
# make sure no lock file is left
ok(scalar(grep(/Sync process /, @out)), 0);

# clean up
rmtree($repos);
ok(not -d $repos);

exit 0;

#------------------------------------------------------------------------
# test a partial import... just a restatement of partial.t

# Add /Jam/MAIN/src/jam.ps
# remove /Jam/MAIN/src/scan.h
system("svn import -m test $0 file://$repos/Jam/MAIN/src/jam.ps");
ok($?, 0);
system("svn rm -m test file://$repos/Jam/MAIN/src/scan.h");
ok($?, 0);

# try to import rev 179,180
my $files = File::Temp->new(TEMPLATE => $repos."filesXXXXXX");
system("svnlook tree --full-paths $repos > ".$files->filename);
my $revs = File::Temp->new(TEMPLATE => $repos."revsXXXXXX");
system("svn log --xml --with-all-revprops file://$repos > ".$revs->filename);

system("perl ../p42svn.pl --branch //depot= --save-changenum both --changes 179-180 ".
       "--existing-files ".$files->filename." --existing-revs ".$revs->filename.
       " | svnadmin load -q $repos");
ok($?, 0);
