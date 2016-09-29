#!/bin/bash

# Copyright (c) 2016, rockyluke
#
# Permission  to use,  copy, modify,  and/or  distribute this  software for  any
# purpose  with  or without  fee  is hereby  granted,  provided  that the  above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS"  AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
# REGARD TO  THIS SOFTWARE INCLUDING  ALL IMPLIED WARRANTIES  OF MERCHANTABILITY
# AND FITNESS.  IN NO EVENT SHALL  THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
# INDIRECT, OR  CONSEQUENTIAL DAMAGES OR  ANY DAMAGES WHATSOEVER  RESULTING FROM
# LOSS OF USE, DATA OR PROFITS,  WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
# OTHER  TORTIOUS ACTION,  ARISING  OUT OF  OR  IN CONNECTION  WITH  THE USE  OR
# PERFORMANCE OF THIS SOFTWARE.

version='2.0'

arch='amd64'
oldstable='wheezy'
stable='jessie'
testing='stretch'

if [ -f functions.sh ]
then
    . functions.sh
else
    echo "Missing functions.sh"
    exit 1
fi

while getopts 'hd:m:t:u:plv' OPTIONS
do
    case ${OPTIONS} in
	h)
	    # -h / --help
	    usage
	    exit 0
	    ;;
	d)
	    # -d / --dist
	    dist=${OPTARG}
	    ;;
	m)
	    # -m / --mirror
	    mirror=${OPTARG}
	    ;;
	t)
	    # -t / --timezone
	    timezone=${OPTARG}
	    ;;
	u)
	    # -u / --user
	    user=${OPTARG}
	    ;;
	p)
	    # -p / --push
	    push='true'
	    ;;
	l)
	    # -l / --latest
	    latest=${OPTARG}
	    ;;
	v)
	    # -v / --version
	    echo "${version}"
	    exit 0
	    ;;
	*)
	    usage
	    exit 1
	    ;;
    esac
done

which sudo > /dev/null
if [ ${?} -ne 0 ]
then
    echo "Please install sudo (see README.md)"
    exit 1
fi

which debootstrap > /dev/null
if [ ${?} -ne 0 ]
then
    echo "Please install debootstrap (see README.md)"
    exit 1
fi

# -d / --dist
if [ -n "${dist}" ]
then
    case ${dist} in
	lenny|5|5.0)
	    distname='lenny'
	    distid='5'
	    mirror='archive.debian.org'
	    ;;
	squeeze|6|6.0)
	    distname='squeeze'
	    distid='6'
	    mirror='archive.debian.org'
	    ;;
	wheezy|7|7.0)
	    distname='wheezy'
	    distid='7'
	    ;;
	jessie|8|8.0)
	    distname='jessie'
	    distid='8'
	    ;;
	stretch|9|9.0)
	    distname='stretch'
	    distid='9'
	    ;;
	sid)
	    distname='sid'
	    distid='sid'
	    ;;
	*)
	    usage
	    exit 1
	    ;;
    esac
else
    usage
    exit 1
fi

# -m / --mirror
if [ -z "${mirror}" ]
then
    mirror='ftp.debian.org'
fi

# -t / --timezone
if [ -z "${timezone}" ]
then
    timezone='Europe/Amsterdam'
fi

# -u / --user
if [ -z "${user}" ]
then
    user='rockyluke'
fi

# -l / --latest
if [ -z "${latest}" ]
then
    latest='jessie'
fi

# create image
docker_debootstrap

# import image
docker_import

# push image
if [ -n "${push}" ]
then
    docker_push
fi
# EOF
