btrfs_snapshot_or_create() {
	local source="$1"
	local new="$2"

	if [ -e "$basemount/$new" ]; then
		btrfs subvolume delete "$basemount/$new"
	fi
	if [ -e "$basemount/$source" ]; then
		btrfs subvolume snapshot \
			"$basemount/$source" "$basemount/$new"
	else
		btrfs subvolume create "$basemount/$new"
	fi
}

btrfs_subvol_create() {
	local new="$1"

	[ -e "$basemount/$new" ] && return
	btrfs subvolume create "$basemount/$new"
}


prepare_appfs() {
	local dev="${mmcblk}p5"
	local mountopt="compress=zstd:3,space_cache=v2,subvol"
	local basemount

	basemount=$(mktemp -d -t btrfs-root.XXXXXX) || error "Could not create temp dir"
	mkdir -p /target/var/app/storage /target/var/app/volumes
	mkdir -p /target/var/app/volumes_persistent /target/var/tmp

	if ! mount "$dev" "$basemount" >/dev/null 2>&1; then
		echo "Reformating $dev (app)"
		mkfs.btrfs "$dev" || error "$dev already contains another filesystem (or other mkfs error)"
		mount "$dev" "$basemount" || error "Could not mount $dev"
	fi

	if [ "$(readlink /etc/containers/storage.conf)" != "storage.conf-persistent" ] &&
	    ! grep -q 'graphroot = "/var/app/storage' /target/etc/atmark/containers-storage.conf 2>/dev/null; then
		echo "Persistent storage is used for podman, stopping all containers before taking snapshot" >&2
		echo "This is only for development, do not use this mode for production!" >&2
		podman kill -a
		podman rm -a
	fi

	[ -d "$basemount/boot_0" ] || mkdir "$basemount/boot_0"
	[ -d "$basemount/boot_1" ] || mkdir "$basemount/boot_1"
	btrfs_snapshot_or_create "boot_$((!ab))/storage" "boot_${ab}/storage" \
		|| error "Could not create storage subvol"
	btrfs_snapshot_or_create "boot_$((!ab))/volumes" "boot_${ab}/volumes" \
		|| error "Could not create volumes subvol"
	btrfs_subvol_create "volumes_persistent" \
		|| error "Could not create volumes_persistent subvol"
	btrfs_subvol_create "tmp" || error "Could not create tmp subvol"

	mount -t btrfs -o "$mountopt=boot_${ab}/storage" "$dev" /target/var/app/storage \
		|| error "Could not mount storage subvol"
	mount -t btrfs -o "$mountopt=boot_${ab}/volumes" "$dev" /target/var/app/volumes \
		|| error "Could not mount volume subvol"
	mount -t btrfs -o "$mountopt=volumes_persistent" "$dev" /target/var/app/volumes_persistent \
		|| error "Could not mount volume_persistent subvol"
	mount -t btrfs -o "$mountopt=tmp" "$dev" /target/var/tmp \
		|| error "Could not mount tmp subvol"

	rm -rf "/target/var/tmp/podman_update"
	mkdir "/target/var/tmp/podman_update" \
		|| error "Could not create /target/var/tmp/podman_update"

	# wait for subvolume deletion to complete to make sure we can use
	# any reclaimed space
	btrfs subvolume sync "$basemount"
	umount "$basemount"
	rmdir "$basemount"
}

prepare_appfs
