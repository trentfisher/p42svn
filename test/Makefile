#
# Set up and run tests for p42svn
#
# this will fetch Perforce binaries, set up a dummy server, and make a bunch
# changes to the depot
#
# TODO:
# - make work on something other than linux (auto-detect platform?)
# - should be more robust, should be able to start in the middle
# - maybe set up an svn repo an run the import?
#
VER=r11.1
PLAT=linux26x86
ROOT=$(shell pwd)
P4ROOT=$(ROOT)/PerforceSample
P4=$(ROOT)/p4
P4D=$(ROOT)/p4d
P42SVN=../p42svn.pl
PORTNUM=1666
P4PORT=$(shell hostname):$(PORTNUM)
export P4PORT
export P4ROOT
# make sure p4 executables are in path
PATH:=$(shell pwd):$(PATH)
export PATH
# this will do the whole test
all: test
test: setup-depot start ../p42svn.pl.orig addtestcases ptest stop
	@echo All tests successful

tstfiles=$(wildcard *.t)
ptest:
	@perl -MTest::Harness -e "runtests(@ARGV);" $(tstfiles)

#------------------------------------------------------------------------
# get perforce binaries
$(P4):
	wget ftp://ftp.perforce.com/perforce/$(VER)/bin.$(PLAT)/p4
	chmod a+x $@
$(P4D):
	wget ftp://ftp.perforce.com/perforce/$(VER)/bin.$(PLAT)/p4d
	chmod a+x $@
sampledepot.tar.gz:
	wget ftp://ftp.perforce.com/perforce/tools/sampledepot.tar.gz

#------------------------------------------------------------------------
# set up depot... get the sample one from Perforce, see
# http://kb.perforce.com/AdminTasks/BasicServerConfiguration/SampleDepot
#
$(P4ROOT): $(P4) $(P4D) sampledepot.tar.gz
	tar xzf sampledepot.tar.gz
	$(P4D) -r $(P4ROOT) -jr $(P4ROOT)/checkpoint
	$(P4D) -r $(P4ROOT) -xu -J $(P4ROOT)/journal
.PHONY: setup-depot
setup-depot: $(P4ROOT) start
# this adds our custom test cases into the depot
addtestcases:
	sh -ex addtestcases.sh

#------------------------------------------------------------------------
# stop and start the depot
.PHONY: start stop
start: $(P4D) $(P4ROOT)
	@if test -f $(P4ROOT)/pid && kill -0 `cat $(P4ROOT)/pid` 2> /dev/null; \
	then echo P4D already running; \
	else $(P4D) -r $(P4ROOT) -p $(PORTNUM) $(P4DOPTS) > $(P4ROOT)/log 2>&1 & echo $$! > $(P4ROOT)/pid; sleep 2; \
	fi
stop: $(P4)
	@if [ -f $(P4ROOT)/pid ]; then \
	  if kill -0 `cat $(P4ROOT)/pid` 2> /dev/null; \
	  then \
            $(P4) admin stop; sleep 2; \
	    if kill -0 `cat $(P4ROOT)/pid` 2> /dev/null; \
	    then kill `cat $(P4ROOT)/pid`; fi \
	  else echo P4D already dead; fi; \
          rm $(P4ROOT)/pid; \
	else echo P4D not running; \
	fi

restart: stop start

# start a sub-shell with the p4 environment
shell:
	$(SHELL)

#------------------------------------------------------------------------
# run exports
# 
.PHONY: export
export: std.svndump
# standard dump, before any of the added features
std.svndump: start
	time perl $(P42SVN) --port $(P4PORT) --branch //depot= > $@ || rm $@

#------------------------------------------------------------------------
# This is the last released version before the most recent string of changes
../p42svn.pl.orig:
	svn cat -r87 ../p42svn.pl > $@ || rm $@

#------------------------------------------------------------------------
# convert a dump into a repository
%.repos: %.svndump
	rm -rf $@
	svnadmin create $@
	svnadmin load -q $@ < $<

# in-place edit is a kludge and prevents these dumps from being loaded
# remove or replace any lines which we expect to be different or hinder diff
%.svndumptxt: %.svndump
	perl -pe 's/^\d+-\d+-\d+T\d+:\d+:\d+\.\d+Z/TIMESTAMP/; s/[^[:ascii:]]+/BINARY/;' $^ > $@

compare-dump: std.svndumptxt all-after.svndumptxt
	diff -q $^

#------------------------------------------------------------------------
# clean up the whole mess
.PHONY: clean
clean: stop
	rm -rf $(P4ROOT) *.repos *.svndump *.diff *.bak $(CONTENTCACHE) ws
