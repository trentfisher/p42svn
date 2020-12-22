#!/bin/sh -ex
#
# set up test cases
# we assume P4PORT, P4USER and P4PASSWD have been set
#
echo adding test cases to $P4PORT
P4CLIENT=ws
export P4CLIENT

# set up a workspace/client
rm -rf $P4CLIENT
mkdir $P4CLIENT
cd $P4CLIENT

p4 client -o | perl -ne 'print unless m,^\s+//(.+?)/, and $1 ne "depot"' | p4 client -i
p4 sync -f > /dev/null

cd depot
mkdir chgtests
cd chgtests

# test matrix:
# |         | symlink | file  | dir  |
# | symlink | s2s     | s2f   | s2d* |
# | file    | f2s?    | f2f!  | f2d* |
# | dir     | d2s*    | d2f*  | d2d! |
# tests marked with * are the ones which failed before the fix
# I'm not yet sure about the f2s case
# we expect f2f to be a normal file edit, and d2d to be a noop,
# and therefore skip them

ln -s ../www/live s2s
ln -s ../www/live s2f
ln -s ../www/live s2d
echo wow > f2s
echo wow > f2d
mkdir d2s; touch d2s/dummy
mkdir d2f; touch d2f/dummy
p4 add s2s s2f s2d f2s f2d d2s/dummy d2f/dummy
p4 submit -d "add type conversion test cases"

# now change the types
rm s2s; ln -s ../www/dev s2s
rm s2f; echo wow > s2f
rm s2d; mkdir s2d; touch s2d/dummy
rm -f f2s; ln -s ../www/dev f2s
rm -f f2d; mkdir f2d; touch f2d/dummy
p4 delete d2s/dummy
rmdir d2s
ln -s ../www/dev d2s
rm -rf d2f; echo wow > d2f
p4 add s2d/dummy f2d/dummy d2s d2f 
p4 submit -d "execute type conversions"

# now set up a test case for move and copy
cd ../www/dev
p4 edit Jam.html
p4 move Jam.html Jelly.html
p4 copy index.html index.htm
p4 submit -d "test case for move and copy"

# now set up test cases for non-ascii chars
cd ../..
mkdir chartests
cd chartests

# test filenames: valid utf8 dash, utf8 FFFD, valid cp1252 but invalid utf8, and,
#                 all utf8 chars
for i in foo–bar foo�bar foo`echo -n -e \\\xc0`bar ｆｏｏｂａｒ 
do
echo wow > $i
p4 add $i
done
p4 submit -d "test case for weird characters"

# now change each of them
for i in foo–bar foo�bar foo`echo -n -e \\\xc0`bar ｆｏｏｂａｒ 
do
p4 edit $i
echo ouch > $i
done
p4 submit -d "test case for weird characters in incremental import"

exit 0;

# create a dir->file->dir test
cd ..
mkdir dirfiledir
cd dirfiledir
p4 copy //depot/www/dev/... repl/...
p4 submit -d "copy directory for dir/file/dir switcheroo"

# this file will "eclipse" the dir
rm -rf repl
p4 copy //depot/Jam/MAIN/src/README repl
p4 submit -d "put file in place of dir"

p4 delete repl
mkdir repl
p4 copy  //depot/Jam/MAIN/src/README repl/README
p4 submit -d "put dir in place of file"
# NOTE: at this point the files from the first copy will be in this directory

exit 0
