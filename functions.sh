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

function usage() {

    cat <<EOF

NAME:
   build.sh - Docker images and builders of Debian.

USAGE:
   build.sh -d <dist>

OPTIONS:
   -h, --help           Show help
   -d, --dist		Choose debian distribution (lenny, squeeze, wheezy, jessie, stretch, sid)
   -m, --mirror		Choose your preferred mirror (default: ftp.debian.org)
   -t, --timezone       Choose your preferred timezone (default: Europe/Amsterdam)
   -u, --user		Docker Hub username (or organisation)
   -p, --push		Docker Hub push
   -l, --latest         Force the "latest" (default: jessie)
   -v, --version        Show version

VERSION:
   docker-debian version: ${version}

EOF

} # usage


function docker_debootstrap() {

    # variables
    image="/tmp/image-${distname}-${arch}"
    include="apt-transport-https,apt-utils,ca-certificates,curl,git,locales"
    exclude="debconf-i18n,man-db,manpages"
    components='main contrib non-free'

    id=$(id -u)
    if [ "${id}" -ne 0 ]
    then
	sudo='sudo'
    fi

    # clean old image
    ${sudo} rm -fr "${image}"

    # create minimal debootstrap image
    echo "-- debootstrap ${distname}"
    ${sudo} debootstrap \
	--arch="${arch}" \
	--include="${include}" \
	--exclude="${exclude}" \
	--variant=minbase \
	"${distname}" \
	"${image}" \
	"http://${mirror}/debian" > /dev/null
    if [ $? -ne 0 ]
    then
	echo "error with debootstrap"
	exit 1
    fi

    # create /etc/default/locale
    echo '-- /etc/default/locale'
    cat <<EOF | ${sudo} tee "${image}/etc/default/locale" > /dev/null
LANG=C
LANGUAGE=C
LC_COLLATE=C
LC_ALL=C
EOF

    # create /etc/timezone
    echo '-- /etc/timezone'
    cat <<EOF | ${sudo} tee "${image}/etc/timezone" > /dev/null
${timezone}
EOF

    # create /etc/resolv.conf
    echo '-- /etc/resolv.conf'
    cat <<EOF | ${sudo} tee "${image}/etc/resolv.conf" > /dev/null
nameserver 8.8.4.4
nameserver 8.8.8.8
EOF

    if [ "${distname}" = 'lenny' ]
    then

	# create /etc/apt/sources.list
	echo '-- /etc/apt/sources.list'
	cat <<EOF | ${sudo} tee "${image}/etc/apt/sources.list" > /dev/null
deb http://archive.debian.org/debian lenny main contrib non-free
deb http://archive.debian.org/debian-backports lenny-backports main contrib non-free
EOF

	# create /etc/apt/apt.conf.d/90ignore-release-date
	# thanks to http://stackoverflow.com/questions/36080756/archive-repository-for-debian-squeeze
	echo '-- /etc/apt/apt.conf.d/ignore-release-date'
	cat <<EOF | ${sudo} tee "${image}/etc/apt/apt.conf.d/ignore-release-date" > /dev/null
Acquire::Check-Valid-Until "false";
EOF

    elif [ "${distname}" = 'squeeze' ]
    then

	# create /etc/apt/sources.list
	echo '-- /etc/apt/sources.list'
	cat <<EOF | ${sudo} tee "${image}/etc/apt/sources.list" > /dev/null
deb http://archive.debian.org/debian squeeze main contrib non-free
deb http://archive.debian.org/debian squeeze-lts main contrib non-free
deb http://archive.debian.org/debian-backports squeeze-backports main contrib non-free
deb http://archive.debian.org/debian-backports squeeze-backports-sloppy main contrib non-free
EOF

	# create /etc/apt/apt.conf.d/90ignore-release-date
	# thanks to http://stackoverflow.com/questions/36080756/archive-repository-for-debian-squeeze
	echo '-- /etc/apt/apt.conf.d/ignore-release-date'
	cat <<EOF | ${sudo} tee "${image}/etc/apt/apt.conf.d/ignore-release-date" > /dev/null
Acquire::Check-Valid-Until "false";
EOF

    else

	# create /etc/apt/sources.list
	echo '-- /etc/apt/sources.list'
	cat <<EOF | ${sudo} tee "${image}/etc/apt/sources.list" > /dev/null
deb http://${mirror}/debian ${distname} ${components}
deb http://${mirror}/debian ${distname}-updates ${components}
EOF

	# create /etc/apt/sources.list.d/backports.list
	echo '-- /etc/apt/sources.list.d/backports.list'
	cat <<EOF | ${sudo} tee "${image}/etc/apt/sources.list.d/backports.list" > /dev/null
deb http://${mirror}/debian ${distname}-backports ${components}
EOF

	# create /etc/apt/sources.list.d/security.list
	echo '-- /etc/apt/sources.list.d/security.list'
	cat <<EOF | ${sudo} tee "${image}/etc/apt/sources.list.d/security.list"  > /dev/null
deb http://security.debian.org/ ${distname}/updates ${components}
EOF

	# create /etc/dpkg/dpkg.cfg.d/disable-doc
	# thanks to http://askubuntu.com/questions/129566/remove-documentation-to-save-hard-drive-space
	cat <<EOF | ${sudo} tee "${image}/etc/dpkg/dpkg.cfg.d/disable-doc" > /dev/null
path-exclude /usr/share/doc/*
path-include /usr/share/doc/*/copyright
path-exclude /usr/share/info/*
path-exclude /usr/share/man/*
EOF

    fi

    # create /etc/apt/apt.conf.d/force-ipv4
    # thanks to https://github.com/cw-ansible/cw.apt/
    echo '-- /etc/apt/apt.conf.d/force-ipv4'
    cat <<EOF | ${sudo} tee "${image}/etc/apt/apt.conf.d/force-ipv4" > /dev/null
Acquire::ForceIPv4 "true";
EOF

    # create /etc/apt/apt.conf.d/disable-auto-install
    # thanks to https://github.com/cw-ansible/cw.apt/
    echo '-- /etc/apt/apt.conf.d/disable-auto-install'
    cat <<EOF | ${sudo} tee "${image}/etc/apt/apt.conf.d/disable-auto-install" > /dev/null
APT::Install-Recommends "0";
APT::Install-Suggests "0";
EOF

    # create /etc/apt/apt.conf.d/disable-cache
    # thanks to https://github.com/docker/docker/blob/master/contrib/mkimage-debootstrap.sh
    echo '-- /etc/apt/apt.conf.d/disable-cache'
    cat <<EOF | ${sudo} tee "${image}/etc/apt/apt.conf.d/disable-cache" > /dev/null
Dir::Cache::pkgcache "";
Dir::Cache::srcpkgcache "";
EOF

    # create /etc/apt/apt.conf.d/force-conf
    # thanks to https://raphaelhertzog.com/2010/09/21/debian-conffile-configuration-file-managed-by-dpkg/
    echo '-- /etc/apt/apt.conf.d/force-conf'
    cat <<EOF | ${sudo} tee "${image}/etc/apt/apt.conf.d/force-conf" > /dev/null
Dpkg::Options {
   "--force-confnew";
   "--force-confmiss";
}
EOF

    # create /etc/apt/apt.conf.d/disable-languages
    # tahnks to https://github.com/docker/docker/blob/master/contrib/mkimage-debootstrap.sh
    echo '-- /etc/apt/apt.conf.d/disable-languages'
    cat <<EOF | ${sudo} tee "${image}/etc/apt/apt.conf.d/disable-languages" > /dev/null
Acquire::Languages "none";
EOF

    # create /usr/bin/apt-clean
    echo '-- /usr/bin/apt-clean'
    cat <<EOF | ${sudo} tee "${image}/usr/bin/apt-clean" > /dev/null
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

find /usr/share/doc     -type f ! -name copyright -delete
find /usr/share/i18n    -type f -delete
find /usr/share/locale  -type f -delete
find /usr/share/man     -type f -delete
find /var/cache/apt     -type f -delete
find /var/lib/apt/lists -type f -delete
# EOF
EOF
    ${sudo} chmod 755 "${image}/usr/bin/apt-clean"

    # mount
    ${sudo} mount --bind /dev     "${image}/dev"
    ${sudo} mount --bind /dev/pts "${image}/dev/pts"
    ${sudo} mount --bind /proc    "${image}/proc"
    ${sudo} mount --bind /sys     "${image}/sys"

    # update root certificates
    ${sudo} mkdir -p "${image}/usr/local/share/"
    ${sudo} cp -r ca-certificates "${image}/usr/local/share/"

    # upgrade
    echo '-- apt-get upgrade'
    ${sudo} chroot "${image}" bash -c \
	"export DEBIAN_FRONTEND=noninteractive && \
         export LC_ALL=C && \
         update-ca-certificates -f && \
         apt-get update -qq && \
         apt-get upgrade -qq -y && \
         apt-get dist-upgrade -qq -y && \
         apt-get clean -qq -y && \
         apt-get autoremove -qq -y && \
         apt-get autoclean -qq -y" > /dev/null

    # unmount
    ${sudo} umount "${image}/dev/pts"
    ${sudo} umount "${image}/dev"
    ${sudo} umount "${image}/proc"
    ${sudo} umount "${image}/sys"

    # clean
    # thanks to https://wiki.debian.org/ReduceDebian
    ${sudo} find   "${image}/usr/share/doc"     -type f ! -name copyright -delete
    ${sudo} find   "${image}/usr/share/i18n"    -type f -delete
    ${sudo} find   "${image}/usr/share/locale"  -type f -delete
    ${sudo} find   "${image}/usr/share/man"     -type f -delete
    ${sudo} find   "${image}/var/cache/apt"     -type f -delete
    ${sudo} find   "${image}/var/lib/apt/lists" -type f -delete

    # create archive
    if [ -f "${image}.tar" ]
    then
	${sudo} rm "${image}.tar"
    fi
    ${sudo} tar --numeric-owner -cf "${image}.tar" -C "${image}" .

} # docker_debootstrap


function docker_import() {

    # create image
    echo "-- docker import debian:${distname} (from ${image}.tgz)"
    docker import "${image}.tar" "${user}/debian:${distname}"
    docker run "${user}/debian:${distname}" echo "Successfully build ${user}/debian:${distname}"
    docker tag "${user}/debian:${distname}" "${user}/debian:${distid}"
    docker run "${user}/debian:${distid}" echo "Successfully build ${user}/debian:${distid}"

    # tag {latest,stable,oldstable}
    for import in latest oldstable stable testing
    do
	if [ "${distname}" = "${!import}" ]
	then
	    docker tag "${user}/debian:${distname}" "${user}/debian:${import}"
	    docker run "${user}/debian:${distid}" echo "Successfully build ${user}/debian:${import}"
	fi
    done

} # docker_import


function docker_push() {

    # push image to docker hub
    echo "-- docker push debian:${distname}"
    docker push "${user}/debian:${distname}"

    echo "-- docker push debian:${distid}"
    docker push "${user}/debian:${distid}"

    # push {latest,stable,oldstable} to docker hub
    for push in latest oldstable stable testing
    do
	if [ "${distname}" = "${!push}"  ]
	then
	    echo "-- docker push ${push}"
	    docker push "${user}/debian:${push}"
	fi
    done

} # docker_push

# EOF
