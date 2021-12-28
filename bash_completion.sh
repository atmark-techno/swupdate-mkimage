_mkimage_sh()
{
	local cur prev words cword split
	_init_completion || return
	case "$prev" in
	-o|--out)
		_filedir
		return
		;;
	-c|--config)
		_filedir 'conf'
		return
		;;
	esac

	COMPREPLY=($(compgen -W '-o --out -c --config' -- "$cur"))
	_filedir 'desc'
} && complete -F _mkimage_sh ./mkimage.sh


_podman_image_list()
{
	local filter
	filter="${cur%:*}"
	if [ "$filter" != "$cur" ]; then
		podman image list --format '{{range .Names}}{{.}}{{println}}{{end}}' "$filter" \
			| awk -F: '$1 == "'"$filter"'" { print $2 }'
	else
		podman image list --format '{{range .Names}}{{.}}{{println}}{{end}}{{.Id}}' \
			| sed -e 's:^localhost/\(.*\):\1\n&:'
	fi
}
_podman_partial_image()
{
	local cur curcol prev words cword split image
	# We do not split colons here to have sensible prev/cur variable,
	# but we are expected to only fill in whatever is after the colon
	# in COMPREPLY so care must be taken after on...
	_init_completion -n ":" || return
	curcol=${cur##*:}
	case "$prev" in
	-o|--output)
		_filedir
		return
		;;
	-b|--base)
		COMPREPLY=($(compgen -W "$(_podman_image_list)" -- "$curcol"))
		return
		;;
	-R|--rename)
		return
		;;
	esac

	if [[ $cur == -* ]]; then
		COMPREPLY=($(compgen -W "-b --base -o --output -R --rename" -- "$curcol"))
		return
	fi

	COMPREPLY=($(compgen -W "$(_podman_image_list)" -- "$curcol"))
} && complete -F _podman_partial_image podman_partial_image

_hawkbit_create-update_sh()
{
	local cur prev words cword split
	_init_completion || return
	COMPREPLY=($(compgen -W '--new --failed --start --no-rollout --keep-tmpdir' -- "$cur"))
	_filedir 'swu'
} && complete -F _hawkbit_create-update_sh ./create-update.sh \
  && complete -F _hawkbit_create-update_sh ./hawkbit/create-update.sh
