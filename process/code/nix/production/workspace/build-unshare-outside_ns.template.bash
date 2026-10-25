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
echo "*************************************************************************"

UNSHARE_LOG_FILE_NAME="$TMP/build-inside_ns-$SRANDOM.log"
echo "$NAMESPACE: UNSHARE_LOG_FILE_NAME: $UNSHARE_LOG_FILE_NAME"

# Handle Script Arguments
DEBUG=false
MODE="shell"
BUILD_INSIDE_NS_ENV_SCRIPT_PATH=""
INSIDE_NS_ENV_READY_FILE_PATH="$TMP/$SRANDOM"
OTHER_ARGS=()
SLIRP4NETNS_PORT_FORWARD_HOST_ADDRESS="0.0.0.0"
SLIRP4NETNS_PORT_FORWARD_HOST_PORT="9000"
SLIRP4NETNS_PORT_FORWARD_GUEST_PORT="9000"

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

cleanup() {
    echo "Orchestrator exiting. Cleaning up background tasks..."
    [[ -n "$UNSHARE_CHILD_PID" ]] && kill -9 "$UNSHARE_CHILD_PID" 2>/dev/null
    [[ -n "$SLIRP_PID" ]] && kill -9 "$SLIRP_PID" 2>/dev/null

	# Clean up parent FDs
	exec 3>&-
	exec 4>&-
}

setup_parent_child_communication() {
	echo "=== Setup 2-Way Anonymous Pipes ==="
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
	echo "=== FINISHED: Setup 2-Way Anonymous Pipes ==="
}

start_unshare() {
	echo "=== Start Background unshare Namespace Environment ==="
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
	echo "Host PID for unshare parent process $UNSHARE_PARENT_PID"

	# Give unshare process time to setup
	sleep 1

	# Use the forked unshare child process PID not the parent unshare wrapper process PID
	UNSHARE_CHILD_PID=$(pgrep -P $UNSHARE_PARENT_PID -o)
	echo "Host PID for unshare forked child process $UNSHARE_CHILD_PID"

	# Clean up the background sleep process when this orchestrator exits
	# NOTE: need kill -9 to kill sleep infinity
	trap cleanup EXIT
	echo "=== FINISHED: Start Background unshare Namespace Environment ==="
}

verify_parent_child_communication() {
	echo "=== Verify 2-Way Anonymous Pipe Communication ==="
	# Parent communicates through the established FDs
	echo "[Parent] Sending verification message to child"
	echo "Hello child, can you hear me?" >&3

	# Read the reply from the child
	read -u 4 REPLY
	echo "[Parent] Received from child: $REPLY"
	echo "=== FINISHED: Verify 2-Way Anonymous Pipe Communication ==="
}

setup_bridge_network() {
	echo "=== Setup Bridge Network For unshare Namespace ==="
	# Attach slirp4netns from outside the namespace to connect it to the internet
	# --port-forward=hostPort:guestPort
	slirp4netns --version
	slirp4netns \
		--api-socket="$TMP/slirp4netns.sock" \
		--configure \
		--mtu=65520 \
		--disable-host-loopback \
		--outbound-addr="$SLIRP4NETNS_PORT_FORWARD_HOST_ADDRESS" \
		$UNSHARE_CHILD_PID tap0 &
	SLIRP_PID=$!
	# Wait briefly for the socket to initialize, then send the port-forwarding rule
	sleep 1
	read -r -d '' JSON_COMMAND << JSON
{
	"execute": "add_hostfwd",
	"arguments": {
		"proto": "tcp",
		"host_addr": "$SLIRP4NETNS_PORT_FORWARD_HOST_ADDRESS",
		"host_port": $SLIRP4NETNS_PORT_FORWARD_HOST_PORT,
		"guest_port": $SLIRP4NETNS_PORT_FORWARD_GUEST_PORT
	}
}
JSON
	# Format: add_hostfwd:proto:host_addr:host_port:guest_addr:guest_port
	#echo "'{\"execute\": \"add_hostfwd\", \"arguments\": {\"proto\": \"tcp\", \"host_addr\": \""$SLIRP4NETNS_PORT_FORWARD_HOST_ADDRESS"\", \"host_port\": \""$SLIRP4NETNS_PORT_FORWARD_HOST_PORT"\", \"guest_port\": \""$SLIRP4NETNS_PORT_FORWARD_GUEST_PORT"\"}}'" | nc -U "$TMP/slirp4netns.sock"
	echo "$JSON_COMMAND" | nc -U "$TMP/slirp4netns.sock"
	echo "=== FINISHED: Setup Bridge Network For unshare Namespace ==="
}

wait_for_ready_signal() {
	echo "=== Wait To Connect To unshare Namespace ==="
	echo "Waiting for file to appear at: $INSIDE_NS_ENV_READY_FILE_PATH"
	CHECK_INTERVAL=2
	TIMEOUT_LIMIT=120 # Maximum seconds to wait
	SECONDS_WAITED=0

	# Loop until the file exists
	until [ -f "$INSIDE_NS_ENV_READY_FILE_PATH" ]; do
		if [ "$SECONDS_WAITED" -ge "$TIMEOUT_LIMIT" ]; then
			echo "Error: Timed out waiting for file." >&2
			exit 1
		fi
		
		sleep "$CHECK_INTERVAL"
		SECONDS_WAITED=$((SECONDS_WAITED + CHECK_INTERVAL))
		echo "Seconds waited: $SECONDS_WAITED"
	done

	echo "Success: $INSIDE_NS_ENV_READY_FILE_PATH file found! Proceeding with the rest of the script..."
	rm $INSIDE_NS_ENV_READY_FILE_PATH
	echo "=== FINISHED: Wait To Connect To unshare Namespace ==="
}


setup_parent_child_communication
start_unshare
verify_parent_child_communication
setup_bridge_network
wait_for_ready_signal

# NOTE: Need the Nix store path of "@startShellScriptShellWrapper_nixStorePath@/bin/@startShellScriptFileName@" bind mounted within container
# NOTE: nsenter starting bash process inherits a direct copy of host shell environment variables
# NOTE: exporting TERM to pass it through nsenter to the called script
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