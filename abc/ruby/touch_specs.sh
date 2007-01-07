#!/bin/sh
# by Hiromasa YOSHIMOTO <y@momonga-linux.org>

function do_touch ()
{
    if [ -f $1/$1.spec ]; then
	echo $1
	touch $1/$1.spec
    fi
}

while [ -n "$1" ]; do
    if [ "-" == "$1" ]; then
	while read pkg; do
	    do_touch $pkg
	done
    else
	do_touch $1
    fi
    shift
done 
