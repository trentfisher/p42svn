#!/usr/bin/env perl

=pod

=head1 NAME

B<p42svn> - dump Perforce repository in Subversion portable dump/load format.

=head1 SYNOPSIS

B<p42svn> [I<options>] [B<--branch> I<p4_branch_spec=svn_path>] ...

=head1 OPTIONS

=over 8


=item B<--help>

Print detailed help message and exit.

=item B<--usage>

Print brief usage message and exit.

=item B<--debug>

Print debug messages to STDERR.

=item B<--verbose>

Print status messages to STDERR.

=item B<--version>

Print out the version of this program, the P4 API, and Perl itself.

=item B<--dry-run>

Don't actually retrieve file data, but go through the motions. This is
useful for checking depot validity and for debugging.

=item B<--changes> I<list>

Specifies which changelists to process.  The list can contain a list of
numbers and ranges separated by commas, such as 12,39-45,68.

=item B<--revlimit> I<num>

Only convert the given number of revisions.  This is useful when
doing incremental imports (--changes) of parts of a depot (--branch).
In that case, saying --changes 32, may convert nothing if change 32
is not within the scope of the --branch specs.

=item B<--branch> I<p4_depot_spec=svn_path>

Specify mapping of Perforce branch to repository path.  Takes an
argument of the form p4_depot_spec=svn_path.  Multiple branch mappings
may be specified, but at least one is required.

=item B<--label> I<regexp=p4_depot_spec=svn_path>

Specify mapping of Perforce labels to repository path.  The regexp is
used to specify which labels to import, ".*" will match all labels.
The other two parameters are the same as the ones for --branch.

Alternately the keywords "each" or "all" may be given.  The keyword
"all" means that labels will be placed in a top level "tags" directory
for all branch mappings.  The keyword "each" means that labels will be
placed in a "tags" directory for each branch mapping.

For example, given the branch options
 --branch //p1=p1 --branch //p2=p2,
the option --label each would translate to
 --label ".*=//p1=/p1/tags" --label ".*=//p2=/p2/tags"
the option --label all would translate to
 --label ".*=//p1=/tags/p1" --label ".*=//p2=/tags/p2"

The keyword "none" may also be given.  This has the effect of canceling out
all other --label options on the command line.  This is really only useful
in when this is called from L<p42svnsync>.

=item B<--redolabels|--noredolabels>

Do/don't redo labels on files which already have already been tagged in SVN.
The default is to not redo labels.  The only reason to change this is if
you have labels moving onto different versions of the same files.

Only meaningful with --label, --changes, --existing-revs and --existing-files
(in other words, incremental imports).

=item B<--munge-keywords|--nomunge-keywords>

Do/don't convert Perforce keywords to their Subversion equivalent.
Default is not to perform keyword conversion.

=item B<--convert-eol|--noconvert-eol>

Do/don't set the svn:eol-style property for Perforce types text/unicode.
Default is not to set the svn:eol-style property.

=item B<--parse-mime-types|--noparse-mime-types>

Do/don't attempt to parse content MIME type and add svn:mime-type
property.  Default is not to parse MIME types.

=item B<--mime-magic-path> I<path>

Specify path of MIME magic file, overriding the default
F</usr/share/file/magic.mime>.  Ignored unless B<--parse-mime-types>
is true.

=item B<--delete-empty-dirs|--nodelete-empty-dirs>

Do/don't delete the parent directory when the last file/directory it
contains is deleted.  Default is to delete empty directories.

=item B<--user> I<name>

Specify Perforce username; this overrides $P4USER, $USER, and
$USERNAME in the environment.

=item B<--client> I<name>

Specify Perforce client; this overrides $P4CLIENT in the environment
and the default, the hostname.

=item B<--port> I<[host:]port>

Specify Perforce server and port; this overrides $P4PORT in the
environment and the default, perforce:1666.

=item B<--password> I<token>

Specify Perforce password; this overrides $P4PASSWD in the
environment.

=item B<--charset> I<token>

Specify Perforce charset; this overrides $P4CHARSET in the
environment

=item B<--fix-case> I<map|uc|lc|ucfirst>

If a Perforce repository is hosted on a case-insensitive filesystem
the depot may return pathnames with varying case.  The parameters
"uc", "lc", and "ucfirst" use the corresponding perl functions to
transform the case to a consistent name.  The parameter "map" tells
the converter to map all case variants to the first-encountered
variant.

=item B<--rawcharset> I<charset>

Interpret filenames according to the given character set when
converting filenames to utf8.  The default is to interpret filenames
as utf8.  A depot used exclusively by windows machines will likely
need to specify cp1252 here.

This may be specified multiple times, and all those character sets will be tried.
UTF8 will always be tried last.  If the file is not valid in any character set,
the non-ascii characters will be converted to hex strings.

Do not change this option between runs using --changes as new files
with variant filenames will be introduced.

=item B<--contentcache> I<directory>

Use the given directory as a cache for the contents of each file version.
The first time you run with this option the file contents will be pulled
from the Perforce depot and saved in the cache.  On subsequent runs, the
contents will be pulled from the cache rather than from Perforce.

This option is useful if the Perforce depot is distant or slow.  It
can also speed up imports by running through the process several
times, saving the cache, and then the production migration can be done
faster.

=item B<--save-changenum> I<prop,comm>

Instructs B<p42svn> to save the Perforce revision number in the
subversion dump file either as a property (if given "prop") or as an
addendum to the checkin comment (if given "comm"), or both (if given
"prop,comm" or "both").

=item B<--svn-change-prop> I<propname>

Set the svn revision property <propname> to the p4 change number,
Implies "--save-changenum prop".  Defaults to "p42svn:changenum".

=item B<--syncrevs>

Add in dummy revisions to ensure the Perforce change numbers and the
Subversion change numbers match exactly.  Probably only of use in full
depot conversions.  This will definitely not work in incremental
imports with labels.

=item B<--existing-files> I<file>

Load a file containing a list of files assumed to already exist 
in the svn repository (to be used in conjunction with --changes).
The list can be obtained from svn with the
command "svnlook tree --full-paths repositorypath"

=item B<--existing-revs> I<file>

Load a file containing an SVN log for mapping labels and branches to
their revisions (otherwise file contents will be imported with no
relatinoship to the previous history).  This assumes that previous
imports have used "--svn-changenum prop" (otherwise no Perforce
revision numbers will be found).
This output is generated with this command:

 svn log --xml --with-all-revprops <repository-url>

This will also cause the revision numbers to start at the next
available one in the target repository.  There will be trouble if
there are intervening checkins.

=item B<--skipcorrupt>

By default if a file's contents cannot be read from the Perforce server,
the program exits.  This option allows the conversion to continue if
the error indicates corruption in the depot.  This is useful if there
is corruption in the depot which cannot be fixed.

=item B<--partialrev|--nopartialrev>

If an error occurs while fetching things from Perforce, the dump file
could be truncated in a way that would not indicate that files are
missing in that revision.  That is the default behavior, the
option --nopartialrev will try to prevent this by dumping the error
messages into the dump file, which should cause svnadmin load to fail
without completing the in-progress transaction.

=item B<--verify>

Just get the change list from Perforce and compare it to what is in a
subversion repository.  You must specify --existing-revs, and that svn
log output must have the file changes (i.e. the -v option), and that
repository must have been generated with the option "--save-changenum
prop".

=item B<--stopfile> I<file>

If the given file is found, p42svn will stop at the end of the
revision/changelist currently being processed.
If not specified, the file monitored is
TMPDIR/p42svn.PID, where TMPDIR is the temporary directory returned by
L<File::Spec::tmpdir> and PID is the process id of the p42svn process.

=back

=head1 DESCRIPTION

B<p42svn> connects to a Perforce server and examines changelists
affecting the specified repository branch(es).  Records reflecting
each change are written to STDOUT in Subversion portable dump/load
format.  Each Perforce changelist corresponds to a single Subversion
revision.  Changelists restricted to files outside the specified
Perforce branch(es) are ignored.

Migration of a Perforce depot to Subversion can thus be achieved in
two easy steps:

=over 4

=item C<svnadmin create /path/to/repository>

=item C<p42svn --branch //depot/projectA=trunk/projectA | svnadmin load /path/to/repository>

=back

It is also possible to specify multiple branch mappings to change the
repository layout when migrating, for example:

=over 4

=item C<p42svn --branch //depot/projectA/devel=projectA/trunk --branch
//depot/projectA/release-1.0=projectA/tags/release1.0>

=back

=head1 REQUIREMENTS

This program requires the Perforce Perl API, which is available for
download from
E<lt>http://www.perforce.com/perforce/loadsupp.html#apiE<gt>.

Version 0.16 has been tested By Ray Miller against version 1.2587 of the P4 module built
against release 2002.2 of the Perforce API.

Versions 0.16, 0.17, and 0.18 have been tested by Dimitri Papadopoulos-Orfanos against
version 3.4804 of the P4 module built against release 2005.2 of the Perforce API.

Version 0.19 has been tested by Dimitri Papadopoulos-Orfanos against version 3.5708 of
the P4 module built against release 2006.1 of the Perforce API.

Version 0.21 has been tested by Dimitri Papadopoulos-Orfanos against version 2008.2 of
the Perforce Perl API and the Perforce C/C++ API.

Version 0.30 has been tested by Trent Fisher against version 2010.1 of
the Perforce Perl API and the Perforce C/C++ API.

=head1 VERSION

This is version 0.30.

=head1 AUTHOR

Ray Miller E<lt>ray@sysdev.oucs.ox.ac.ukE<gt>,
Dimitri Papadopoulos-Orfanos,
and
Trent Fisher.

=head1 SEE ALSO

The Subversion dump file format is documented at
http://svn.apache.org/repos/asf/subversion/trunk/notes/dump-load-format.txt

=head1 BUGS

Please report any bugs to the issue tracker
E<lt>http://p42svn.tigris.org/servlets/ProjectIssuesE<gt>.

Accuracy of determined MIME types is dependent on your system's MIME
magic data.  This program defaults to using data in
F</usr/share/file/magic.mime>.  This location appears to comply with
the Filesystem Hierarchy Standard (FHS) 2.3, although it may differ
from system to system in practice.

The B<--changes> option has known bugs unless used with the
--existing-files and --existing-revs options.  Even then there may be
subtle bugs remaining.  Also --existing-revs doesn't use a full XML
parser so if SVN changes their formatting, it could break.

The ETA calculations do not take into account the number of actions
being performed each rev.

The --syncrevs option may be ill-advised and incorrect in some cases.

=head1 COPYRIGHT

Copyright (C) 2010-2012 Oracle and/or its affiliates.

Copyright (C) 2006-2009 Commissariat a l'Energie Atomique

Copyright (C) 2003-2006 University of Oxford

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

use strict;
use warnings;

use P4;
use Data::Dumper;
use Date::Format;
use Digest::MD5 qw(md5_hex);
use File::MMagic;
use Getopt::Long;
use Pod::Usage;
use File::Temp;
use File::Spec;
use Encode qw(decode encode_utf8);

use constant MIME_MAGIC_PATH => '/usr/share/file/magic.mime';
use constant SVN_FS_DUMP_FORMAT_VERSION => 1;
use constant SVN_DATE_TEMPLATE => '%Y-%m-%dT%T.000000Z';

our (%rev_map, %rev_act, %dir_seen, %file_seen, %dir_usage, @deleted_files, @ranges);
my $svn_rev = 1;

our %KEYWORD_MAP = ('Author'   => 'LastChangedBy',
		    'Date'     => 'LastChangedDate',
		    'Revision' => 'LastChangedRevision',
		    'File'     => 'HeadURL',
		    'Id'       => 'Id');

use constant OPT_SPEC => qw(help usage debug verbose|v dry-run changes=s ignore!
                            branch=s% delete-empty-dirs! munge-keywords!
			    convert-eol! parse-mime-types! mime-magic-path=s
			    user=s client=s port=s password=s charset=s 
                            label=s@ fix-case=s save-changenum=s rawcharset=s 
                            contentcache=s syncrevs skipcorrupt partialrev!
                            existing-revs=s existing-files=s
                            redolabels! verify revlimit=i
                            svn-change-prop=s version);

our %options = ('help'              => 0,
		'usage'             => 0,
                'version'           => 0,
		'debug'             => 0,
		'verbose'           => 0,
		'dry-run'           => 0,
		'ignore'            => 1,
		'changes'           => undef,
		'delete-empty-dirs' => 1,
		'munge-keywords'    => 0,
		'convert-eol'       => 0,
		'parse-mime-types'  => 0,
		'label'             => [],
                'redolabels'        => 0,
                'fix-case'          => 0,
                'save-changenum'    => [],
                'rawcharset'        => [],
                'contentcache'      => 0,
                'syncrevs'          => 0,
		'existing-files'    => undef,
		'existing-revs'     => undef,
                'verify'            => undef,
                'svn-change-prop'   => undef,
                'skipcorrupt'       => undef,
                'partialrev'        => 1,
                'revlimit'          => 0,
                'stopfile'          => File::Spec->catfile(
                                          File::Spec->tmpdir(), "p42svn.$$"),
		'mime-magic-path'   => MIME_MAGIC_PATH,
		'branch'            => {});

########################################################################
# Identify Perforce Perl API version, so that we can adapt to the API.
########################################################################

my $p4perl_version = undef;

if (defined $P4::VERSION) {
    # This is original version of P4Perl from Tony Smith's page.
    # Latest version 3.6001 has been written for P4API 2007.2 or earlier.
    $p4perl_version = $P4::VERSION;
    $p4perl_version =~ s/^\s+//;
    $p4perl_version =~ s/\s+$//;
} else {
    # This the new version of the Perforce Perl API from the FTP server.
    # The Perforce Perl API is now released together with Perforce,
    # starting with 2007.3.
    $p4perl_version = P4::Identify();
    if ($p4perl_version =~ /P4PERL\/[^\/]+\/(\d+\.\d+)[^\/]*\/\d+/s) {
	$p4perl_version = $1;
    }
}

my $p42svn_version = 0.30;

########################################################################
# Print debugging messages when debug option is set.
########################################################################

sub debug {
    return unless $options{'debug'};
    print STDERR @_;
}

sub verbose {
    return unless $options{'verbose'} or $options{'debug'};
    if (ref $_[0] eq "CODE")
    {
        print STDERR $_[0]->();
    }
    else
    {
        print STDERR @_;
    }
}

# display seconds as days+hours:min:sec
sub hourminsec
{
    my $seconds = shift;
    my ($days,$hours,$minutes);

    $days =  int($seconds  / (24 * 3600));
    $seconds -= $days * (24 * 3600);
    $hours =  int($seconds / 3600);
    $seconds -= $hours * 3600;
    $minutes =  int($seconds / 60);
    $seconds -= $minutes * 60; 
    return sprintf("%d+%02d:%02d:%02d",
                   $days, $hours, $minutes, $seconds) if $days;
    return sprintf("%02d:%02d:%02d", $hours, $minutes, $seconds)
}

########################################################################
# Helper routines for option validation.
########################################################################

sub is_valid_depot {
    my $depot = shift;
    return $depot =~ m{^//([^/]+/?)*$};
}

sub is_valid_svnpath {
    my $path = shift;
    return $path =~ m{^/?([^/]+/?)*$};
}

########################################################################
# Helper routines for handling changelist ranges.
########################################################################

sub is_in_range {
    my $change = shift;
    return 1 unless @ranges;
    foreach (@ranges) {
	$_->[0] <= $change && $change <= $_->[1] && return 1;
    }
    return 0;
}

########################################################################
# Process command-line options.
########################################################################

sub process_options {
    GetOptions(\%options, OPT_SPEC) and @ARGV == 0
	or pod2usage(-exitval => 2, -verbose => 1);
    pod2usage(-exitval => 1, -verbose => 2)
	if $options{'help'};
    pod2usage(-exitval => 1, -verbose => 1)
	if $options{'usage'};
    if ($options{'version'}) {
        print "p42svn version $p42svn_version using p4perl $p4perl_version and perl $]\n";
        exit 0;
    }
    pod2usage(-exitval => 2, -verbose => 0,
              -message => "Must specify at least one branch or label")
	unless keys %{$options{'branch'}} || @{$options{'label'}};
    pod2usage(-exitval => 1, -verbose => 0,
              -message => "Must specify --existing-revs with --verify")
	if $options{'verify'} and not $options{'existing-revs'};
    if ($options{'stopfile'} and -e $options{'stopfile'}) {
        unlink($options{'stopfile'}) or
            die "Error: stopfile ".$options{'stopfile'}." cannot be removed: $!\n";
    }

    # the incoming character sets should always end with utf8
    push @{$options{'rawcharset'}}, "utf8";

    # Build list of [start,end] pairs (changelist ranges to process)
    if ($options{'changes'}) {
	foreach (split(/,/,$options{'changes'})) {
	    my @range = split(/-/,$_);
	    pod2usage(-exitval => 3, -verbose => 1,
	              -message => "Invalid range of changelists")
		if (@range > 2);
	    push(@ranges, [int($range[0]),int($range[$#range])]);
	}
    }

    # Validate and sanitize branch specifications
    while (my ($key, $val) = each %{$options{'branch'}}) {
	pod2usage(-exitval => 2, -verbose => 0,
	          -message => "Invalid Perforce depot specification: \"$key\"")
	    unless is_valid_depot($key);
	pod2usage(-exitval => 2, -verbose => 0,
	          -message => "Invalid Subversion repository path \"$val\"")
	    unless is_valid_svnpath($val);
        # make sure there's a trailing slash, if anything is there
	if ($val =~ m{.+[^/]$}) {
	    $options{'branch'}{$key} .= "/";
	}
	if ($key =~ m{[^/]$}) {
	    $options{'branch'}{"$key/"} = $options{'branch'}{$key};
	    delete $options{'branch'}{$key};
            $key .= "/";
	}
	debug("process_options: branch $key => $options{'branch'}{$key}\n");
    }

    # Validate and sanitize label specifications
    # first deal with special shorthand keywords
    # the keyword "none" will eliminate all label options
    $options{'label'} = [] if $options{'label'} and grep(/^none$/, @{$options{'label'}});

    # the keyword "all" means that all labels should go to a global /tags
    if ($options{'label'}[0] and $options{'label'}[0] eq "all") {
        $options{'label'} = [];
        while (my ($key, $val) = each %{$options{'branch'}}) {
            my $s = ".*=$key=tags/$val";
            push @{$options{'label'}}, $s;
            debug("process_options: all labels add $s\n");
        }
    # the keyword each means each label should go to separate tags dirs
    } elsif ($options{'label'}[0] and $options{'label'}[0] eq "each") {
        $options{'label'} = [];
        while (my ($key, $val) = each %{$options{'branch'}}) {
            my $s = ".*=$key=$val"."tags/";
            push @{$options{'label'}}, $s;
            debug("process_options: all labels add $s\n");
        }
    }
    foreach my $l (@{$options{'label'}}) {
        my ($labelre, $from, $to) = split(/=/, $l);
	pod2usage(-exitval => 2, -verbose => 0,
	          -message => "bad label substitution \"$l\"")
            unless defined $from && defined $to;
	pod2usage(-exitval => 2, -verbose => 0,
	          -message => "Invalid Perforce depot specification: \"$from\"")
	    unless is_valid_depot($from);
	pod2usage(-exitval => 2, -verbose => 0,
	          -message => "Invalid Subversion repository path \"$to\"")
	    unless $to eq "DISCARD" or is_valid_svnpath($to);

        # ensure paths end with a single slash and no leading slashes on svn dest
        $from =~ s,/*$,/,;
        $to  =~ s,/*$,/,;
        $to =~ s,^/+,,;
        $l = join("=", $labelre, $from, $to);
        
	debug("process_options: label $labelre => $from => $to\n");
    }

    # Load the directory usage
    if($options{'existing-files'}) {
        verbose("Loading existing files from ".$options{'existing-files'}."\n");
	local *EXF;
	open(EXF,'<',$options{'existing-files'}) or 
	    die("Cannot open $options{'existing-files'}: $!"); 
        binmode(EXF, ":utf8");
	my $f;
	while($f=<EXF>) {
	    chomp($f);
	    if($f=~/\/$/) {
		$dir_seen{$f}=1;
	    } else {
                $file_seen{$f}=1;
            }
            casemap($f);  # init casemap cache if needed
	    $dir_usage{parent_directory($f)}++;
	}
	close EXF;
    }

    # validate/fix the save-changenum arguments:
    # split up comma separated things, and substitute "both" with "prop,comm"
    $options{'save-changenum'} = [
        map(split(/,/, $_),
            grep(s/^(both|all)$/prop,comm/ || $_,
                map(split(/,/, $_), @{$options{'save-changenum'}})))];
    if (my @bad = grep($_ !~ /^(prop|comm)$/, @{$options{'save-changenum'}}))
    {
        die "Error: invalid --save-changenum argument @bad\n";
    }
    # if --svn-change-prop is set, make sure save-changenum is set too
    push @{$options{'save-changenum'}}, "prop"
        if $options{'svn-change-prop'};
    # set the default property name
    $options{'svn-change-prop'} = 'p42svn:changenum'
        unless $options{'svn-change-prop'};

    debug("process_options: save-changenum = ".join(", ", @{$options{'save-changenum'}})."\n");

    if($options{'existing-revs'}) {
        verbose("Loading existing revs from ".$options{'existing-revs'}."\n");
        # we expect output from svn log --xml --with-all-revprops
        # though we aren't doing full xml parsing
	local *EXR;
	open(EXR,'<',$options{'existing-revs'}) or 
	    die("Cannot open $options{'existing-revs'}: $!"); 
        binmode(EXR, ":utf8");
        my $f;
        my $rev;
        my $kind;
	while($f=<EXR>) {
            if ($f =~ /revision="(\d+)">/) {
                # this is also the svn rev used in the dump file
                $rev = $1;
                $svn_rev = $rev+1 if $rev > $svn_rev;
            }
            elsif ($f =~ m/name="$options{'svn-change-prop'}">(\d+)/) {
                # use the first rev we find, as earlier ones could
                # be incomplete
                if ($rev_map{$1}) {
                    warn "Warning: duplicate revision for p4 $1 in svn $rev (using ".$rev_map{$1}.")\n";
                } else {
                    $rev_map{$1} = $rev;
                }
            }
            elsif ($f =~ m/kind="(\w+)"/)
            {
                $kind = $1;
            }
            elsif ($f =~ m/action="(\w)">(.+)<\/path>/)
            {
                push @{$rev_act{$rev}}, {kind => $kind,
                                         action => $1,
                                         path => $2};
            }
        }
    }
}

########################################################################
# Does Perforce file lie in a branch we're processing?
######################################################################## 

sub is_wanted_file {
    my $filespec = shift;
    debug("is_wanted_file: $filespec\n");
    foreach (keys %{$options{'branch'}}) {
	debug("is_wanted_file: considering $_\n");
	return 1 if $filespec =~ /^$_/ and $options{'branch'}{$_} ne "EXCLUDE";
	return 1 if $options{'fix-case'} and $filespec =~ /^$_/i and $options{'branch'}{$_} ne "EXCLUDE";;
    }
    debug("is_wanted_file: ignoring $filespec\n");
    return 0;
}

########################################################################
# Map Perforce depot spec to Subversion path.
########################################################################

# fix any characters to conform to utf8
sub fixcharset {
    my $origional = shift;
    my $rawcharset;
    my $converted;
    foreach $rawcharset (@{$options{'rawcharset'}}) {
        my $d = $origional;  # we do this because decode can change it's arg
        $converted = eval { local $SIG{__DIE__} = "DEFAULT";
                            decode($rawcharset,
                                   $d, Encode::FB_CROAK); };
        last unless $@;
    }
    if (not $converted) {
        warn "Warning: Cannot convert string $origional to utf8, forcing to ascii: $@\n";
	$converted = $origional;
	$converted =~ s/([[:^ascii:]])/sprintf('=%X', ord($1))/ge;
    }

    # display the non ascii chars with hex codes
    if ($options{'debug'} and $converted ne $origional) {
        my $o = sprintf("depot2svnpath: mapping charset %5s: %s\n".
		        "                             to utf8: %s\n",
		            $rawcharset, $origional, $converted);
	$o =~ s/([[:^ascii:]])/sprintf('\\x{%x}', ord($1))/ge;
	debug($o);
    }

    # this doesn't really belong here... fix line endings
    $converted =~ s/\r//g;
    return $converted;
}

sub depot2svnpath {
    my $depot = shift;
    my $branches = $options{'branch'};
    my $key = undef;

    # first try to turn the pathname into valid utf8,
    # if it fails, issue a warning and do the conversion
    # such that a substitute utf8 char will be used instead
    $depot = fixcharset($depot);

    local $_;
    foreach (sort {length($a) <=> length($b)} keys %$branches) {
	if ($depot =~ /^$_/ or ($options{'fix-case'} and $depot =~ /^$_/i) ) {
 	    $key = $_;
 	    last;
 	}
    }
    return undef unless $key;

    my $svnpath = $depot;
    ($options{'fix-case'} ?
     $svnpath =~ s/^$key/$branches->{$key}/i :
     $svnpath =~ s/^$key/$branches->{$key}/) or
     warn "Error: unable to map $key to $branches->{$key}";
    $svnpath =~ s/%40/@/;
    $svnpath =~ s/%23/#/;
    $svnpath =~ s/%2a/*/;
    $svnpath =~ s/%25/%/;
    debug("depot2svnpath: $depot => $svnpath\n");

    $svnpath = casemap($svnpath);

    return $svnpath;
}

my $casemapcache = {};
sub casemap
{
    my $svnpath = shift;

    # if the depot is on a case-insensitive server we may get paths
    # with any case, so we try to map them to the first case we encountered
    if ($options{'fix-case'} =~ /^(uc|lc|ucfirst)$/i)
    {
        my $origsvnpath = $svnpath;

        # brute force... but fast... and less memory :)
        if    (lc($1) eq "lc")      { $svnpath = lc($svnpath); }
        elsif (lc($1) eq "uc")      { $svnpath = uc($svnpath); }
        elsif (lc($1) eq "ucfirst") {
            $svnpath =~ s,(/)([^/])([^/]*),$1.uc($2).lc($3),ge; }

        debug("casemap: mapping case $origsvnpath\n".
              "                   to $svnpath\n")
            if $origsvnpath ne $svnpath;
    }
    elsif ($options{'fix-case'} eq "map")
    {
        my $origsvnpath = $svnpath;
 
        my @path = split(m([\\/]), $svnpath);
        my $root = $casemapcache;
        my @mpath = ();

        while (@path)
        {
            my $this = shift @path;

            # create an entry if there isn't one
            $root->{lc($this)} = [$this, {}]
                if (not exists $root->{lc($this)});
            push @mpath, $root->{lc($this)}[0];
            # continue examining path
            $root = $root->{lc($this)}[1];
        }
        $svnpath = join("/", @mpath);

        debug("casemap: mapping case $origsvnpath\n".
              "                   to $svnpath\n")
            if $origsvnpath ne $svnpath;
    }
    return $svnpath;
}

########################################################################
# Helper routines for Perforce file types.
########################################################################

sub p4_has_keyword_expansion {
    my $type = shift;
    return $type =~ /^k/ || $type =~ /\+.*k/;
}

sub p4_has_executable_flag {
    my $type = shift;
    return $type =~ /^[cku]?x/ || $type =~ /\+.*x/;
}

sub p4_has_text_flag {
    my $type = shift;
    return $type =~ /text|unicode/;
}

########################################################################
# Return property list based on Perforce file type and (optionally)
# content MIME type.
########################################################################

my $mmagic;

sub properties {
    my ($type, $content_ref) = @_;
    my @properties;
    if (p4_has_keyword_expansion($type)) {
	push @properties, 'svn:keywords' => join(' ', values %KEYWORD_MAP);
    }
    if (p4_has_executable_flag($type)) {
	push @properties, 'svn:executable' => 'on';
    }
    if ($options{'convert-eol'} && p4_has_text_flag($type)) {
	push @properties, 'svn:eol-style' => 'native';
    }
    if ($options{'parse-mime-types'}) {
	unless ($mmagic) {
	    $mmagic = File::MMagic->new($options{'mime-magic-path'})
	      or die "Unable to open MIME magic file "
	        . $options{'mime-magic-path'} . $!;
	}
	my $mtype = $mmagic->checktype_contents($$content_ref);
	push(@properties, 'svn:mime-type' => $mtype) if $mtype;
    }
    return \@properties;
}

########################################################################
# Replace Perforce keywords in file content with equivalent Subversion
# keywords.
########################################################################

sub munge_keywords {
    return unless $options{'munge-keywords'};
    my $content_ref = shift;
    while (my ($key, $val) = each %KEYWORD_MAP) {
	$$content_ref =~ s/\$$key(?\:[^\$\n]*)?\$(\W)/\$$val\$$1/g;
    }
}

########################################################################
# Return parent directories of a path
########################################################################

sub parent_directories {
    my $path = shift;
    my @components;
    my $offset = 0;
    while ((my $ix = index($path, '/', $offset)) >= 0) {
	$offset = $ix + 1;
	push @components, substr($path, 0, $offset);
    }
    return @components;
}

########################################################################
# Return parent directory of a path
########################################################################

sub parent_directory {
    my $path = shift;
    (my $parent_dir = $path) =~ s|[^/]+/?$||;
    return $parent_dir;
}

########################################################################
# Convert Subversion property list to string.
########################################################################

sub svn_props2string {
    my $properties = shift;
    my $result;
    if (defined $properties) {
	while (my ($key, $val) = splice(@$properties, 0, 2)) {
	    $result .= sprintf("K %d\n%s\n", length($key), $key);
            # this string will be printed out in UTF8, so we
            # have to calculate the byte length based on that, but length()
            # will give us the number of characters, not encoded bytes
            # XXX do we need to do the same for the key?
	    $result .= sprintf("V %d\n%s\n", length(encode_utf8($val)), $val);
	    # $result .= sprintf("V %d\n%s\n", length($val), $val);
	}
    }
    $result .= 'PROPS-END';
    return $result;
}

########################################################################
# Routines to print Subversion records.
########################################################################

sub svn_dump_format_version {
    my ($version) = @_;
    print "SVN-fs-dump-format-version: $version\n\n";
}

sub svn_revision {
    my ($revision, $properties) = @_;
    my $ppty_txt = svn_props2string($properties);
    my $ppty_len = length(encode_utf8($ppty_txt)) + 1;
    binmode(STDOUT, ":utf8");
    print <<EOT;
Revision-number: $revision
Prop-content-length: $ppty_len
Content-length: $ppty_len

$ppty_txt

EOT
    binmode(STDOUT);
}

sub svn_add_dir {
    my ($path, $properties) = @_;
    $dir_usage{parent_directory($path)}++;
    my $ppty_txt = svn_props2string($properties);
    my $ppty_len = length($ppty_txt) + 1;
    binmode(STDOUT, ":utf8");
    print <<EOT;
Node-path: $path
Node-kind: dir
Node-action: add
Prop-content-length: $ppty_len
Content-length: $ppty_len

$ppty_txt

EOT
    binmode(STDOUT);
}

sub svn_add_file {
    my ($path, $properties, $text) = @_;
    $dir_usage{parent_directory($path)}++;
    my $ppty_txt = svn_props2string($properties);
    my $ppty_len = length($ppty_txt) + 1;
    my $text_len = length($$text);
    my $text_md5 = md5_hex($$text);
    my $content_len = $ppty_len + $text_len;
    binmode(STDOUT, ":utf8");
    print <<EOT;
Node-path: $path
Node-kind: file
Node-action: add
Text-content-length: $text_len
Text-content-md5: $text_md5
Prop-content-length: $ppty_len
Content-length: $content_len

$ppty_txt
EOT
    binmode(STDOUT);
    print $$text, "\n\n";
}

sub svn_add_symlink {
    my ($path, $properties, $text) = @_;
    push(@$properties, ('svn:special','*'));
    $text = "link ".$$text;
    svn_add_file($path, $properties, \$text);
}

sub svn_edit_file {
    my ($path, $properties, $text) = @_;
    my $ppty_txt = svn_props2string($properties);
    my $ppty_len = length($ppty_txt) + 1;
    my $text_len = length($$text);
    my $text_md5 = md5_hex($$text);
    my $content_len = $ppty_len + $text_len;
    binmode(STDOUT, ":utf8");
    print <<EOT;
Node-path: $path
Node-kind: file
Node-action: change
Text-content-length: $text_len
Text-content-md5: $text_md5
Prop-content-length: $ppty_len
Content-length: $content_len

$ppty_txt
EOT
    binmode(STDOUT);
    print $$text, "\n\n";
}

sub svn_edit_symlink {
    my ($path, $properties, $text) = @_;
    push(@$properties, ('svn:special','*'));
    $text = "link ".$$text;
    svn_edit_file($path, $properties, \$text);
}

sub svn_delete {
    my ($path) = @_;
    $dir_usage{parent_directory($path)}--;

    binmode(STDOUT, ":utf8");
    print <<EOT;
Node-path: $path
Node-action: delete

EOT
    binmode(STDOUT);
}

sub svn_add_copy {
    my ($path, $from_path, $from_rev) = @_;
    $dir_usage{parent_directory($path)}++;
    binmode(STDOUT, ":utf8");
    print <<EOT;
Node-path: $path
Node-kind: file
Node-action: add
Node-copyfrom-rev: $from_rev
Node-copyfrom-path: $from_path

EOT
    binmode(STDOUT);
}

sub svn_replace_copy {
    my ($path, $from_path, $from_rev) = @_;
    binmode(STDOUT, ":utf8");
    print <<EOT;
Node-path: $path
Node-kind: file
Node-action: replace
Node-copyfrom-rev: $from_rev
Node-copyfrom-path: $from_path

EOT
    binmode(STDOUT);
}

sub svn_add_parent_dirs {
    my $svn_path = shift;
    debug("svn_add_parent_dirs: $svn_path\n");
    foreach my $dir (parent_directories($svn_path)) {
	next if ($dir eq '/') or $dir_seen{$dir}++;

        # if this was previously seen as a file, we have to remove
        # the file to make way for the directory
        if ($dir =~ m,(.*)/$, and $file_seen{$1}) {
            my $f = $1;
            svn_delete($f);
            delete $file_seen{$f};
            debug("svn_add_parent_dirs: changing file to dir $dir\n");
        }
#	debug("svn_add_parent_dirs: adding $dir\n");
	svn_add_dir($dir, undef);
    }
}

sub svn_delete_empty_parent_dirs {
    return unless $options{'delete-empty-dirs'} && @_;
    debug("svn_delete_empty_parent_dirs: passed @_\n");

    my @deleted_dirs;
    for (@_) {
	$_ = parent_directory($_) or next;
	debug("svn_delete_empty_parent_dirs: $_ usage $dir_usage{$_}\n");
	if ($dir_usage{$_} == 0 && $dir_seen{$_} > 0) {
	    debug("svn_delete_empty_parent_dirs: deleting $_\n");
	    svn_delete($_);
	    $dir_seen{$_} = 0;
	    push(@deleted_dirs, $_);
	}
    }

    svn_delete_empty_parent_dirs(@deleted_dirs);
}

#########################################################################
# Routines for interacting with Perforce server.
#########################################################################

my $p4 = undef;

sub p4_init {
    if(defined $p4 and $p4->IsConnected()) {
 	return $p4;
     }
    $p4 = P4->new();
    $p4->SetUser($options{'user'}) if $options{'user'};
    $p4->SetClient($options{'client'}) if $options{'client'};
    $p4->SetPort($options{'port'}) if $options{'port'};
    $p4->SetPassword($options{'password'}) if $options{'password'};
    $p4->SetCharset($options{'charset'}) if $options{'charset'};
    if ($p4perl_version < 2007.3) {
	$p4->ParseForms();
    } else {
	$p4->SetVersion("p42svn $p42svn_version");
    }
    $p4->Connect() or die "Failed to connect to Perforce server ", $p4->GetPort();
    return $p4;
}

#
# Discard changelists outside of specified branches.
#
sub p4_get_changes {
    my $p4 = p4_init();
    my @changes;

    # Consider only changelists related to the specified branch mappings.
    foreach my $branch (keys %{$options{'branch'}}) {
	debug("p4_get_changes: branch $branch\n");
	push @changes, $p4->Run('changes', $branch . "...");
	die $p4->Errors() if $p4->ErrorCount();
    }

    # Remove duplicates.
    my %seen = map {$_->{'change'} => 1} @changes;

    # Filter out changelists outside of the specified ranges and sort.
    return sort {$a <=> $b} grep {is_in_range $_} keys %seen;
}

sub p4_get_change_details {
    my $change_num = shift;
    debug("p4_get_change_details: $change_num\n");
    my $p4 = p4_init();
    my $change = ($p4->Run('describe', '-s', $change_num))[0];
    my $error_count = $p4->ErrorCount();
    my $errors = $p4->Errors();
    if ($error_count) {
	warn "Skipping $change_num due to errors:\n$errors\n";
	return undef;
    }
    my %result;
    $result{'author'} = $change->{'user'};
    $result{'log'}  = $change->{'desc'};
    $result{'time'} = $change->{'time'};
    $result{'date'} = time2str(SVN_DATE_TEMPLATE, $change->{'time'}, "UTC");
    for (my $i = 0; $i < @{$change->{'depotFile'}}; $i++) {
	my $file = $change->{'depotFile'}[$i];
	my $action = $change->{'action'}[$i];
	my $type = $change->{'type'}[$i];
	if (is_wanted_file($file)) {
	    push @{$result{'actions'}}, {'action' => $action,
	                                 'path' => $file,
	                                 'type' => $type};
	}
    }

    # fix the order of actions so that move/delete comes after move/add
    @{$result{'actions'}} = sort {
        return 0 unless $a->{'action'} =~ /^move/ and $b->{'action'} =~ /^move/;
        return $a->{'action'} cmp $b->{'action'};  # add < delete
    } @{$result{'actions'}};

    return \%result;
}

sub p4_get_labels {
    return unless @{$options{'label'}};
    my $p4 = p4_init();
    my $labels = $p4->Run('labels');
    my $error_count = $p4->ErrorCount();
    my $errors = $p4->Errors();
    if ($error_count) {
	warn "Skipping due to errors:\n$errors\n";
	return undef;
    }

    my @results;
    foreach my $label (@$labels) {
        $label->{tagmap} = [];
        foreach my $l (@{$options{'label'}}) {
            my ($labelre, $from, $to) = split(/=/, $l);
            if ( $label->{'label'} =~ /^$labelre$/ ) {
                die "bad label substitution $l" unless defined $from && defined $to;
                push @{$label->{tagmap}}, [qr($from), $to.$label->{'label'}."/"];
                # just in case
                if (not $label->{Update})
                {
                    warn "Error: the label ".$label->{'label'}." does not have a timestamp, using now\n";
                    $label->{Update} = time;
                }
                debug("p4_get_labels: got ".$label->{'label'}." from $from to $to\n");
            }
        }
    }

    return sort { $a->{Update} <=> $b->{Update} } @$labels;
    return @$labels;
}

sub p4_get_label_files {
    my $label = shift;
    my $labelname = $label->{label};
    my $p4 = p4_init();
    my $files = $p4->Run('files', "\@$labelname");
    my $error_count = $p4->ErrorCount();
    my $errors = $p4->Errors();
    if ($error_count) {
	warn "Skipping label \"$labelname\" due to errors:\n$errors\n";
	return undef;
    }

    # Subversion can't handle labeling (copying) deleted files.
    my($file, @retfiles);
    foreach $file (@$files) {
        if ( $file->{action} eq 'delete' or
             $file->{action} eq 'move/delete' or $file->{action} eq 'purge') {
            debug("p4_get_label_files: skipping $file->{depotFile}\@$file->{change} ($file->{action})\n");
            next;
        }

        # now see if this labeled file falls within the requested paths
        my $svn_path = $file->{depotFile};
        foreach my $t (@{$label->{tagmap}}) {
            last if ($svn_path =~ s/$t->[0]/$t->[1]/);
            last if ($options{'fix-case'} and $svn_path =~ s/$t->[0]/$t->[1]/i);
        }

        # if the given file doesn't get remapped to an SVN path, it
        # must fall outsite our label mapping, skip it.
        if ($svn_path eq $file->{depotFile}) {
            debug("p4_get_label_files: no label substitution for $svn_path, skipping\n");
            next;
        }
        if ($svn_path =~ /^DISCARD/) {
            debug("p4_get_label_files: label substitution for $svn_path is DISCARD, skipping\n");
            next;
        }

        # if this file is already in the svn tag, skip it
        # unless the redolabels option indicates to do it anyway.
        if (not $options{'redolabels'} and
            ($file_seen{$svn_path} or $dir_seen{$svn_path})) {
            debug("p4_get_label_files: labeled path $svn_path already in svn, skipping\n");
            next;
        }

        $file->{svn_path} = $svn_path;

        push(@retfiles, $file);
    }
    return \@retfiles;
}

#
# get the contents of a given file@version
# This has been rewritten to write to a temp file and eliminate fork.
# this is then read in and returned as a reference, which will allow
# far larger files to be returned without running out of memory
#
my $get_file_content_tmpfile;
(undef, $get_file_content_tmpfile) =
    File::Temp::tempfile("p42svn_get_XXXX", TMPDIR => 1, UNLINK =>1);
# this code stolen from URI::Escape which may not be everywhere
# Build a char->hex map
my %escapes;
for (0..255) {  $escapes{chr($_)} = sprintf("%%%02X", $_); }
sub uri_escape
{
    my $text = shift;
    return undef unless defined $text;
    $text =~ s/([^A-Za-z0-9\-_.\/])/$escapes{$1}/ge;
    return $text;
}
# generate the filename we will use to store the file contents
# either a file in our cache, or a tmp file
sub get_file_content_cachefile
{
    my $path = shift;
    if ($options{'contentcache'} && $path =~ /(.+)@(.+)/)
    {
        my $file = $1;
        my $ver = $2;
        return join("/", $options{'contentcache'},
                    split(//, $ver), uri_escape($file));
    }
    return $get_file_content_tmpfile;
}

sub p4_get_file_content {
    my $filespec = shift;
    if ($options{'dry-run'})
    {
        my $p ='Content placeholder!';
        return \$p;
    }
    debug("p4_get_file_content: $filespec\n");

    my $contentfile = get_file_content_cachefile($filespec);
    unless ($options{'contentcache'} and
            (-f $contentfile or -l $contentfile))
    {
    my $p4 = p4_init();
    my $result = undef;
    $result = $p4->Run('print', '-o', $contentfile, $filespec);
    #print STDERR Dumper($result),"\n";
    # massage result to be a single hash
    $result = $result->[0] if ref $result eq 'ARRAY';
    if ($p4->ErrorCount() or not $result or not $result->{depotFile})
    {
        # if we get an error indicating repository corruption and
        # the option for skipping such problems is enabled, 
        # put placeholder content in place
        my $errs = ($p4->ErrorCount() ? $p4->Errors() :
                    "Perforce print $filespec returned empty results and no error.");
        if ($options{'skipcorrupt'} and
            (not $p4->ErrorCount() or
             ($errs =~ /Librarian checkout .+ failed/ or
              $errs =~ /Gzip magic header wrong/)))
        {
            warn "Warning: $filespec is corrupt, inserting placeholder:\n$errs\n";
            my $content = "VERSION CORRUPTED in P4 Depot for $filespec\n$errs\n";
            return \$content;
        }
        die $errs."\n";
    }
    }

    # The "file" could really be a symlink, so we need to read the link
    # target and hand that over as the content
    # I have no idea what to do about this on Windows
    if (-l $contentfile)
    {
        my $content = readlink($contentfile);
        debug("p4_get_file_content: got symlink to $content\n");
        return \$content;
    }
    local *P4_OUTPUT;
    local $/ = undef;
    open(P4_OUTPUT, $contentfile) or
        die "Error: reading p4 output from $contentfile for $filespec failed: $!\n";
    my $content = <P4_OUTPUT>;
    close(P4_OUTPUT) or die "Close failed: ($?) $!";
    debug("p4_get_file_content: got ".length($content)." bytes\n");
    return \$content;
}

#
# Depending on the version of Perforce, Diff2() may return an
# ARRAY of SCALAR, A HASH, or an ARRAY of HASH.
#
sub p4_files_are_identical {
    my ($src_fspec, $dst_fspec) = @_;
    debug("p4_files_are_identical: @_\n");
    my $p4 = p4_init();
    my $result = $p4->Run('diff2', $src_fspec, $dst_fspec);
    if ($p4->ErrorCount())
    {
        warn "Error: diff2 $src_fspec, $dst_fspec, ".$p4->Errors();
        exit 1 unless $options{'skipcorrupt'};
        return 0; 
    }
    $p4->Disconnect();
    #print STDERR Dumper($result),"\n";
    if (ref $result eq 'ARRAY') {
	if (ref $result->[0] eq 'HASH') { # Perforce 2006.2
	    $result = $result->[0]->{'status'};
	} elsif ($result->[0] and not ref $result->[0] and $result->[0] =~ /===\s*(\w*)\s*$/) { # Perforce 2003.1
	    $result = $1;
	} else {
	    warn "Command 'diff2 $src_fspec $dst_fspec' returns ARRAY containing unexpected item";
            return 0 if $options{'skipcorrupt'};
            exit 1;
	}
    } elsif (ref $result eq 'HASH') {  # Perforce 2005.1
	$result = $result->{'status'};
    } else {
        warn "Command 'diff2 $src_fspec $dst_fspec' returns ", ref $result, ", expected ARRAY or HASH instead";
        return 0 if $options{'skipcorrupt'};
        exit 1;
    }
    debug("p4_files_are_identical: $result\n");
    return $result eq 'identical';
}

#
# If $path was not modified by this $change, return (undef, undef),
# which signals to the caller to ignore this file.  If we are unable,
# for any reason, to determine the source of a branch/integrate,
# return (undef, -n), signalling to the caller to treat this as an
# add/edit.
#
sub p4_get_copyfrom_filerev {
    my ($path, $change) = @_;
    debug("p4_get_copyfrom_filerev: passed $path\@$change\n");
    if ($change > 1 && p4_files_are_identical($path.'@'.$change,
                                              $path.'@'.($change-1))) {
	debug("p4_get_copyfrom_filerev: $path\@$change unchanged\n");
        if ( $options{'ignore'} ) {
            return (undef, undef);
        }
        else {
            warn "$path\@$change unchanged but not returning ignore\n";
        }
    }
    my $p4 = p4_init();
    my $result = $p4->Run('filelog', "$path\@$change");
    die $p4->Errors() if $p4->ErrorCount();
    if (ref $result eq 'ARRAY') { # Perforce 2006.2
	unless (ref $result->[0] eq 'HASH') {
	    die "Command 'filelog' returns an ARRAY missing a HASH";
	}
	$result = $result->[0];   # Now in the Perforce 2005.1 case
    }
    if (ref $result eq 'HASH') {  # Perforce 2005.1
	unless ($result->{'how'} && defined $result->{'how'}->[0]) {
	    debug("p4_get_copyfrom_filerev: returning undef#-1\n");
	    return (undef, -1);
	}

        # Perforce 2002.2 can return empty (undef) slots... convert them
        # to empty lists, so the code below doesn't crash
        grep((!defined $result->{'how'}[$_] and $result->{'how'}[$_] = []),
             0..$#{$result->{'how'}});

	my $i;
        # If this version is not a branch, it will be undef
        if ( ref($result->{'how'}->[0]) ne 'ARRAY' ) {
            debug("p4_get_copyfrom_filerev: $path\@$change is not a branch action.  returning undef#-3\n");
            return (undef, -3);
        }
	for ($i = 0; $i < @{$result->{'how'}->[0]}; $i++) {
	    last if $result->{'how'}->[0][$i] =~ /from$/;
	}
	if ($i > $#{$result->{'how'}->[0]}) {
	    debug("p4_get_copyfrom_filerev: returning undef#-2)\n");
	    return (undef, -2);
	}
	my $copyfrom_path = $result->{'file'}[0][$i];
	my $copyfrom_rev  = $result->{'erev'}[0][$i];
	debug("p4_get_copyfrom_filerev: returning $copyfrom_path$copyfrom_rev\n");

        # check if the integrate/branch is coming from outside our branch spec
        if (not depot2svnpath($copyfrom_path))
        {
            debug("p4_get_copyfrom_filerev: outside branch spec, treating as add/edit\n");
            return (undef, -4);
        }

	return ($copyfrom_path, $copyfrom_rev);
    }
    die "Command 'filelog' returns ", ref $result, ", expected ARRAY or HASH instead";
}

########################################################################
# Return Subversion revision of Perforce file at given revision.
########################################################################

sub p4_file2svnrev {
    my ($file, $rev) = @_;
    debug("p4_file2svnrev: $file$rev\n");
    my $change;
    if ( $rev =~ /^\@(.*)$/ ) {
        $change = $1;
    }
    else {
        my $p4 = p4_init();
        my $result = $p4->Run('filelog', $file . $rev);
        die $p4->Errors() if $p4->ErrorCount();
        if (ref $result eq 'ARRAY') { # Perforce 2006.2
            unless (ref $result->[0] eq 'HASH') {
                die "Command 'filelog' returns an ARRAY missing a HASH";
            }
            $result = $result->[0];   # Now in the Perforce 2005.1 case
        }
        if (ref $result eq 'HASH') {  # Perforce 2005.1
            $change = shift @{$result->{'change'}};
        }
        else {
            die "Command 'filelog' returns ", ref $result, ", expected ARRAY or HASH instead";
        }
    }
    if ($rev_map{$change} or is_in_range($change)) {
        debug("p4_file2svnrev: p4 $change to svn r$rev_map{$change}\n");
        return $rev_map{$change};
    } else {
        debug("p4_file2svnrev: $change is not within specified changelists\n");
        return -1;
    }
}

########################################################################
# Routines for converting Perforce actions to Subversion dump/restore
# records.
########################################################################

sub p4add2svn {
    my ($path, $type, $change) = @_;
    debug("p4add2svn: $path\@$change\n");
    my $svn_path = depot2svnpath($path)
      or die "Unable to determine SVN path for $path\n";
    svn_add_parent_dirs($svn_path);
    my $content = p4_get_file_content("$path\@$change");
    munge_keywords($content) if p4_has_text_flag($type);
    chomp $$content if $type =~ /symlink$/;
    my $properties = properties($type, $content);

    # doing another add probably means we are changing a file type
    if ($dir_seen{$svn_path."/"}) {
        debug("p4add2svn: duplicate add of $path\n");
        svn_delete($svn_path);
        foreach my $s ($svn_path,
                       grep(m,^$svn_path/,, keys %file_seen),
                       grep(m,^$svn_path/,, keys %dir_seen))
        {
            $file_seen{$s} = $dir_seen{$s} = 0;
        }
    }

    if ($type =~ /symlink$/) {
        svn_add_symlink($svn_path, $properties, $content);
    } else {
        if ($file_seen{$svn_path}) {
            svn_edit_file($svn_path, $properties, $content);
        } else {
            svn_add_file($svn_path, $properties, $content);
        }
    }
    $file_seen{$svn_path}++;
}

sub p4delete2svn {
    my ($path, $type, $change) = @_;
    debug("p4delete2svn: $path\@$change\n");
    my $svn_path = depot2svnpath($path)
      or die "Unable to determine SVN path for $path\n";
    svn_delete($svn_path) if $file_seen{$svn_path};
    # mark the directory and everything under it as deleted
    foreach my $s ($svn_path,
                   grep(m,^$svn_path/,, keys %file_seen),
                   grep(m,^$svn_path/,, keys %dir_seen))
    {
        $file_seen{$s} = $dir_seen{$s} = 0;
    }
    push @deleted_files, $svn_path;
}

sub p4edit2svn {
    my ($path, $type, $change) = @_;
    debug("p4edit2svn: $path\@$change\n");
    my $svn_path = depot2svnpath($path)
      or die "Unable to determine SVN path for $path\n";
    my $content = p4_get_file_content("$path\@$change");
    munge_keywords($content) if p4_has_text_flag($type);
    chop $$content if $type =~ /symlink$/;
    my $properties = properties($type, $content);
    if ($type =~ /symlink$/) {
        svn_edit_symlink($svn_path, $properties, $content);
    } else {
        if ($file_seen{$svn_path}++) {
            svn_edit_file($svn_path, $properties, $content);
        } else {
	    svn_add_parent_dirs($svn_path);
            svn_add_file($svn_path, $properties, $content);
        }
    }
}

sub p4label2svn {
    my ($path, $type, $change, $svn_path) = @_;

    debug("p4label2svn: $path\@$change -> $svn_path\n");

    # for copy/paste code from p4branch2svn to work
    my $from_path = $path;
    my $from_rev = '@' . $change;

    my $svn_from_path = depot2svnpath($from_path);
    my $svn_from_rev;
    if ($svn_from_path) {
	# Source is within specified branches
        debug("p4label2svn: path for label $from_path -> $svn_from_path\n");
        svn_add_parent_dirs($svn_path);
	$svn_from_rev = p4_file2svnrev($from_path, $from_rev);
        if (not $file_seen{$svn_from_path}) {
            warn "Warning: label src path $svn_from_path not found\n";
        }
	elsif ($svn_from_rev > 0) {
	    # Initial changelist falls within specified changelists
	    svn_add_copy($svn_path, $svn_from_path, $svn_from_rev);
	    return;
	}
    } else {
        # if the labeled files are out of specified branches, we skip it
        debug("p4label2svn: path for label $from_path is outside of branch mappings, skipping\n");
        return;
    }

    # Outside of specified changelists: treat as add
    warn "Warning: unable to find rev for tag $svn_path, to tag $from_path\@$from_rev, copying full contents\n";
    my $content = p4_get_file_content($from_path . $from_rev);
    munge_keywords($content) if p4_has_text_flag($type);
    my $properties = properties($type, $content);
    push(@$properties, "p42svn:notes",
         "should be copy from $path\@$change in Perforce, ".
         "and $svn_from_path\@".($svn_from_rev||"?")." in Subversion");
    svn_add_file($svn_path, $properties, $content);
}

sub p4branch2svn {
    my ($path, $type, $change) = @_;
    debug("p4branch2svn: $path\@$change\n");
    my $svn_path = depot2svnpath($path)
      or die "Unable to determine SVN path for $path\n";
    my ($from_path, $from_rev) = p4_get_copyfrom_filerev($path, $change);
    unless ($from_path) {
	if ($from_rev) {
            debug("p4branch2svn: unable to locate the source branch, treating as add\n");
	    p4add2svn($path, $type, $change);
	} else {
	    warn "Ignoring $path\@$change\n";
	}
	return;
    }
    debug("p4branch2svn: switch to $from_path\@$from_rev\n");
    unless (p4_files_are_identical($from_path.$from_rev, "$path\@$change")) {
	p4add2svn($path, $type, $change);
	return;
    }
    svn_add_parent_dirs($svn_path);
    my $svn_from_path = depot2svnpath($from_path);
    if ($svn_from_path and $file_seen{$svn_from_path}) {
	# Source is within specified branches
	my $svn_from_rev = p4_file2svnrev($from_path, $from_rev);
	if ($svn_from_rev > 0) {
	    # Initial changelist falls within specified changelists
            if ($file_seen{$svn_path}++) {
                svn_replace_copy($svn_path, $svn_from_path, $svn_from_rev);
            } else {
                svn_add_copy($svn_path, $svn_from_path, $svn_from_rev);
            }
	    return;
	}
    }
    # Outside of specified branches or changelists: treat as add
    my $content = p4_get_file_content($from_path . $from_rev);
    munge_keywords($content) if p4_has_text_flag($type);
    my $properties = properties($type, $content);
    if ($file_seen{$svn_path}++) {
        svn_edit_file($svn_path, $properties, $content);
    } else {
        svn_add_file($svn_path, $properties, $content);
    }
}

sub p4integrate2svn {
    my ($path, $type, $change) = @_;
    debug("p4integrate2svn: $path\@$change\n");
    my $svn_path = depot2svnpath($path)
      or die "Unable to determine SVN path for $path\n";
    my ($from_path, $from_rev) = p4_get_copyfrom_filerev($path, $change);
    if ($from_path) {
	debug("p4integrate2svn: switch to $from_path\@$from_rev\n");
    } else {
	debug("p4integrate2svn: uninitialized \$from_path: empty integration?\n");
	if ($from_rev) {
	    p4edit2svn($path, $type, $change);
	} else {
	    warn "Ignoring $path\@$change\n";
	}
	return;
    }
    unless (p4_files_are_identical($from_path.$from_rev, "$path\@$change")) {
	p4edit2svn($path, $type, $change);
	return;
    }
    my $svn_from_path = depot2svnpath($from_path);
    if ($svn_from_path and $file_seen{$svn_from_path}) {
	# Source is within specified branches
	my $svn_from_rev  = p4_file2svnrev($from_path, $from_rev);
	if ($svn_from_rev > 0) {
	    # Initial changelist falls within specified changelists
            if ($file_seen{$svn_path}++) {
                svn_replace_copy($svn_path, $svn_from_path, $svn_from_rev);
            } else {
                svn_add_parent_dirs($svn_path);
                svn_add_copy($svn_path, $svn_from_path, $svn_from_rev);
            }
	    return;
	}
    }
    # Outside of specified branches or changelists: treat as edit
    my $content = p4_get_file_content($from_path . $from_rev);
    munge_keywords($content) if p4_has_text_flag($type);
    my $properties = properties($type, $content);
    if ($file_seen{$svn_path}++) {
        svn_edit_file($svn_path, $properties, $content);
    } else {
        svn_add_file($svn_path, $properties, $content);
    }
}

sub p4purge2svn {
    my ($path, $type, $change) = @_;
    debug("p4purge2svn: $path\@$change\n");

    return p4delete2svn($path, $type, $change);

    # XXX this seems dead wrong, hence the line above
    my $svn_path = depot2svnpath($path)
	or die "Unable to determine SVN path for $path\n";
    svn_add_parent_dirs($svn_path);
    my $content = "Placeholder for file purged by Perforce.";
    my $properties = properties($type, \$content);
    svn_add_file($svn_path, $properties, \$content);
}

# verify a given revision
# This assumes we have %rev_act filled in, which means --existing-revs must
# be given verbose output from svn log.
sub verifyrev
{
    my $change_num = shift;
    my $details = shift;

    verbose("Verifying P4 rev $change_num".
            ($rev_map{$change_num} ? " svn rev ".$rev_map{$change_num} :
             " no svn rev")."\n");

    # first check if svn has the matching revision
    if (not exists $rev_map{$change_num}) {
        warn "Error: p4 rev $change_num is missing from svn\n";
        return undef;
    }

    debug("verifyrev: p4 actions ".
          ($#{$details->{actions}}+1)." svn actions ".
          ($#{$rev_act{$rev_map{$change_num}}}+1)."\n");

    # first build a hash of the files changed in svn
    my %svn_act_map = map(($_->{path}, 1), @{$rev_act{$rev_map{$change_num}}});
    
    # now go through each action ensuring that svn has matching actions
    ACTION: foreach my $act (@{$details->{actions}}) {
        my $svn_path = depot2svnpath($act->{path})
            or die "Error: Unable to determine SVN path for $act->{path}\n";
        $svn_path = "/".$svn_path;
        
        next if exists $svn_act_map{$svn_path};

        # if files get deleted and a directory gets emptied
        # that ends up as a directory remove, so check for that
        # if the above doesn't work
        if ($act->{action} eq "delete") {
            my $p = $svn_path;
            while ($p =~ s,^(.+)/[^/]+$,$1,) {
                next ACTION if $svn_act_map{$p};
            }
        }
        # if we get here, we couldn't find a matching action
        warn sprintf("Error: action %s missing in svn rev %d %s from p4 rev %d %s\n",
                     $act->{action},
                     $rev_map{$change_num}, $svn_path,
                     $change_num, $act->{path});
    }

    return 1;
}

########################################################################
# Main processing
########################################################################

process_options();

my %p42svn = ('add'       => \&p4add2svn,
              'delete'    => \&p4delete2svn,
              'edit'      => \&p4edit2svn,
              'branch'    => \&p4branch2svn,
              'integrate' => \&p4integrate2svn,
              'purge'     => \&p4purge2svn,
              'move/delete' => \&p4delete2svn,
              'move/add'    => \&p4branch2svn);

my $last_time;   # timestamp on last revision... needed for syncrevs

binmode(STDOUT);
binmode(STDERR, ":utf8");
svn_dump_format_version(SVN_FS_DUMP_FORMAT_VERSION)
    unless $options{'verify'};
verbose("Fetching perforce change list\n");
my @changes = p4_get_changes();
debug(sprintf "got %d changes from %d to %d\n",
      $#changes+1, $changes[0], $changes[$#changes]) if @changes;
if ($options{'syncrevs'}) {
    $svn_rev = $changes[0];
    $svn_rev = $1 if $options{'changes'} and $options{'changes'} =~ /^(\d+)/;
}
my $svn_rev_start = $svn_rev;

verbose("Fetching perforce label list\n");
my @labels = p4_get_labels();
verbose("Found ".(1+$#labels)." Perforce labels\n");

# we do this so that if we die, we will corrupt the svn dump file to prevent
# a partial transaction from getting in
$SIG{__DIE__} = sub { print @_; die @_; } if not $options{'partialrev'};

# unified loop for handling labels and changes... we do this to create labels in the
# right chronological order.
# TBD fix sub-optimal behavior... p4_get_change_details can be run repeatedly
# on the same rev and the evaluation of whether a label already exists is done
# after evaluating every file in a label.
my $change_idx = 0;
my $label_idx = 0;
while ($change_idx <= $#changes or $label_idx <= $#labels)
{
    my $change_num = $changes[$change_idx];

    my $details = p4_get_change_details($change_num);
    unless (defined $details) {
        debug("no changes for change $change_num, skipping\n");
        $change_idx++;
        next;
    }

    # first check if any labels need to be created
    if (exists($labels[$label_idx]) and $labels[$label_idx]->{'Update'} < $details->{'time'}) {
        my $label = $labels[$label_idx];

        if ($options{'verify'}) {
            # TBD not sure what to do here
            $label_idx++;
            next;
        }

        # get the list of affected files, if none, skip
        my $files = p4_get_label_files($label);
        unless ($files and @$files) {
            $label_idx++;
            next;
        }

        verbose("p4 label ".$label->{'label'}." to svn revision ".$svn_rev.
                " (".(1+$#$files)." files)\n");
        my @properties = ('svn:log'    => fixcharset($label->{'Description'}),
                          'svn:author' => $label->{'Owner'},
                          'svn:date'   => time2str(SVN_DATE_TEMPLATE,
                                                   $label->{'Update'}, "UTC"));

        # optionally save perforce change numbers
        push @properties, ($options{'svn-change-prop'} => $label->{label})
            if (grep(/^prop$/, @{$options{'save-changenum'}}));
        $properties[1] .= "\n\nPerforce label ".$label->{label}
            if (grep(/^comm$/, @{$options{'save-changenum'}}));

        svn_revision($svn_rev++, \@properties);
        foreach my $file (@$files) {
            p4label2svn($file->{'depotFile'}, $file->{'type'}, $file->{'change'},
                        $file->{'svn_path'});
        }

        # bail out if we've done the number of revs desired
        if ($options{'revlimit'} and
            $svn_rev-$svn_rev_start >= $options{'revlimit'}) {
            last;
        }
        # bail out if we've been asked to do so
        if ($options{'stopfile'} and -f $options{'stopfile'})
        {
            last;
        }

        $label_idx++;
        next;
    }

    #-----------------------------------------------------------------
    # from here on the loop is for regular checkins
    if ($options{'verify'}) {
        verifyrev($change_num, $details);
        $change_idx++;
        next;
    }

    my @properties = ('svn:log'    => fixcharset($details->{'log'}),
                      'svn:author' => $details->{'author'},
                      'svn:date'   => $details->{'date'});

    # optionally save perforce change numbers
    push @properties, ($options{'svn-change-prop'} => $change_num)
        if (grep(/^prop$/, @{$options{'save-changenum'}}));
    $properties[1] .= "\n\nPerforce change number $change_num"
        if (grep(/^comm$/, @{$options{'save-changenum'}}));

    # add dummy records at the beginning if we are exporting a range of changes
    # we do this here, so that we have the date of the first rev, which
    # we will use.
    $last_time = $details->{'date'};
    if ($options{'syncrevs'}) {
        while ($svn_rev < $change_num) {
            debug("inserting dummy rev $svn_rev (to $change_num) $details->{'date'}");
            svn_revision($svn_rev++, [
                'svn:log'    => "dummy revision place holder for missing perforce change",
                'svn:author' => "p42svn",
                'svn:date'   => $last_time]);
        }
    }
        
    @deleted_files = ();
    verbose(sub {
        my $elapsed = (time-$^T)||1;
        return
            sprintf("p4 %d (of %d) to svn r%d (of %d) (%d actions)\n".
                    "%s elapsed, %.1f revs/min, %.1f%% done, eta %s\n",
                    $change_num,
                    $changes[$#changes],
                    $svn_rev,
                    1+$#changes,
                    1+$#{$details->{'actions'}},
                    hourminsec($elapsed),
                    ($svn_rev-$svn_rev_start)/$elapsed*60,
                    ($svn_rev-$svn_rev_start)/(1+$#changes)*100,
                    ($svn_rev == $svn_rev_start ? "??" :
                     hourminsec($elapsed/
                                (($svn_rev-$svn_rev_start)/(1+$#changes))
                                - $elapsed)));
            });
    svn_revision($svn_rev, \@properties);
    $rev_map{$change_num} = $svn_rev++;
    foreach (@{$details->{'actions'}}) {
	if (defined $p42svn{$_->{'action'}}) {
	    $p42svn{$_->{'action'}}->($_->{'path'}, $_->{'type'}, $change_num);
	} else {
	    warn "Action $_->{'action'} not recognized "
	      ."($_->{'path'}\@$change_num)\n";
	}
    }
    #
    # This must be done last in case files are both created and
    # deleted in the same directory in the course of a single changelist.
    #
    svn_delete_empty_parent_dirs(@deleted_files);

    # bail out if we've done the number of revs desired
    if ($options{'revlimit'} and
        $svn_rev-$svn_rev_start >= $options{'revlimit'}) {
        $options{'label'} = [];  # don't do labels
        last;
    }
    # bail out if we've been asked to do so
    if ($options{'stopfile'} and -f $options{'stopfile'})
    {
        $options{'label'} = [];  # don't do labels
        last;
    }
    $change_idx++;
}


# add dummy records at the end if we are exporting a range of changes
if ($options{'syncrevs'} and $options{'changes'} and
    $options{'changes'} =~ /(\d+)$/) {
    my $lastrev = $1;
    # this should only happen if there were no changes in the given span
    # XXX not sure if this is a good default...
    $last_time = "1970-01-01T00:00:00.000000Z" unless $last_time;
    while ($svn_rev <= $lastrev) {
        debug("inserting dummy rev $svn_rev, $lastrev, $last_time");
        svn_revision($svn_rev++, [
                'svn:log'    => "dummy revision place holder for missing perforce change",
                'svn:author' => "p42svn",
                'svn:date'   => $last_time]);
    }
}        


verbose("Completed!\n");
exit 0;
