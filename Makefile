# P42SVN automation
# not well tested outside of Linux

# this is where things will be installed
PREFIX=/scm
# what version of the p4 api to use, must match directory on ftp site
P4VER=r10.1
P4PLAT=`perl platid`

all:
	@echo Available targets
	@echo  install -- install p4 api and scripts, set PREFIX as desired
	@echo  docs    -- regenerate html documentation
	@echo  test    -- run test suite
	@echo  dist    -- generate a tarball for release

# generate documentation... probably only done at release time
# this probably should be in a sub-make file... but I'm too lazy to do so
docs: www/p42svn.html www/p42svnsync.html www/migration.html
www/p42svn.html: p42svn.pl
	pod2html --infile=p42svn.pl --outfile=www/p42svn.html
www/migration.html: migration.pod
	pod2html --infile=$< --outfile=$@
www/p42svnsync.html: p42svnsync
	pod2html --infile=p42svnsync --outfile=www/p42svnsync.html

# install the perforce API, perl bindings and our scripts
install: perforce-api.install
	install p42svn.pl $(PREFIX)/bin
	install p42svnsync $(PREFIX)/bin

# these rules should grab the p4 api, build and install
# not well tested
p4api.tgz:
	wget -N ftp://ftp.perforce.com/perforce/$(P4VER)/bin.$(P4PLAT)/p4api.tgz
p4perl.tgz:
	wget -N ftp://ftp.perforce.com/perforce/$(P4VER)/bin.tools/p4perl.tgz
perforce-api.install: p4api.tgz p4perl.tgz
	tar xzf p4api.tgz
	tar xzf p4perl.tgz
	cd p4perl-2* && perl Makefile.PL --apidir ../p4api-2*
	cd p4perl-2* && make
	cd p4perl-2* && make install
	touch $@

# rules to generate a tar ball for release
MANIFEST: Makefile
	echo MANIFEST > MANIFEST
	echo ChangeLog >> MANIFEST
	echo INSTALL >> MANIFEST
	echo Makefile >> MANIFEST
	echo p42svn.pl >> MANIFEST
	echo p42svnsync >> MANIFEST
	echo platid >> MANIFEST
	ls www/*.html >> MANIFEST
# we only want checked in stuff... is there a better way to do this?
	svn status -q -v test| cut -c42- | grep -v '^test$$' >> MANIFEST
dist: docs MANIFEST
	tar -czf p42svn.tar.gz -T MANIFEST

test: perforce-api.install
	cd test && $(MAKE) test
clean:
	rm -rf *~ p4perl-2* p4api-2*
	cd test && $(MAKE) clean
