#!/usr/bin/env bash
# Iteration goal: separate out Bash script that sets up inside namespace environment
set -euo pipefail

NAMESPACE="NS_1"
PID=$BASHPID
BASH_INSTANCE_NAME="Main"
script_name="$0"

log_msg() {
	echo "[$NAMESPACE][$PID][$BASH_INSTANCE_NAME] $1"
}

log_msg "*************************************************************************"
log_msg "running script: $script_name"
log_msg "purpose: to start unshare namespace and setup environment outside of unshare namespace"
log_msg "script arguments: $@"
log_msg "current working directory: $PWD"
log_msg "user name: $(whoami)"
log_msg "PID: $$"
log_msg "TMP: $TMP"
log_msg "SLIRP4NETNS_UNSHARE_CHILD_PID_FIFO_PATH: $SLIRP4NETNS_UNSHARE_CHILD_PID_FIFO_PATH"
log_msg "SLIRP4NETNS_READY_FIFO_PATH: $SLIRP4NETNS_READY_FIFO_PATH"
log_msg "SLIRP4NETNS_API_SOCKET_PATH: $SLIRP4NETNS_API_SOCKET_PATH"
log_msg "SLIRP4NETNS_HOST_PORT_1: $SLIRP4NETNS_HOST_PORT_1"
log_msg "SLIRP4NETNS_NS_PORT_1: $SLIRP4NETNS_NS_PORT_1"
log_msg "SLIRP4NETNS_FW_ALLOWED_DEST_1_IP: $SLIRP4NETNS_FW_ALLOWED_DEST_1_IP"
log_msg "SLIRP4NETNS_FW_ALLOWED_DEST_1_PORT: $SLIRP4NETNS_FW_ALLOWED_DEST_1_PORT"
log_msg "*************************************************************************"





log_msg "==== Setup slirp4netns ===="
# Determine our TRUE host-side PID by reading field 4 (PPID) of /proc/self/stat.
TRUE_UNSHARE_CHILD_PID_1=$(cut -d" " -f4 /proc/self/stat)
log_msg "TRUE_UNSHARE_CHILD_PID_1 = $TRUE_UNSHARE_CHILD_PID_1"
# TRUE_UNSHARE_CHILD_PID=$(awk '/NSpid:/ {print $NF}' /proc/self/status)
TRUE_UNSHARE_CHILD_PID=$(awk '/NSpid:/ {print $2}' /proc/self/status)

log_msg "Namespace PID: $$, Host-side PID: $TRUE_UNSHARE_CHILD_PID"

# Send the true host PID to the supervisor via the inherited environment variable path
echo "$TRUE_UNSHARE_CHILD_PID" > "$SLIRP4NETNS_UNSHARE_CHILD_PID_FIFO_PATH"
log_msg "marker 1.1 - TRUE_UNSHARE_CHILD_PID sent"

# Block here until slirp4netns writes its readiness token back into the FIFO
read -r _ < "$SLIRP4NETNS_READY_FIFO_PATH" || true
log_msg "marker 1.2 - Handshake complete"


# ==== BRING UP NETWORKING INTERFACE INSIDE THE NAMESPACE ====
# slirp4netns defaults to 10.0.2.100 for the guest tap interface
# and 10.0.2.2 as the virtual gateway router address
# and 10.0.2.3 as the virtual DNS address
set +e
ip link set lo up

# echo "Waiting for slirp4netns to provision tap0 interface..."
wait_tap0_timed_out=true
for i in {1..5}; do
    log_msg "Waiting for slirp4netns to provision tap0 interface $i"
	if ip link show tap0 >/dev/null 2>&1; then
		wait_tap0_timed_out=false
		break
	fi
    
	sleep 0.5
done

if [[ "$wait_tap0_timed_out"  = "true" ]]; then
	log_msg "ERROR: Did not detect slirp4netns tap0 interface"
	exit 1
fi

log_msg "marker 1.3 - tap0 network interface discovered"

ip link set dev tap0 up
ip addr add 10.0.2.100/24 dev tap0
ip route add default via 10.0.2.2 dev tap0

set -e
log_msg "marker 1.4 - tap0 network interface initialized"

# NOTE: This has to be executed after TRUE_UNSHARE_CHILD_PID has been sent; otherwise, deadlock
# Wait briefly for the slirp4netns API socket to be created
until [ -S "$SLIRP4NETNS_API_SOCKET_PATH" ]; do sleep 0.5; done
log_msg "marker 1.5 - slirp4netns API socket active"

# Send JSON command to the API socket to configure the port forward
log_msg "Configuring port forward: Host $SLIRP4NETNS_HOST_PORT_1 -> NS $SLIRP4NETNS_NS_PORT_1"
echo "{\"execute\": \"add_hostfwd\", \"arguments\": {\"proto\": \"tcp\", \"host_addr\": \"0.0.0.0\", \"host_port\": \"$SLIRP4NETNS_HOST_PORT_1\", \"guest_addr\": \"10.0.2.100\", \"guest_port\": \"$SLIRP4NETNS_NS_PORT_1\"}}" | nc -U "$SLIRP4NETNS_API_SOCKET_PATH" > /dev/null

log_msg "==== FINISHED: Setup slirp4netns ===="


# Start configuring inside namespace environment
log_msg "*************************************************************************"
log_msg "PRE-MOUNT OF NEW ROOT DIRECTORY"
log_msg "PRE-DROP OF LINUX CAPABILITIES"
log_msg "PRE-PIVOT TO NEW ROOT DIRECTORY"
log_msg "PRE-CLEAR ENVIRONMENT VARIABLES"
log_msg "*************************************************************************"

# Network is live. Configure namespace firewalls.
# iptables -A OUTPUT -o lo -j ACCEPT
# iptables -A OUTPUT -p tcp -d 10.0.2.2 --dport 3128 -j ACCEPT
# iptables -A OUTPUT -j DROP
# iptables -A INPUT -p tcp --dport "$NS_PORT" -j ACCEPT

# Set up the interactive shell profile
# export http_proxy="http://10.0.2.2:3128"
# export https_proxy="http://10.0.2.2:3128"
# export PROMPT_COMMAND='PS1="[ns-restricted] \u@\h:\w\$ "'

log_msg "========================================================="
log_msg " Sandboxed PID Namespace Securely Initialized "
log_msg " Sandboxed Network Namespace Securely Initialized "
log_msg " Port Forward Active: Host $HOST_PORT -> Namespace $NS_PORT "
log_msg "========================================================="

# Drop CAP_NET_ADMIN and execute bash interactively
exec setpriv --ambient-caps=-net_admin --bounding-set=-net_admin bash -i < /dev/tty > /dev/tty 2>&1
