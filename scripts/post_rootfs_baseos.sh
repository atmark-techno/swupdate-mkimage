baseos_upgrade_fixes() {
	local baseos_version

	# if user has local certificates we should regenerate the bundle
	if stat /target/usr/local/share/ca-certificates/* >/dev/null 2>&1; then
		FILTER="WARNING: ca-certificates.crt does not contain exactly one certificate or CRL: skipping" \
			podman_info run --net=none --rootfs /target update-ca-certificates 2>/dev/null \
				|| error "update-ca-certificates failed"
	fi

	### workaround section, these can be removed once we consider we no longer
	### support a given version.

	# note this is the currently running version,
	# not the version we install (which would always be too recent!)
	baseos_version=$(cat /etc/atmark-release) || return

	# not a baseos install? skip fixes...
	[ -n "$baseos_version" ] || return

	# add /var/at-log to fstab (added in 3.15.0-at.1)
	if grep -q /dev/mmcblk2 /proc/cmdline \
	    && [ -e /dev/mmcblk2gp1 ] \
	    && ! grep -q /dev/mmcblk2gp1 /target/etc/fstab; then
		cat >> /target/etc/fstab <<'EOF' \
			|| error "Could not append to target /etc/fstab"
/dev/mmcblk2gp1	/var/at-log			vfat	defaults			0 0
EOF
	fi

	# add noatime to fstab (added in 3.15.0-at.2)
	if ! grep -q noatime /target/etc/fstab; then
		sed -i -e '/squashfs/ ! s/defaults/&,noatime/' \
				-e 's/,subvol=/,noatime&/' /target/etc/fstab \
			|| error "Could not update fstab"
	fi

	# Remove /var/log/rc.log we no longer write to
	# (removed in 3.15.4-at.6)
	if [ -e /var/log/rc.log ]; then
		rm -f /var/log/rc.log
	fi

	# Increase swupdate.cfg verbosity
	# (done in 3.16-at.1)
	if grep -q 'loglevel = 2;' /target/etc/swupdate.cfg; then
		sed -i -e 's/loglevel = 2/loglevel = 3/' /target/etc/swupdate.cfg \
			|| error "Could not update swupdate.cfg"
	fi
}

baseos_upgrade_fixes
