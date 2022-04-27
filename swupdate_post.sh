#!/bin/sh

TMPDIR="${TMPDIR:-/var/tmp}"
SCRIPTSDIR="$TMPDIR/scripts"

. "$SCRIPTSDIR/common.sh"

. "$SCRIPTSDIR/post_init.sh"
. "$SCRIPTSDIR/post_appfs.sh"
. "$SCRIPTSDIR/post_rootfs.sh"
. "$SCRIPTSDIR/post_boot.sh"
. "$SCRIPTSDIR/post_success.sh"

# note we do not unlock after cleanup unless another update
# is expected to run after this one, a fresh boot is needed.
rm -rf "$SCRIPTSDIR"

POST_ACTION=$(post_action)
case "$POST_ACTION" in
poweroff)
	echo "swupdate triggering poweroff!" >&2
	poweroff
	pkill -9 swupdate
	sleep infinity
	;;
wait)
	echo "swupdate waiting until external reboot" >&2
	sleep infinity
	;;
container)
	unlock_update
	if [ -n "$SWUPDATE_HAWKBIT" ]; then
		echo "Restarting swupdate-hawkbit service" >&2
		# remove stdout/stderr to avoid sigpipe when parent is killed
		rc-service swupdate-hawkbit restart >/dev/null 2>&1
	fi
	;;
*)
	echo "swupdate triggering reboot!" >&2
	reboot
	pkill -9 swupdate
	sleep infinity
	;;
esac
