#!/bin/sh
set -x

[ $(id -u) -eq 0 ] || {
  printf >&2 '%s requires root\n' "$0"
  exit 1
}

usage() {
  printf >&2 '%s: [-r release] [-m mirror] [-s]\n' "$0"
  exit 1
}

tmp() {
  TMP=$(mktemp -d /tmp/alpine-docker-XXXXXXXXXX)
  ROOTFS=$(mktemp -d /tmp/alpine-docker-rootfs-XXXXXXXXXX)
  trap "rm -rf $TMP $ROOTFS" EXIT TERM INT
}

apkv() {
  set -x
  curl -s $REPO/$ARCH/APKINDEX.tar.gz | tar -Oxz |
    grep '^P:apk-tools-static$' -a -A1 | tail -n1 | cut -d: -f2
}

getapk() {
  echo REPO $REPO
  curl -s $REPO/$ARCH/apk-tools-static-$(apkv).apk |
    tar -xz -C $TMP sbin/apk.static
}

mkbase() {
  $TMP/sbin/apk.static --repository $REPO --update-cache --allow-untrusted \
    --root $ROOTFS --initdb add alpine-base
}

conf() {
  printf '%s\n' $REPO > $ROOTFS/etc/apk/repositories
}

pack() {
  local id
  id=$(tar --numeric-owner -C $ROOTFS -c . | docker import - $TAG:$REL)

  docker tag $id $TAG:latest
#  docker run -i -t $TAG printf 'alpine:%s with id=%s created!\n' $REL $id
}

save() {
  [ $SAVE -eq 1 ] || return

#  tar --numeric-owner -C $ROOTFS -c . | xz > rootfs.tar.xz
  tar --numeric-owner -C $ROOTFS -cf rootfs.tar .

}

while getopts "hr:m:s" opt; do
  case $opt in
    r)
      REL=$OPTARG
      ;;
    m)
      MIRROR=$OPTARG
      ;;
    s)
      SAVE=1
      ;;
    *)
      usage
      ;;
  esac
done

REL=${REL:-latest-stable}
MIRROR=${MIRROR:-https://nl.alpinelinux.org/alpine}
SAVE=${SAVE:-0}
REPO=$MIRROR/$REL/main
ARCH=armhf
#ARCH=$(uname -m)
TAG=pietervandereems/armhf-alpine

echo "prepare\n\n"
tmp && getapk

echo "makebase\n\n"
mkbase


echo "config\n\n"
echo "$REPO\n" > $ROOTFS/etc/apk/repositories
#conf

echo "pack\n\n"
pack

echo "save\n\n"
save
