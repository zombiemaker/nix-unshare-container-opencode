#!/usr/bin/env bash

# Setup network interface and IP address for slirp4netns outbound-addr to bind to
NET_INTERFACE_DEVICE_NAME="${net_iface_device_name}"
sudo ip link add $NET_INTERFACE_DEVICE_NAME type dummy
sudo ip link set $NET_INTERFACE_DEVICE_NAME up
sudo ip addr add "${net_iface_ipv4_cidr_addr}" dev $NET_INTERFACE_DEVICE_NAME

SOCKET_PATH="/run/sbx-slirp4netns-fw.sock"
sudo rm -f "$SOCKET_PATH"    

# Initialize the base chain on startup

# Initialize the base chain on startup
if ! iptables -S SANDBOX_OUTPPUT &>/dev/null; then
	# The chain is missing, create it
	sudo iptables -N SANDBOX_OUTPUT
fi

iptables -C OUTPUT -j SANDBOX_OUTPUT 2>/dev/null
if [ $? -ne 0 ]; then
	# The rule is missing, so add
	iptables -I OUTPUT -j SANDBOX_OUTPUT
fi 

logger -t sbx-slirp4netns-fw "systemd daemon started. SANDBOX_OUTPUT iptables chain initialized."

# Listen on the socket and process requests sequentially
socat UNIX-LISTEN:"$SOCKET_PATH",fork,mode=0660,group=sbx-slirp4netns-fw SYSTEM:'
	read input

	# Validate input structure: PID IP PORT ACTION
	if echo "$input" | grep -E "^[0-9]+ [0-9.]+ [0-9]+ (ALLOW|DROP|DELETE)$"; then
		read -r pid gid ip port action <<< "$input"

		if [ "$action" = "ALLOW" ]; then
			iptables -A SANDBOX_OUTPUT -m owner --gid-owner "$gid" -d "$ip" -p tcp --dport "$port" -j ACCEPT
			logger -t sbx-slirp4netns-fw "SUCCESS: Allowed GID $gid to access $ip:$port"
		elif [ "$action" = "DROP" ]; then
			iptables -A SANDBOX_OUTPUT -m owner --gid-owner "$gid" -j DROP
			logger -t sbx-slirp4netns-fw "SUCCESS: Added default DROP rule for GID $gid"
		elif [ "$action" = "DELETE" ]; then
			# Delete both the allow and catch-all drop rules matching that specific GID
			iptables -D SANDBOX_OUTPUT -m owner --gid-owner "$gid" -j DROP || true
		fi

		echo "SUCCESS"
	else
		logger -t sbx-slirp4netns-fw -p user.warn "WARNING: Rejected malformed payload: \"$input\""
		echo "ERROR: Invalid Input Structure"
	fi
'
