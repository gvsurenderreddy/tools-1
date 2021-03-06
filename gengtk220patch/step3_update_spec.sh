#!/bin/bash
#
#  Hiromasa YOSHIMOTO <y@momonga-linux.org>
#

BIN=`dirname $0`
BIN=`readlink -f $BIN`
BIN=${BIN:-.}


function error 
{
    echo $@ > /dev/stderr
    exit 2
}

source $BIN/config ||  error "failed to load $BIN/config "

LANG=C 

if [ $# -ne 1 ]; then
    cat<<EOF > /dev/stderr
usage:
 $0  hoge.spec
EOF
    exit 1
fi

[ -f $1 ] || error "no such file, $1 "

spec=$1


for x in BUILD/*gtk220.patch; do
    echo "importing $x into $spec"
    cp $x .

    file=`basename $x`
    $BIN/append_patch.sh $file $spec

    svn add $file
done



$BIN/../increse-rel.rb \
    --address "$ADDRESS" \
    --name    "$NAME" \
    --message "add patch for gtk-2.20 by gengtk220patch" $spec
