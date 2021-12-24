#!/bin/bash

set -e

TESTS_DIR=$(dirname "${BASH_SOURCE[0]}")
. $TESTS_DIR/../scripts/versions.sh

error() {
	printf "%s\n" "$@" >&2
	exit 1
}

export SWDESC_TEST=1

check() {
	local type="$1"
	local file tar regex
	local component version real_version
	shift
	case "$type" in
	file)
		[ $# -gt 0 ] || error "file check has no argument"
		for file; do
			cpio -t < "$swu"| grep -qx "$file" ||
				error "$file not in swu"
		done
		;;
	file-tar)
		[ $# -gt 1 ] || error "file-tar needs tar and content args"
		tar="$1"
		shift
		tar tf "$dir/"$tar "$@" > /dev/null || error "Missing files in $tar"
		;;
	version)
		[ $# -eq 2 ] || error "version usage: <component> <version regex>"
		component="$1"
		version="$2"

		## from scripts/version.sh gen_newversion:
		parse_swdesc < "$dir/sw-description" > "$dir/sw-versions.present"
		real_version=$(get_version "$component" "$dir/sw-versions.present")

		[[ "$real_version" =~ $version ]] ||
			error "Version $component expected $version got $real_version"
		;;
	swdesc)
		[ $# -gt 0 ] || error "swdesc check needs argument"
		for regex; do
			grep -q -E "$regex" "$dir/sw-description" \
				|| error "$regex not found in $dir/sw-description"
		done
		;;
	*) error "Unknown check type: $type" ;;
	esac
}

build_check() {
	local desc="$1"
	local name="${desc##*/}"
	local dir="$TESTS_DIR/out/.$name"
	local swu="$TESTS_DIR/out/$name.swu"
	local check
	shift

	echo "Building $name"
	"$TESTS_DIR/../mkimage.sh" ${conf+-c "$conf"} -o "$swu" "$desc.desc"

	for check; do
		eval check "$check"
	done
}

build_fail() {
	local desc="$1"
	local name="${desc##*/}"
	local dir="$TESTS_DIR/out/.$name"
	local swu="$TESTS_DIR/out/$name.swu"
	local check
	shift

	echo "Building $name (must fail)"
	! "$TESTS_DIR/../mkimage.sh" ${conf+-c "$conf"} -o "$swu" "$desc.desc"
}
