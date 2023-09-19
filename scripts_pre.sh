#!/bin/sh
# SPDX-License-Identifier: MIT

# This script prepares the script environment by extracting the
# archive we concatenate at the end of it, then rolls the pre steps.

TMPDIR="${TMPDIR:-/var/tmp}"
MKSWU_TMP="$TMPDIR/scripts"
# SCRIPTSDIR is overridden for scripts embedded with swupdate
SCRIPTSDIR="$MKSWU_TMP"

rm -rf "$MKSWU_TMP"
mkdir "$MKSWU_TMP" || exit 1
cd "$MKSWU_TMP" || exit 1

# extract archive after script
sed -e '1,/^BEGIN_ARCHIVE/d' "$0" | tar xv || exit 1

# prepare update
. "$SCRIPTSDIR/common.sh"
. "$SCRIPTSDIR/versions.sh"

. "$SCRIPTSDIR/pre_init.sh"
. "$SCRIPTSDIR/pre_boot.sh"
. "$SCRIPTSDIR/pre_rootfs.sh"
. "$SCRIPTSDIR/pre_appfs.sh"

exit
# This must be the last line!
BEGIN_ARCHIVE
