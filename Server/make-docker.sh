#!/bin/bash

VERSION=$1
ALPINE_VERSION="3.18.3"

# since docker has decided to make the official repository pay per view, this script will make a container from blank.

pwsh Update-LibraryCredits.ps1 NabuNet

dotnet publish NabuNet --self-contained --runtime linux-musl-x64 -o docker/tmp -p version="$VERSION" -c Release

#
# alpine image version tag
#    either a.b.c
#    or     a.b.c-something
#
# we need to separate ALPINE_VERSION=a.b.c only

ALPINE_VERSION=$(echo "$ALPINE_VERSION" | sed 's/-.*$//')

# now that version is just a.b.c, we need a.b for 
# the main folder part of the URL...

MAJORMINOR=$(echo "$ALPINE_VERSION" | sed 's/.[0-9]*$//')

DOWNLOADURL="http://dl-cdn.alpinelinux.org/alpine/v${MAJORMINOR}/releases/x86_64/alpine-minirootfs-${ALPINE_VERSION}-x86_64.tar.gz"

echo "Downloading alpine from $DOWNLOADURL"

# using fixed filename for root fs, so the docker import
# command can be hardcoded in the CI pipeline.

#wget "$DOWNLOADURL" -O docker/rootfs.tar.gz

docker build -t "nabunet:$VERSION" docker
