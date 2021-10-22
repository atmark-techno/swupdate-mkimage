#!/bin/bash

set -e

. scripts/versions.sh

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
			cpio -t < "$name".swu | grep -qx "$file" ||
				error "$file not in swu"
		done
		;;
	file-tar)
		[ $# -gt 1 ] || error "file-tar needs tar and content args"
		tar="$1"
		shift
		tar tf "$name/$tar" "$@" > /dev/null || error "Missing files in $tar"
		;;
	version)
		[ $# -eq 2 ] || error "version usage: <component> <version regex>"
		component="$1"
		version="$2"

		## from scripts/version.sh gen_newversion:
		parse_swdesc < "$name/sw-description" > "$name/sw-versions.present"
		real_version=$(get_version "$component" "$name/sw-versions.present")

		[[ "$real_version" =~ $version ]] ||
			error "Version $component expected $version got $real_version"
		;;
	swdesc)
		[ $# -gt 0 ] || error "swdesc check needs argument"
		for regex; do
			grep -q -E "$regex" "$name/sw-description" \
				|| error "$regex not found in $name/sw-description"
		done
		;;
	*) error "Unknown check type: $type" ;;
	esac
}

build_check() {
	local desc="$1"
	local name="${desc##*/}"
	local name="tests/out/$name"
	local check
	shift

	echo "Building $name"
	./mkimage.sh ${conf+-c "$conf"} -o "$name.swu" "$desc.desc"

	for check; do
		eval check "$check"
	done
}
