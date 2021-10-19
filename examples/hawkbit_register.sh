#!/bin/sh

# Script configuration: edit this!
MANAGEMENT_LOGIN=
HAWKBIT_URL=
HAWKBIT_TENANT=default
# set custom options for suricatta block or in general in the config
CUSTOM_SWUPDATE_SURICATTA_CFG="" # e.g. "polldelay = 86400;"
CUSTOM_SWUPDATE_CFG=""
# set to non-empty if server certificate is invalid
SSL_NO_CHECK_CERT=
# or set to cafile that must have been updated first
SSL_CAFILE=
# .. or add your own options if required
CURLOPT=-s

# Configuration required on server
# you'll want something like this in your application.properties config to allow device creation:
#hawkbit.server.im.users[1].username=device
#hawkbit.server.im.users[1].password={noop}test
# or ...password={bcrypt}$2a$12$gA8HoyIVTGypGXIHXgfl.eM/eqXdcwHgEpsmaRN/svm17Gu4oFvEm
#hawkbit.server.im.users[1].permissions=CREATE_TARGET,READ_TARGET_SECURITY_TOKEN


error() {
	echo "$@" >&2
	exit 1
}

wait_network() {
	local HAWKBIT_HOST=${HAWKBIT_URL#http*://}
	HAWKBIT_HOST=${HAWKBIT_HOST%%/*}

	# wait up to 30 seconds for network
	timeout 30s sh -c "while ! ping -q -c 1 $HAWKBIT_HOST >/dev/null 2>&1; do sleep 1; done"
}

init() {
	[ -n "$MANAGEMENT_LOGIN" ] && [ -n "$HAWKBIT_URL" ] || error "Variables top of script must be set"

	# DEVICE_ID="1234-1234-1234" with model-id, lot, serial in this order
	DEVICE_ID=$(dd if=/sys/bus/nvmem/devices/imx-ocotp0/nvmem bs=4 skip=56 count=2 status=none \
			| xxd -p \
			| sed -e 's/\(..\)\(..\)....\(..\)\(..\)\(..\)\(..\)/\2\1-\6\5-\4\3/')

	[ -n "$SSL_NO_CHECK_CERT" ] && CURLOPT="$CURLOPT -k"
	if [ -n "$SSL_CAFILE" ]; then
		CURLOPT="$CURLOPT --cacert $SSL_CAFILE"
	else
		# set default for swupdate
		SSL_CAFILE="/etc/ssl/certs/ca-certificates.crt"

	fi


	wait_network

	command -v curl > /dev/null \
		|| apk add curl \
		|| error "curl not found and could not be installed"
}

# register a device name for us
register_device() {
	CONTROLLER_ID="armadillo-$DEVICE_ID${REGISTER_RETRY:+-$REGISTER_RETRY}"
	curl $CURLOPT -u "$MANAGEMENT_LOGIN" -X POST "${HAWKBIT_URL}/rest/v1/targets" \
		-H 'Content-Type: application/json' -d '[{
			"controllerId": "'"$CONTROLLER_ID"'",
			"name": "Armadillo '"$DEVICE_ID${REGISTER_RETRY:+ ($REGISTER_RETRY)}"'"
		}]' -o curlout \
		|| error "Could not send request to $HAWKBIT_URL"
# known to return one of the following:
# [{"createdBy":"device","createdAt":1634611542824,"lastModifiedBy":"device","lastModifiedAt":1634611542824,"name":"Device 01","description":"One device","controllerId":"device01","updateStatus":"unknown","securityToken":"005cec0b77d38f4081cf3682c9439e0b","requestAttributes":true,"_links":{"self":{"href":"https://my.hawkbit.server/rest/v1/targets/device01"}}}]
# {"exceptionClass":"org.eclipse.hawkbit.repository.exception.EntityAlreadyExistsException","errorCode":"hawkbit.server.error.repo.entitiyAlreayExists","message":"The given entity already exists in database"}
# {"timestamp":"2021-10-19T02:45:20.688+0000","status":401,"error":"Unauthorized","message":"Unauthorized","path":"/rest/v1/targets"}

	
	# note: we should really use something like jq for this,
	# but it's a whole 1MB of dependencies just to get this token...
	SECURITY_TOKEN=$(sed -ne 's/.*securityToken[^0-9a-f]*\([0-9a-f]*\).*/\1/p' < curlout)
	[ -n "$SECURITY_TOKEN" ] && return

	grep -q "Unauthorized" curlout \
		&& error "defined user $MANAGEMENT_LOGIN is not valid or does not have CREATE_TARGET permission"
	grep -q "createdBy" curlout \
		&& error "defined user $MANAGEMENT_LOGIN does not have READ_TARGET_SECURITY_TOKEN permission"
	grep -q "AlreadyExists" curlout \
		|| error "Unknown error while attempting to register: $(cat curlout)"

	# try again with another name
	REGISTER_RETRY=$((REGISTER_RETRY+1))
	register_device
}

# checks the device we just created is accessible.
# XXX do we need this at all?
configure_device() {
	local CONTROLLER_URL="${HAWKBIT_URL}/${HAWKBIT_TENANT}/controller/v1/${CONTROLLER_ID}"
	local AUTHORIZATION="Authorization: TargetToken $SECURITY_TOKEN"

	echo "Trying $AUTHORIZATION $CONTROLLER_URL"

	curl $CURLOPT -X GET -H "$AUTHORIZATION" "$CONTROLLER_URL" -o curlout \
		|| error "Could not send request to $HAWKBIT_URL"
#{"config":{"polling":{"sleep":"00:05:00"}},"_links":{"configData":{"href":"https://tmp.xmpp.codewreck.org/DEFAULT/controller/v1/device01/configData"}}}

	grep -q "config" curlout \
		|| error "Could not get our own config ($CONTROLLER_ID)"
	#grep -q "configData" curlout \
	#	|| error "Device $CONTROLLER_ID was just registered, but already configured?"

	# XXX could send custom attributes here.
	# note this is not valid if data is empty
	#curl $CURLOPT -X PUT -H "$AUTHORIZATION" "$CONTROLLER_URL/configData" \
	#	-H 'Content-Type: application/json' \
	#	-d '{
	#		"mode": "merge",
	#		"data": {
	#			"attribute": "value",
	#			"attribute2": "value"
	#		},
	#		"status": {
	#			"result": { "finished": "success" },
	#			"execution": "closed",
	#			"details": []
	#		}
	#	}' --fail -o /dev/null \
	#	|| error "Could not configure device"
# empty reply, use --fail to check http error code instead
}

update_swupdate_cfg() {
	# nuke the suricatta section if present, then append our own
	sed '/suricatta:/,/}/d' < /etc/swupdate.cfg > swupdate.cfg
	cat >> swupdate.cfg <<EOF
suricatta: {
  url = "${HAWKBIT_URL%/}";
  tenant = "$HAWKBIT_TENANT";
  id = "$CONTROLLER_ID";
  targettoken = "$SECURITY_TOKEN";
  cafile = "$SSL_CAFILE";
EOF
	if [ -n "$SSL_NO_CHECK_CERT" ]; then
		echo "  nocheckcert = true;" >> swupdate.cfg
	fi
	if [ -n "$CUSTOM_SWUPDATE_SURICATTA_CFG" ]; then
		echo "$CUSTOM_SWUPDATE_SURICATTA_CFG" >> swupdate.cfg
	fi
	echo "}" >> swupdate.cfg
	if [ -n "$CUSTOM_SWUPDATE_CFG" ]; then
		echo >> swupdate.cfg
		echo "$CUSTOM_SWUPDATE_CFG" >> swupdate.cfg
	fi
	mv swupdate.cfg /etc/swupdate.cfg

	# enable the service
	rc-update add swupdate-hawkbit default
}

main() {
	local DEVICE_ID SECURITY_TOKEN REGISTER_RETRY
	local temp

	temp=$(mktemp -d /tmp/register_hawkbit.XXXXXX) \
		|| error "Could not create temporary directory"
	trap "rm -rf $temp" EXIT

	cd "$temp" || error "Could not enter temp dir"

	init
	wait_network
	register_device
	#configure_device
	update_swupdate_cfg
}

main
