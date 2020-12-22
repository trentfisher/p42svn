#!/usr/bin/env perl
#
# test case for various encodings of filenames.
#
$|=1;

use Test;
use File::Path;
use File::Spec;
use File::Temp;
use Encode;

BEGIN { plan tests => 48, todo => [] }

my $repos = $0; $repos =~ s/\.\S$//;
$repos = File::Spec->rel2abs($repos);

use subs 'system';
sub system { print join(" ", @_),"\n"; CORE::system(@_); }

ok(1);

#------------------------------------------------------------------------
rmtree($repos);
ok(not -d $repos);
system("svnadmin create $repos");
ok($?, 0);
ok(-d $repos."/db");
system("perl ../p42svn.pl --branch //depot/chartests= 2> /dev/null | svnadmin load -q $repos");
ok($?, 0);

my @out1 = sort qx(svnlook tree --full-paths $repos);
print @out1;
# if we get less than 5 entries two of the files ended up on top of each other
ok($#out1, 4);

# make sure they are all valid utf8 strings
foreach my $f (@out1)
{
    ok(eval { decode_utf8($f, Encode::FB_CROAK); 1; }, 1);
}
# the invalid utf8 char should get turned into hex notation
ok(scalar(map(/^foo=C0bar\s*$/, @out1)), 1);

#------------------------------------------------------------------------
# now tell it that we may get cp1252 chars
rmtree($repos);
ok(not -d $repos);
system("svnadmin create $repos");
ok($?, 0);
ok(-d $repos."/db");
system("perl ../p42svn.pl --branch //depot/chartests= --rawcharset cp1252 | svnadmin load -q $repos");
ok($?, 0);

my @out2 = sort qx(svnlook tree --full-paths $repos);
print @out2;
# if we get less than 5 entries two of the files ended up on top of each other
ok($#out2, 4);

# make sure they are all valid utf8 strings
foreach my $f (@out2)
{
    ok(eval { decode_utf8($f, Encode::FB_CROAK); 1; }, 1);
} 
# none should get hex escapes
ok(scalar(map(/\%[a-z0-9]+/, @out2)), 0);
# the weird full width latin foobar should be the same in both
ok($out1[$#out1], $out2[$#out2]);

#------------------------------------------------------------------------
# now test that incremental loads work properly
rmtree($repos);
ok(not -d $repos);
system("svnadmin create $repos");
ok($?, 0);
ok(-d $repos."/db");
system("perl ../p42svn.pl --branch //depot/chartests= --changes 1-12109 2> /dev/null | svnadmin load -q $repos");
ok($?, 0);

my @out3 = sort qx(svnlook tree --full-paths $repos);
print @out3;
# if we get less than 5 entries two of the files ended up on top of each other
ok($#out3, 4);

# make sure they are all valid utf8 strings
foreach my $f (@out3)
{
    ok(eval { decode_utf8($f, Encode::FB_CROAK); 1; }, 1);
}
# the invalid utf8 char should get turned into hex notation
ok(scalar(map(/^foo=C0bar\s*$/, @out3)), 1);

# now load up the next rev
my $files = File::Temp->new(TEMPLATE => $repos."filesXXXXXX");
system("svnlook tree --full-paths $repos > ".$files->filename);
my $revs = File::Temp->new(TEMPLATE => $repos."revsXXXXXX");
system("svn log --xml --with-all-revprops file://$repos > ".$revs->filename);

system("perl ../p42svn.pl --branch //depot/chartests= --changes 12110 ".
       "--existing-files ".$files->filename." --existing-revs ".$revs->filename.
       " 2> /dev/null | svnadmin load -q $repos");

my @out4 = sort qx(svnlook tree --full-paths $repos);
print @out4;
# if we get more than 5 entries disjoint files got created
ok($#out4, 4);

# make sure they are all valid utf8 strings
foreach my $f (@out4)
{
    ok(eval { decode_utf8($f, Encode::FB_CROAK); 1; }, 1);
}
# the invalid utf8 char should get turned into hex notation
ok(scalar(map(/^foo=C0bar\s*$/, @out4)), 1);

# now make sure they have two revs
foreach my $f (@out4)
{
    chomp $f;
    print "checking history of $f\n";
    $f=~s/%/%25/g;  # percent chars have to be escaped
    my @o = qx(svn log file://$repos/$f);
    ok(scalar(grep(/^r\d+ /, @o)), 2);
}

# clean up
rmtree($repos);
ok(not -d $repos);

exit 0;
