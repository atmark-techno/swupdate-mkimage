#!/bin/bash

error() {
	echo "$@" >&2
	exit 1
}

[[ -r "swupdate.key" ]] || error "Cannot read swupdate.key"

ROOTFS=$(ls --sort=time alpine-aarch64-*.tar* | grep -vE '\.sig$' | head -n 1)
[[ -e  "$ROOTFS" ]] || error "rootfs not found"
ROOTFS_VERSION=${ROOTFS#alpine-aarch64-}
ROOTFS_VERSION=${ROOTFS_VERSION%.tar.*}
# if multiple dashes only keep until first one
ROOTFS_VERSION=${ROOTFS_VERSION%%-*}

OUTPUT=yakushima-eva-${ROOTFS_VERSION}

cat > "$OUTPUT.desc" <<EOF
swdesc_uboot imx-boot_yakushima-eva
swdesc_tar "$ROOTFS" --version base_os "$ROOTFS_VERSION"
EOF

. ./tests/common.sh

build_check "$OUTPUT" "version uboot 20.*" "version base_os .+"
mv "tests/out/$OUTPUT.swu" .
