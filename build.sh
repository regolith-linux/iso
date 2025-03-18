#!/bin/bash

set -e

# check for root permissions
if [[ "$(id -u)" != 0 ]]; then
  echo "E: Requires root permissions" > /dev/stderr
  exit 1
fi

# get config
if [ -z "$1" ]; then
  echo "E: config file is missing. Usage: build.sh /path/to/release.conf" > /dev/stderr
  exit 1
fi

build () {
  BUILD_ARCH="$1"

  mkdir -p "$BASE_DIR/tmp/$BUILD_ARCH"
  cd "$BASE_DIR/tmp/$BUILD_ARCH" || exit

  # remove old configs and copy over new
  rm -rf config auto
  cp -r "$BASE_DIR"/auto/ .
  cp -r "$BASE_DIR"/config/ .
  cp -r "$BASE_DIR"/overlays/$BASEDISTRO/* config/

  if [ -d "$BASE_DIR"/packages ]; then
    mkdir -p config/packages.chroot/
    cp "$BASE_DIR"/packages/* config/packages.chroot/
  fi

  # Make sure conffile specified as arg has correct name
  cp -f "$BASE_DIR"/"$CONFIG_FILE" terraform.conf
  echo "ARCH=\"$BUILD_ARCH\"" >> terraform.conf

  if [ -z "$YYYYMMDD" ]; then
    YYYYMMDD="$(date +%Y%m%d%H%M)"
  fi

  FNAME_PARTIAL=""
  if [ "$CHANNEL" != "stable" ]; then
    FNAME_PARTIAL="-$YYYYMMDD"
  fi
  FNAME="regolith-$VERSION-$BASECODENAME$FNAME_PARTIAL$OUTPUT_SUFFIX-$ARCH"

  OUTPUT_DIR="$BASE_DIR/builds/$BUILD_ARCH"
  mkdir -p "$OUTPUT_DIR"

  echo -e "
#------------------#
# LIVE-BUILD CLEAN #
#------------------#" | tee -a "$OUTPUT_DIR/${FNAME}.iso.log"
  lb clean | tee -a "$OUTPUT_DIR/${FNAME}.iso.log"

  echo -e "
#-------------------#
# LIVE-BUILD CONFIG #
#-------------------#" | tee -a "$OUTPUT_DIR/${FNAME}.iso.log"
  lb config | tee -a "$OUTPUT_DIR/${FNAME}.iso.log"

  echo -e "
#------------------#
# LIVE-BUILD BUILD #
#------------------#" | tee -a "$OUTPUT_DIR/${FNAME}.iso.log"
  lb build 2>&1 | tee -a "$OUTPUT_DIR/${FNAME}.iso.log"

  echo -e "
#---------------------------#
# MOVE OUTPUT TO BUILDS DIR #
#---------------------------#"

  mv "$BASE_DIR/tmp/$BUILD_ARCH/live-image-$BUILD_ARCH.hybrid.iso" "$OUTPUT_DIR/${FNAME}.iso"
  cp "$BASE_DIR/tmp/$BUILD_ARCH/live-image-$BUILD_ARCH.contents"   "$OUTPUT_DIR/${FNAME}.iso.contents"
  cp "$BASE_DIR/tmp/$BUILD_ARCH/live-image-$BUILD_ARCH.packages"   "$OUTPUT_DIR/${FNAME}.iso.packages"

  # cd into output to so {FNAME}.sha256.txt only
  # includes the filename and not the path to
  # our file.
  cd $OUTPUT_DIR

  sha256sum "${FNAME}.iso" | tee -a "${FNAME}.sha256sum"
  sha256sum "${FNAME}.iso.contents" | tee -a "${FNAME}.sha256sum"
  sha256sum "${FNAME}.iso.packages" | tee -a "${FNAME}.sha256sum"

  cd $BASE_DIR
}

CONFIG_FILE="$1"
BASE_DIR="$PWD"
source "$BASE_DIR"/"$CONFIG_FILE"

echo -e "
#----------------------#
# INSTALL DEPENDENCIES #
#----------------------#"

export TZ=America/New_York
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get upgrade -y
apt-get install -y live-build patch gnupg2 binutils zstd

# The Debian repositories don't seem to have the `ubuntu-keyring` or `ubuntu-archive-keyring` packages
# anymore, so we add the archive keys manually. This may need to be updated if Ubuntu changes their signing keys
# To get the current key ID, find `ubuntu-keyring-xxxx-archive.gpg` in /etc/apt/trusted.gpg.d on a running
# system and run `gpg --keyring /etc/apt/trusted.gpg.d/ubuntu-keyring-xxxx-archive.gpg --list-public-keys `
if [ "$BASEDISTRO" = "ubuntu" ]; then
  apt-key adv --recv-keys --keyserver keyserver.ubuntu.com F6ECB3762474EDA9D21B7022871920D1991BC93C
fi

  echo -e "
#------------------------#
# APPLY REQUIRED PATCHES #
#------------------------#"

# TODO: This patch was submitted upstream at:
# https://salsa.debian.org/live-team/live-build/-/merge_requests/314
# This can be removed when our Debian container has a version containing this fix
patch -d /usr/lib/live/build/ < patches/314-follow-symlinks-when-measuring-size-of-efi-files.patch

# TODO: Remove this once debootstrap can natively build noble images:
case $BASECODENAME in
  lunar|mantic|noble|oracular|plucky)
    if [ ! -f "/usr/share/debootstrap/scripts/$BASECODENAME" ]; then
      ln -sfn /usr/share/debootstrap/scripts/gutsy /usr/share/debootstrap/scripts/$BASECODENAME
    fi
    ;;
esac

# remove old builds before creating new ones
rm -rf "$BASE_DIR"/builds

if [ -z "$ARCH" ]; then
  ARCH="amd64"
fi

case $VERSION in
  next|dev|3.3) ;; # do nothing
  *)
      echo -e "
#----------------------------#
# DOWNLOAD REQUIRED PACKAGES #
#----------------------------#"

    for pkg in regolith-branding regolith-minimal regolith-standard regolith-common regolith-desktop-i3 regolith-desktop-sway regolith-live; do
      if [ "$pkg" == "regolith-desktop-i3" ]; then
        if [ "$SESSIONS" == "sway" ]; then
          continue
        fi
      fi

      if [ "$pkg" == "regolith-desktop-sway" ]; then
        if [ "$SESSIONS" == "i3" ]; then
          continue
        fi
      fi

      wget -P "$BASE_DIR"/packages/ https://archive.regolith-desktop.com/${BASEDISTRO}/unstable/pool/main/m/meta-packages/${pkg}_0.1.0-1regolith-${BASECODENAME}_${ARCH}.deb || true
      wget -P "$BASE_DIR"/packages/ https://archive.regolith-desktop.com/${BASEDISTRO}/unstable/pool/main/m/meta-packages/${pkg}_0.1.0-1regolith-${BASECODENAME}_all.deb || true

      if [ ! -s "$BASE_DIR/packages/${pkg}_0.1.0-1regolith-${BASECODENAME}_${ARCH}.deb" ]; then
        rm -f "$BASE_DIR/packages/${pkg}_0.1.0-1regolith-${BASECODENAME}_${ARCH}.deb"
      fi

      if [ ! -s "$BASE_DIR/packages/${pkg}_0.1.0-1regolith-${BASECODENAME}_all.deb" ]; then
        rm -f "$BASE_DIR/packages/${pkg}_0.1.0-1regolith-${BASECODENAME}_all.deb"
      fi
    done
    ;;
esac

build "$ARCH"
