#!/usr/bin/env bash

# --- Everything runs OUTSIDE the new unshare namespace ---

NAMESPACE="Level 0 namespace (host)"
script_name="$0"
echo "*************************************************************************"
echo "$NAMESPACE: running script: $script_name"
echo "$NAMESPACE: purpose: to start unshare namespace and setup environment outside of unshare namespace"
echo "$NAMESPACE: script arguments: $@"
echo "$NAMESPACE: current working directory: $PWD"
echo "$NAMESPACE: user name: $(whoami)"
echo "$NAMESPACE: PID: $$"
echo "$NAMESPACE: TMP: $TMP"


# network interface must match what is configured in /etc/nixos/configurations.nix
SLIRP4NETNS_HOST_NET_INTERFACE="slirp4netns_0"  # this is defined in /etc/nixos/configurations.nix

# Get the specific internal source IP assigned to that interface
if [ -n "$SLIRP4NETNS_HOST_NET_INTERFACE" ]; then
    SLIRP4NETNS_HOST_IPV4=$(ip -4 addr show $SLIRP4NETNS_HOST_NET_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
else
    echo "Error: No default network interface found." >&2
fi

echo "$NAMESPACE: SLIRP4NETNS_HOST_NET_INTERFACE: $SLIRP4NETNS_HOST_NET_INTERFACE"
echo "$NAMESPACE: SLIRP4NETNS_HOST_IPV4: $SLIRP4NETNS_HOST_IPV4"

# Random slirp4netns host forwarding port
SLIRP4NETNS_HOST_PORT_MIN=9500
SLIRP4NETNS_HOST_PORT_MAX=9999
SLIRP4NETNS_HOST_PORT_RANGE=$(( SLIRP4NETNS_HOST_PORT_MAX - SLIRP4NETNS_HOST_PORT_MIN + 1 ))

# Generate the random number for host port for port-forwarding
SLIRP4NETNS_HOST_PORT_1=$(( (RANDOM % SLIRP4NETNS_HOST_PORT_RANGE) + SLIRP4NETNS_HOST_PORT_MIN ))
echo "$NAMESPACE: SLIRP4NETNS_PORT = $SLIRP4NETNS_HOST_PORT_1"

# user group name must match what is configured in /etc/nixos/configurations.nix
SLIRP4NETNS_FW_GROUP_NAME="sbx-slirp4netns-fw"
echo "$NAMESPACE: SLIRP4NETNS_FW_GROUP_NAME = $SLIRP4NETNS_FW_GROUP_NAME"

SLIRP4NETNS_FW_GROUP_ID=$(getent group $SLIRP4NETNS_FW_GROUP_NAME | cut -d: -f3)
echo "$NAMESPACE: SLIRP4NETNS_FW_GROUP_ID = $SLIRP4NETNS_FW_GROUP_ID"

# socket path must match what is configured in /etc/nixos/configurations.nix
SLIRP4NETNS_FW_SOCKET_PATH="/run/sbx-slirp4netns-fw.sock"
echo "$NAMESPACE: SLIRP4NETNS_FW_SOCKET_PATH = $SLIRP4NETNS_FW_SOCKET_PATH"

if [ ! -S "$SLIRP4NETNS_FW_SOCKET_PATH" ]; then
	log_msg "ERROR: Control socket $SLIRP4NETNS_FW_SOCKET_PATH does not exist or is unavailable."
	exit 1
fi

# TODO: change from single to multiple ip:port
SLIRP4NETNS_FW_ALLOWED_DEST_1_IP="192.168.1.90"
echo "$NAMESPACE: SLIRP4NETNS_FW_ALLOWED_DEST_1_IP = $SLIRP4NETNS_FW_ALLOWED_DEST_1_IP"
SLIRP4NETNS_FW_ALLOWED_DEST_1_PORT="9943"
echo "$NAMESPACE: SLIRP4NETNS_FW_ALLOWED_DEST_1_PORT = $SLIRP4NETNS_FW_ALLOWED_DEST_1_PORT"
SLIRP4NETNS_LOG_FILE_NAME="$TMP/slirp4netns-$SRANDOM.log"
echo "$NAMESPACE: SLIRP4NETNS_LOG_FILE_NAME: $SLIRP4NETNS_LOG_FILE_NAME"
echo "*************************************************************************"

UNSHARE_LOG_FILE_NAME="$TMP/build-inside_ns-$SRANDOM.log"
echo "$NAMESPACE: UNSHARE_LOG_FILE_NAME: $UNSHARE_LOG_FILE_NAME"

# Handle Script Arguments
DEBUG=false
MODE="shell"
BUILD_INSIDE_NS_ENV_SCRIPT_PATH=""
INSIDE_NS_ENV_READY_FILE_PATH="$TMP/$SRANDOM"
OTHER_ARGS=()

# Loop through all positional parameters
while [[ $# -gt 0 ]]; do
	case "$1" in
		--mode)
			MODE="${2,,}"
			shift 2
			;;
		--internal-env-script)
			# Get the value of the next argument
			BUILD_INSIDE_NS_ENV_SCRIPT_PATH="$2"
			shift 2 # Shift past the flag and its value
			;;
		--start-shell-script)
			# Get the value of the next argument
			START_SHELL_SCRIPT_PATH="$2"
			shift 2 # Shift past the flag and its value
			;;
		*)
			# Append all other arguments to our array
			OTHER_ARGS+=("$1")
			shift # Shift past the current argument
			;;
	esac
done

# Verify that the required internal-env-script parameter was provided
if [[ -z "$BUILD_INSIDE_NS_ENV_SCRIPT_PATH" ]]; then
	echo "Error: --internal-env-script is required." >&2
	exit 1
fi

# Verify that the required start-shell-script parameter was provided
if [[ -z "$START_SHELL_SCRIPT_PATH" ]]; then
	echo "Error: --start-shell-script is required." >&2
	exit 1
fi


echo "INSIDE_NS_ENV_READY_FILE_PATH = $INSIDE_NS_ENV_READY_FILE_PATH"

log_msg() {
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

cleanup() {
    log_msg "Orchestrator exiting. Cleaning up background tasks..."

	# Clean up 2-way anonymous pipe FDs
	exec 3>&-
	exec 4>&-

	# Clean unshare processes cleanly via the parent wrapper
    if [[ -n "$UNSHARE_PARENT_PID" ]]; then
        kill -9 "$UNSHARE_PARENT_PID" 2>/dev/null
		wait "$UNSHARE_PARENT_PID" 2>/dev/null
    fi

    # Clean up slirp4netns child process
    if [[ -n "$SLIRP_PID" ]]; then
        kill -15 "$SLIRP_PID" 2>/dev/null
        wait "$SLIRP_PID" 2>/dev/null
    fi

	# Clean up iptables rules for slirp4netns
	DELETE_ALL_CMD="echo \"$SLIRP_PID $SLIRP4NETNS_FW_GROUP_ID $SLIRP4NETNS_HOST_IPV4 DELETE_ALL\" | nc -U \"$SLIRP4NETNS_FW_SOCKET_PATH\""
	DELETE_ALL_CMD_RESPONSE=$(sg "$SLIRP4NETNS_FW_GROUP_NAME" "$DELETE_ALL_CMD")
	DELETE_ALL_CMD_EXITCODE=$?	
	log_msg "DELETE Rule Submission Result: $DELETE_ALL_CMD_RESPONSE (exit code $DELETE_ALL_CMD_EXITCODE)"
}

setup_parent_child_communication() {
	log_msg "=== Setup 2-Way Anonymous Pipes ==="
	# Create two anonymous pipes (FIFOs) on the host just to link the FDs
	# (These act as the bridge before the namespaces are locked down)
	PIPE_TO_CHILD=$(mktemp -u)
	PIPE_FROM_CHILD=$(mktemp -u)
	mkfifo "$PIPE_TO_CHILD" "$PIPE_FROM_CHILD"

	# Open the pipes on custom file descriptors (FD 3 and FD 4)
	exec 3<>"$PIPE_TO_CHILD"
	exec 4<>"$PIPE_FROM_CHILD"

	# Clean up the filesystem links immediately; the open FDs are all we need
	rm "$PIPE_TO_CHILD" "$PIPE_FROM_CHILD"
	log_msg "=== FINISHED: Setup 2-Way Anonymous Pipes ==="
}

start_unshare() {
	log_msg "=== Start Background unshare Namespace Environment ==="
	# unshare parameters:
	# --cgroup, -C creates new cgroup namespace
	# --ipc, -i creates new ipc namespace
	# --mount, -m creates new mount namespace
	# --net, -n creates new network namespace
	#	This needs the host to have slirp4netns installed and configured to
	#	bridge between unshare network namespace and host network namespace
	# --pid, -p creates new process PID namespace (forks process?)
	# --time, -T creates new time namespace
	# --user, -U creates new user ID / group ID namespace
	# --uts creates new uts namespace
	# --map-root-user, -r maps current user uid and gid to root inside namespace
	# --map-users <level 1 namespace uid>:<level 0 namespace uid>:<number of uids>
	# --map-groups <level 1 namespace gid>:<level 0 namespace gid>:<number of gids>
	#
	# NOT AVAILABLE for unshare v2.42.2
	# --clear-env do not pass the environment variables of the calling process to the unshared process.
	#
	# NOTE: "stdbuf -oL -eL" before bash is to force flushing of outputs to log file
	#   The '3<&3 4>&4' forces the FDs to remain open across the unshare exec boundary
	# NOTE: need "--net" to mount "/sys"
	# NOTE: need "--map-users" and "--map-groups" for buildah and podman to work
	unshare \
		--user \
		--cgroup \
		--ipc \
		--mount \
		--net \
		--pid \
		--time \
		--uts \
		--fork \
		--map-root-user \
		--map-users auto \
		--map-groups auto \
		stdbuf -oL -eL bash \
			"$BUILD_INSIDE_NS_ENV_SCRIPT_PATH" \
			--ready-file-path "$INSIDE_NS_ENV_READY_FILE_PATH" \
			--start-shell-script "$START_SHELL_SCRIPT_PATH" \
			> "$UNSHARE_LOG_FILE_NAME" \
			2>&1 \
			3<&3 \
			4>&4 &

	UNSHARE_PARENT_PID=$!
	log_msg "Host PID for unshare parent process $UNSHARE_PARENT_PID"

	# Give unshare process time to setup
	sleep 1

	# Use the forked unshare child process PID not the parent unshare wrapper process PID
	UNSHARE_CHILD_PID=$(pgrep -P $UNSHARE_PARENT_PID -o)
	log_msg "Host PID for unshare forked child process $UNSHARE_CHILD_PID"

	# Clean up the background sleep process when this orchestrator exits
	# NOTE: need kill -9 to kill sleep infinity
	trap cleanup EXIT
	log_msg "=== FINISHED: Start Background unshare Namespace Environment ==="
}

verify_parent_child_communication() {
	log_msg "=== Verify 2-Way Anonymous Pipe Communication ==="
	# Parent communicates through the established FDs
	log_msg "[Parent] Sending verification message to child"
	echo "Hello child, can you hear me?" >&3

	# Read the reply from the child
	read -u 4 REPLY
	log_msg "[Parent] Received from child: $REPLY"
	log_msg "=== FINISHED: Verify 2-Way Anonymous Pipe Communication ==="
}

setup_bridge_network() {
	log_msg "=== Setup Bridge Network For unshare Namespace ==="
	# Attach slirp4netns from outside the namespace to connect it to the internet
	# doc on api-socket: https://github.com/rootless-containers/slirp4netns/blob/master/slirp4netns.1.md#api-socket
	slirp_socket="/tmp/slirp4netns.$SRANDOM.sock"
	
	SLIRP4NETNS_COMMAND="slirp4netns --api-socket=\"$slirp_socket\" --configure --mtu=65520 --disable-host-loopback --outbound-addr=\"$SLIRP4NETNS_HOST_IPV4\" $UNSHARE_CHILD_PID tap0"
	log_msg "SLIRP4NETNS_COMMAND = $SLIRP4NETNS_COMMAND"

	# sg program expects the second position parameter to be one single entity - therefore enclose command string variable in quotes
	sg "$SLIRP4NETNS_FW_GROUP_NAME" "$SLIRP4NETNS_COMMAND" > $SLIRP4NETNS_LOG_FILE_NAME 2>&1 &	
	SLIRP_PID=$!
	
	# Wait briefly for the socket to initialize, then send the port-forwarding rule
	sleep 1

	# NOTE: to change values for variables within '@', edit flake.nix that uses this template script
	read -r -d '' JSON_COMMAND << JSON
	{ "execute": "add_hostfwd", "arguments": { "proto": "tcp", "host_addr":  "@slirp4netns_port_forward_host_addr@", "host_port":  $SLIRP4NETNS_HOST_PORT_1, "guest_addr": "10.0.2.100", "guest_port": $SLIRP4NETNS_HOST_PORT_1 }}
JSON
	
	# Format: add_hostfwd:proto:host_addr:host_port:guest_addr:guest_port
	echo -n "$JSON_COMMAND" | nc -U "$slirp_socket"

	# Setup host iptables firewall rules for this slirp4netns instance
	log_msg "Initiating firewall rule updates for PID: $SLIRP_PID..."

	# Send the ACCEPT rule payload
	ACCEPT_CMD="echo \"$SLIRP_PID $SLIRP4NETNS_FW_GROUP_ID $SLIRP4NETNS_HOST_IPV4 ACCEPT $SLIRP4NETNS_FW_ALLOWED_DEST_1_IP tcp $SLIRP4NETNS_FW_ALLOWED_DEST_1_PORT\" | nc -U \"$SLIRP4NETNS_FW_SOCKET_PATH\""
	# sg program expects the second position parameter to be one single entity - therefore enclose command string variable in quotes
	ACCEPT_CMD_RESPONSE=$(sg "$SLIRP4NETNS_FW_GROUP_NAME" "$ACCEPT_CMD")
	ACCEPT_CMD_EXITCODE=$?	
	log_msg "ACCEPT Rule Submission Result: $ACCEPT_CMD_RESPONSE (exit code $ACCEPT_CMD_EXITCODE)"

	# Send the ACCEPT_ICMP rule payload
	ACCEPT_ICMP_CMD="echo \"$SLIRP_PID $SLIRP4NETNS_FW_GROUP_ID $SLIRP4NETNS_HOST_IPV4 ACCEPT $SLIRP4NETNS_FW_ALLOWED_DEST_1_IP icmp\" | nc -U \"$SLIRP4NETNS_FW_SOCKET_PATH\""
	# sg program expects the second position parameter to be one single entity - therefore enclose command string variable in quotes
	ACCEPT_ICMP_CMD_RESPONSE=$(sg "$SLIRP4NETNS_FW_GROUP_NAME" "$ACCEPT_ICMP_CMD")
	ACCEPT_ICMP_CMD_EXITCODE=$?	
	log_msg "ACCEPT Rule Submission Result: $ACCEPT_ICMP_CMD_RESPONSE (exit code $ACCEPT_ICMP_CMD_EXITCODE)"

	# Send the catch-all DROP rule payload (must be after ACCEPT)
	DROP_ALL_CMD="echo \"$SLIRP_PID $SLIRP4NETNS_FW_GROUP_ID $SLIRP4NETNS_HOST_IPV4 DROP_ALL\" | nc -U \"$SLIRP4NETNS_FW_SOCKET_PATH\""
	# sg program expects the second position parameter to be one single entity - therefore enclose command string variable in quotes
	DROP_ALL_CMD_RESPONSE=$(sg "$SLIRP4NETNS_FW_GROUP_NAME" "$DROP_ALL_CMD")
	DROP_ALL_CMD_EXITCODE=$?	
	log_msg "DROP Rule Submission Result: $DROP_ALL_CMD_RESPONSE (exit code $ACCEPT_CMD_EXITCODE)"

	if [[ "$ACCEPT_CMD_EXITCODE" -eq 0 && "$DROP_ALL_CMD_EXITCODE" -eq 0 ]]; then
		log_msg "Firewall constraints successfully deployed for PID $SLIRP_PID GID $SLIRP4NETNS_FW_GROUP_ID."
	else
		log_msg "CRITICAL: One or more firewall rules failed to apply. Check system logs."
		exit 1
	fi

	log_msg "=== FINISHED: Setup Bridge Network For unshare Namespace ==="
}

wait_for_ready_signal() {
	log_msg "=== Wait To Connect To unshare Namespace ==="
	log_msg "Waiting for file to appear at: $INSIDE_NS_ENV_READY_FILE_PATH"
	CHECK_INTERVAL=2
	TIMEOUT_LIMIT=120 # Maximum seconds to wait
	SECONDS_WAITED=0

	# Loop until the file exists
	until [ -f "$INSIDE_NS_ENV_READY_FILE_PATH" ]; do
		if [ "$SECONDS_WAITED" -ge "$TIMEOUT_LIMIT" ]; then
			log_msg "Error: Timed out waiting for file." >&2
			exit 1
		fi
		
		sleep "$CHECK_INTERVAL"
		SECONDS_WAITED=$((SECONDS_WAITED + CHECK_INTERVAL))
		log_msg "Seconds waited: $SECONDS_WAITED"
	done

	log_msg "Success: $INSIDE_NS_ENV_READY_FILE_PATH file found! Proceeding with the rest of the script..."
	rm $INSIDE_NS_ENV_READY_FILE_PATH
	log_msg "=== FINISHED: Wait To Connect To unshare Namespace ==="
}


setup_parent_child_communication
start_unshare
verify_parent_child_communication
setup_bridge_network
wait_for_ready_signal

# NOTE: Need the Nix store path of "@startShellScriptShellWrapper_nixStorePath@/bin/@startShellScriptFileName@" bind mounted within container
# NOTE: nsenter starting bash process inherits a direct copy of host shell environment variables
# NOTE: exporting SLIRP4NETNS_PORT to pass it through nsenter to the called script
export SLIRP4NETNS_HOST_PORT_1
nsenter \
	--keep-caps \
	--user \
	--cgroup \
	--ipc \
	--mount \
	--net \
	--pid \
	--time \
	--uts \
	--wdns="/workspace" \
	--target $UNSHARE_CHILD_PID \
	bash \
		"@startShellScriptShellWrapper_nixStorePath@/bin/@startShellScriptFileName@" \
		--mode $MODE 