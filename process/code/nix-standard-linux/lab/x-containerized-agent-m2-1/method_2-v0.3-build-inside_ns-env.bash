#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="NS_1"
PID=$BASHPID
BASH_INSTANCE_NAME="inside_ns_main"
script_name="$0"

source ./fn.bash
get_namespace_id "user" uid_ns
get_namespace_id "pid" pid_ns

log_msg() {
	echo "[$NAMESPACE][$PID][$BASH_INSTANCE_NAME] $1"
}

log_msg "*************************************************************************"
log_msg "running script: $script_name"
log_msg "purpose: to start unshare namespace and setup environment outside of unshare namespace"
log_msg "script arguments: $@"
log_msg "current working directory: $PWD"
log_msg "user name: $(whoami)"
log_msg "pid ns: $pid_ns"
log_msg "uid ns: $uid_ns"
log_msg "PID: $PID"
log_msg "TMP: $TMP"
log_msg "SLIRP4NETNS_UNSHARE_CHILD_PID_FIFO_PATH: $SLIRP4NETNS_UNSHARE_CHILD_PID_FIFO_PATH"
log_msg "SLIRP4NETNS_READY_FIFO_PATH: $SLIRP4NETNS_READY_FIFO_PATH"
log_msg "SLIRP4NETNS_API_SOCKET_PATH: $SLIRP4NETNS_API_SOCKET_PATH"
log_msg "SLIRP4NETNS_HOST_PORT_1: $SLIRP4NETNS_HOST_PORT_1"
log_msg "SLIRP4NETNS_NS_PORT_1: $SLIRP4NETNS_NS_PORT_1"
log_msg "*************************************************************************"


log_msg "==== Setup slirp4netns ===="
# Read /proc/self/status without forking a sub-process
# This extracts the leftmost value of NSpid, which is the Host PID
L0_PIDNS_CURRENT_PROCESS_PID=""
while IFS= read -r line; do
    if [[ "$line" =~ ^NSpid:[[:space:]]*([0-9]+) ]]; then
        L0_PIDNS_CURRENT_PROCESS_PID="${BASH_REMATCH[1]}"
        break
    fi
done < /proc/self/status

# Verify we successfully grabbed the host PID
if [ -z "$L0_PIDNS_CURRENT_PROCESS_PID" ]; then
    log_msg "Failed to determine host PID" >&2
    exit 1
fi

log_msg "L0_PIDNS_CURRENT_PROCESS_PID = $L0_PIDNS_CURRENT_PROCESS_PID"

# Send the true host PID to the supervisor via the inherited environment variable path
echo "$L0_PIDNS_CURRENT_PROCESS_PID" > "$SLIRP4NETNS_UNSHARE_CHILD_PID_FIFO_PATH"
log_msg "marker 1.1 - L0_PIDNS_CURRENT_PROCESS_PID sent"

# Block here until slirp4netns writes its readiness token back into the FIFO
read -r _ < "$SLIRP4NETNS_READY_FIFO_PATH" || true
log_msg "marker 1.2 - Handshake complete"


# ==== BRING UP NETWORKING INTERFACE INSIDE THE NAMESPACE ====
log_msg "Waiting for slirp4netns to provision tap0 interface..."
ip link set lo up

wait_tap0_timed_out=true
for i in {1..20}; do
    log_msg "Waiting...$i"
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

# NOTE: This has to be executed after L0_PIDNS_CURRENT_PROCESS_PID has been sent; otherwise, deadlock
# Wait briefly for the slirp4netns API socket to be created
until [ -S "$SLIRP4NETNS_API_SOCKET_PATH" ]; do sleep 0.5; done
log_msg "marker 1.5 - slirp4netns API socket active"

# Send JSON command to the API socket to configure the port forward
log_msg "Configuring port forward: Host NS $SLIRP4NETNS_HOST_PORT_1 -> Container NS $SLIRP4NETNS_NS_PORT_1"
echo "{\"execute\": \"add_hostfwd\", \"arguments\": {\"proto\": \"tcp\", \"host_addr\": \"0.0.0.0\", \"host_port\": \"$SLIRP4NETNS_HOST_PORT_1\", \"guest_addr\": \"10.0.2.100\", \"guest_port\": \"$SLIRP4NETNS_NS_PORT_1\"}}" | nc -U "$SLIRP4NETNS_API_SOCKET_PATH" > /dev/null
log_msg "==== FINISHED: Setup slirp4netns ===="


# Start configuring inside namespace environment
log_msg "*************************************************************************"
log_msg "PRE-MOUNT OF NEW ROOT DIRECTORY"
log_msg "PRE-MOUNT OF NEW PROC DIRECTORY"
log_msg "PRE-MOUNT OF NEW SYS DIRECTORY"
log_msg "PRE-DROP OF LINUX CAPABILITIES"
log_msg "PRE-PIVOT TO NEW ROOT DIRECTORY"
log_msg "PRE-CLEAR ENVIRONMENT VARIABLES"
log_msg "*************************************************************************"

# Network is live. Configure namespace firewalls.
log_msg "marker 1.6 - configuring iptables"
src_ipv4_addr="10.0.2.100"
dst_ipv4_addr="192.168.1.90"
dst_proto="tcp"
dst_port="9943"
iptables -N SANDBOX_OUTPUT
iptables -I OUTPUT -j SANDBOX_OUTPUT
iptables -A SANDBOX_OUTPUT -s $src_ipv4_addr -d $dst_ipv4_addr -p $dst_proto --dport $dst_port -j ACCEPT
iptables -A SANDBOX_OUTPUT -s $src_ipv4_addr -d $dst_ipv4_addr -p icmp -j ACCEPT
iptables -A SANDBOX_OUTPUT -s $src_ipv4_addr -j DROP
# iptables -L -n --line-numbers
log_msg "marker 1.7 - configuring iptables FINISHED"


# Set up the interactive shell profile
# export http_proxy="http://10.0.2.2:3128"
# export https_proxy="http://10.0.2.2:3128"
# export PROMPT_COMMAND='PS1="[ns-restricted] \u@\h:\w\$ "'

log_msg "========================================================="
log_msg " Sandboxed PID Namespace Securely Initialized "
log_msg " Sandboxed Network Namespace Securely Initialized "
# log_msg " Port Forward Active: Host $HOST_PORT -> Namespace $NS_PORT "
log_msg "========================================================="

# Drop CAP_NET_ADMIN and execute bash interactively
exec setpriv --ambient-caps=-net_admin --bounding-set=-net_admin bash -i