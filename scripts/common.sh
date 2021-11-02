error() {
	printf "%s\n" "$@" >&2
	cleanup
	if [ -n "$soft_fail" ]; then
		echo "An error happened after changes have been applied" >&2
		echo "This most likely means success status cannot be reported correctly." >&2
		echo "Reboot to finish applying anything left" >&2
		reboot
	fi
	unlock_update
	exit 1
}

try_lock() {
	local pid

	if mkdir /tmp/.swupdate_lock 2>/dev/null; then
		echo $PPID > /tmp/.swupdate_lock/pid
		return 0
	fi

	if [ -e /tmp/.swupdate_lock ]; then
		# there is a small window where directory exists but not pid file
		# cheat around it with a sleep...
		[ -e /tmp/.swupdate_lock/pid ] || sleep 1

		if ! pid=$(cat /tmp/.swupdate_lock/pid 2>/dev/null); then
			rm -rf /tmp/.swupdate_lock
			try_lock
			return
		fi
		[ "$pid" = "$PPID" ] && return 0
		if [ "$(cat "/proc/$pid/comm" 2>/dev/null)" != swupdate ]; then
			rm -rf /tmp/.swupdate_lock
			try_lock
			return
		fi
	else
		# mkdir failed but lock does not exist, we could have been
		# raced so try again once without masking stderr and if it
		# still does not exist error out...
		if mkdir /tmp/.swupdate_lock; then
			echo $PPID > /tmp/.swupdate_lock/pid
			return 0
		fi

		[ -e /tmp/.swupdate_lock ] \
			|| error "Could not create our script install lock, aborting"
	fi
	return 1
}

lock_update() {
	# lock handling necessary for hawkbit/usb/manual install locking
	# we cannot just use flock here as this shell script will exit before
	# the end of the install, and we cannot use a simple 'mkdir lock'
	# either because no cleanup is reliable if the update process gets
	# killed, so rely on the parent's PID being a swupdate process:
	# - if the update runs normally it will clear the lock as appropriate
	# (error in script or post script)
	# - if the whole swupdate process is killed (e.g. ^C) then the pid will
	# not exist or hopefully not be swupdate again (PID recycling) and lock
	# will be freed, but that should hopefully be rare enough..
	# - if update fails between pre/post or the script gets killed abruptly
	# without killing swupdate, then we -also- detect if the swupdate pid
	# is our own parent and keep the existing lock
	# - that leaves a deadlock if an update failed without unlocking in
	# another swupdate process, but hopefully most users will only use a
	# single update vector? and even if they use multiple this should not
	# happen unless the updates are bogus.
	#
	# tl;dr: move this lock within swupdate itself eventually or accept
	# very rare deadlocks when mixing e.g. USB and hawkbit updates after
	# failures.
	try_lock && return
	echo "/tmp/.swupdate_lock exists: another update in progress? Waiting until it disappears" >&2

	while ! try_lock; do
		sleep 5;
	done
}

unlock_update() {
	rm -rf /tmp/.swupdate_lock
}

umount_if_mountpoint() {
	local dir="$1"
	if ! awk '$5 == "'"$dir"'" { exit 1 }' < /proc/self/mountinfo; then
		umount "$dir" || error "Could not umount $dir"
	fi
}

remove_loop() {
	local dev
	[ -n "$rootdev" ] || return
	dev=$(losetup -a | awk -F : "/${rootdev##*/}/ && /$((32*1024))/ { print \$1 }")
	[ -n "$dev" ] || return
	losetup -d "$dev"
}

cleanup() {
	remove_loop
	umount_if_mountpoint /target/var/lib/containers/storage_readonly/overlay
	umount_if_mountpoint /target/var/lib/containers/storage_readonly
	umount_if_mountpoint /target/var/app/rollback/volumes
	umount_if_mountpoint /target/var/app/volumes
	umount_if_mountpoint /target/var/tmp
	umount_if_mountpoint /target
}

init_common() {
	if [ -e "$TMPDIR/sw-description" ]; then
		SWDESC="$TMPDIR/sw-description"
	elif [ -e "/tmp/sw-description" ]; then
		SWDESC="/tmp/sw-description"
	else
		error "sw-description not found!"
	fi

	# debug tests
	grep -q "DEBUG_SKIP_SCRIPTS" "$SWDESC" && exit 0
}

init_common
