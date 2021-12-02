#!/bin/bash

error() {
	printf "%s\n" "$@" >&2
	exit 1
}

[[ -r "swupdate.key" ]] || error "Cannot read swupdate.key"

ROOTFS=$(ls --sort=time baseos-x2-*.tar* | head -n 1)
[[ -e  "$ROOTFS" ]] || error "rootfs not found"
ROOTFS_VERSION=${ROOTFS#baseos-x2-}
ROOTFS_VERSION=${ROOTFS_VERSION%.tar.*}

OUTPUT=baseos-x2-${ROOTFS_VERSION}

cat > "$OUTPUT.desc" <<EOF
DEBUG_SWDESC="# ALLOW_PUBLIC_CERT ALLOW_EMPTY_LOGIN"
swdesc_boot --board iot-g4-eva imx-boot_yakushima-eva
swdesc_boot --board iot-g4-es1 imx-boot_armadillo_x2
swdesc_boot --board iot-g4-es2 imx-boot_armadillo_x2
swdesc_tar "$ROOTFS" --version base_os "$ROOTFS_VERSION"
EOF

. ./tests/common.sh

build_check "$OUTPUT" "version boot 20.*" "version base_os .+" \
	"file imx-boot_armadillo_x2.* imx-boot_yakushima-eva.* '$ROOTFS'" \
	"swdesc imx-boot_armadillo_x2 imx-boot_yakushima-eva '$ROOTFS'"
mv "tests/out/$OUTPUT.swu" .
