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

# cleanup version for test builds entries: remove trailing words
while [[ "$ROOTFS_VERSION" =~ -at.*-[a-z] ]]; do
	ROOTFS_VERSION=${ROOTFS_VERSION%-[a-z]*}
done


cat > "$OUTPUT.desc" <<EOF
DEBUG_SWDESC="# ALLOW_PUBLIC_CERT ALLOW_EMPTY_LOGIN"
swdesc_boot --board iot-g4-eva imx-boot_yakushima-eva
swdesc_boot --board iot-g4-es1 imx-boot_armadillo_x2
swdesc_boot --board iot-g4-es2 imx-boot_armadillo_x2
swdesc_boot --board AGX4500 imx-boot_armadillo_x2
swdesc_tar "$ROOTFS" --preserve-attributes \
            --version base_os "$ROOTFS_VERSION"
EOF

. ./tests/common.sh

build_check "$OUTPUT" "version --board AGX4500 boot '20[^ ]* different'" \
	"version base_os '[^ ]+ higher'" \
	"file imx-boot_armadillo_x2.* imx-boot_yakushima-eva.* '$ROOTFS'" \
	"swdesc imx-boot_armadillo_x2 imx-boot_yakushima-eva '$ROOTFS'"
mv "tests/out/$OUTPUT.swu" .
