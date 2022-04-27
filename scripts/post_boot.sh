cleanup_boot() {
	local dev

	if ! needs_reboot; then
		return
	fi

	if [ "$rootdev" = "/dev/mmcblk2" ]; then
		if fw_printenv dek_spl_offset | grep -q dek_spl_offset=0x; then
			echo "writing encrypted uboot update, rollback will be done by current uboot on reboot"
			fw_setenv encrypted_update_available 1
		else
			mmc bootpart enable "$((ab+1))" 0 "$rootdev" \
				|| error "Could not flip mmc boot flag"
		fi
	elif [ -s /etc/fw_env.config ]; then
		# if uboot env is supported, use it (e.g. sd card)
		fw_setenv mmcpart $((ab+1)) \
			|| error " Could not setenv mmcpart"
	elif [ -e /target/boot/extlinux.conf ]; then
		# assume gpt boot e.g. extlinux
		sgdisk --attributes=$((ab+1)):set:2 --attributes=$((!ab+1)):clear:2 "$rootdev" \
			|| error "Could not set boot attribute"

		sed -i -e "s/root=[^ ]*/root=LABEL=rootfs_${ab}/" /target/boot/extlinux.conf \
			|| error "Could not update extlinux.conf"
		extlinux -i /target/boot || error "Could not reinstall bootloader"
	else
		error "Do not know how to A/B switch this system"
	fi

	# from here on, failure is not appropriate
	soft_fail=1
}

cleanup_boot
