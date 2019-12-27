
## Overview

Debian is a free operating system (OS) for your computer. An operating system is
the set of basic programs and utilities that make your computer run.

https://www.debian.org/

## Description

Use this script to build your own base system.

We've included the  last ca-certificates files in the repository  to ensure that
all of our images are accurates.

## Tags

Supported tags.

- 7, stretch, oldstable
- 8, buster, stable, latest
- 9, bullseye, testing
- sid

## Requirements

On Debian you need sudo permissions and the following packages:

```bash
# if you build on wheezy please use backports version of debootstrap
$ sudo apt-get install debootstrap
```

On Ubuntu you need sudo permissions and the following packages:

```bash
$ sudo apt-get install debian-keyring debian-archive-keyring debootstrap
```

You also need to be in the docker group to use Docker.

```bash
$ sudo usermod -a -G docker USERNAME
```

Finally you need to login on Docker Hub.

```bash
$ docker login
```

## Usage

You first need  to choose which dist between stretch (9.0), buster (10.0) and bullseye (11.0) you want (buster will be the 'latest' tag)
and you need to choose you user (or organization) name on Docker Hub.

Show help.

```bash
$ ./build.sh -h
```

Build your own Debian image (eg. stretch).

```bash
$ ./build.sh -d stretch -u $USER
```

Build your own Debian image (eg. buster) and push it on the Docker Hub.

```bash
$ ./build.sh -d buster -u <docker account username> -p
```
