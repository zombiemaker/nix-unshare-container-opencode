#!/usr/bin/env bash
# Iteration 0.3 goal: Implement firewall rules and restrict container user from changing network configuration
# Iteration 0.2 goal (done): separate out Bash script that sets up inside namespace environment

# Processes:
# - main process
#	- bash
#	- invoke slirp4netns as background Bash job
#		- creates Bash job
#		- forks child process (main.child_1)
#		- configures stdout and stderr for child process
#		- detachess parent stdin from child stdin
#		- adds PID and status to parent process Bash job table
#	- continues execution after starting background job
#	- (main_option_1) invoke unshare as foreground with Bash exec
#	- (main_option_2) invoke unshare as foreground
#	- (main_option_3) invoke unshare as background Bash job
# - main.child_1 process
#	- executes execve() to run slirp4netns
# - main_option_1: invoke unshare using Bash exec
#	- invokes unshare in foreground with execve() process image replacement 
#	- forks child process (main_option_1.child_1)
# - main_option_1.child_1 process: running unshare with --pid and --fork options
#	- creates namespaces
#	- forks child process (main_option_1.child_1.child_1)
# - main_option_1.child_1.child_1 process: running unshare-in-namespace-command paramter
#	- executes execve() to run unshare-in-namespace-command (e.g., Bash script to build inside namespace environment)
# - main_option_2: invoke unshare as foreground
# - main_option_3: invoke unshare as background Bash job
# - Bash script to build inside namespace environment
# 	- execute handshake with slirp4netns
#	- configures tap0 network interface
#	- mounts new root file system
#	- mounts /nix/store directories
#	- mounts /sys, /dev, /proc, /tmp, /run, /home
#	- creates configuration directories and files for apps
#		- Buildah system and container user configuration
#		- Podman system and container user configuration
#		- OpenCode system, container user, and workspace configuration
#		- GNU Bash container user configuration
#		- PowerShell container user configuration
#	- configure netfilter firewall rules
#		- restrict destination IP/port
#	- pivot to new root file system
#	- drop Linux capabilities
#	- remove inherited environment variables
#	- set container user environment variables
set -euo pipefail

NAMESPACE="NS_0"
PID=$BASHPID
BASH_INSTANCE_NAME="outside_ns_main"
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

# network interface must match what is configured in /etc/nixos/configurations.nix
SLIRP4NETNS_HOST_NET_INTERFACE="slirp4netns_0"  # this is defined in /etc/nixos/configurations.nix

# Get first IP assigned to SLIRP4NETNS_HOST_NET_INTERFACE interface
if [ -n "$SLIRP4NETNS_HOST_NET_INTERFACE" ]; then
    SLIRP4NETNS_HOST_IPV4=$(ip -4 addr show $SLIRP4NETNS_HOST_NET_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
else
    log_msg "ERROR: No default network interface found." >&2
	exit 1
fi

log_msg "$NAMESPACE: SLIRP4NETNS_HOST_NET_INTERFACE: $SLIRP4NETNS_HOST_NET_INTERFACE"
log_msg "$NAMESPACE: SLIRP4NETNS_HOST_IPV4: $SLIRP4NETNS_HOST_IPV4"

# Random slirp4netns host forwarding port
SLIRP4NETNS_HOST_PORT_MIN=9500
SLIRP4NETNS_HOST_PORT_MAX=9999
SLIRP4NETNS_HOST_PORT_RANGE=$(( SLIRP4NETNS_HOST_PORT_MAX - SLIRP4NETNS_HOST_PORT_MIN + 1 ))

# Generate the random number for host port for port-forwarding
export SLIRP4NETNS_HOST_PORT_1=$(( (RANDOM % SLIRP4NETNS_HOST_PORT_RANGE) + SLIRP4NETNS_HOST_PORT_MIN ))
log_msg "SLIRP4NETNS_HOST_PORT_1 = $SLIRP4NETNS_HOST_PORT_1"
export SLIRP4NETNS_NS_PORT_1=$SLIRP4NETNS_HOST_PORT_1
log_msg "SLIRP4NETNS_NS_PORT_1 = $SLIRP4NETNS_NS_PORT_1"

# TODO: change from single to multiple ip:port
# export SLIRP4NETNS_FW_ALLOWED_DEST_1_IP="192.168.1.90"
# log_msg "SLIRP4NETNS_FW_ALLOWED_DEST_1_IP = $SLIRP4NETNS_FW_ALLOWED_DEST_1_IP"
# export SLIRP4NETNS_FW_ALLOWED_DEST_1_PORT="9943"
# log_msg "SLIRP4NETNS_FW_ALLOWED_DEST_1_PORT = $SLIRP4NETNS_FW_ALLOWED_DEST_1_PORT"
SLIRP4NETNS_LOG_FILE_NAME="$TMP/slirp4netns-$SRANDOM.log"
log_msg "SLIRP4NETNS_LOG_FILE_NAME: $SLIRP4NETNS_LOG_FILE_NAME"

# Create a unique named pipe on the host for synchronization handshake
# NOTE: export variable in order for child unshare process can access it as environment variable
export SLIRP4NETNS_UNSHARE_CHILD_PID_FIFO_PATH="/tmp/slirp4netns_pid_$$.fifo"
export SLIRP4NETNS_READY_FIFO_PATH="/tmp/slirp4netns_ready_$$.fifo"
mkfifo "$SLIRP4NETNS_UNSHARE_CHILD_PID_FIFO_PATH"
log_msg "SLIRP4NETNS_UNSHARE_CHILD_PID_FIFO_PATH: $SLIRP4NETNS_UNSHARE_CHILD_PID_FIFO_PATH"
mkfifo "$SLIRP4NETNS_READY_FIFO_PATH"
log_msg "SLIRP4NETNS_READY_FIFO_PATH: $SLIRP4NETNS_READY_FIFO_PATH"

# Create a unique named pipe on the host for sending-receiving slirp4netns api commands
export SLIRP4NETNS_API_SOCKET_PATH="/tmp/slirp4netns_api_$$.sock"
log_msg "SLIRP4NETNS_API_SOCKET_PATH: $SLIRP4NETNS_API_SOCKET_PATH"
log_msg "*************************************************************************"



# Ensure cleanup on host script exits
cleanup() {
    rm -f "$SLIRP4NETNS_UNSHARE_CHILD_PID_FIFO_PATH" "$SLIRP4NETNS_READY_FIFO_PATH" "$SLIRP4NETNS_API_SOCKET_PATH"
}
trap cleanup EXIT

log_msg "Preparing background supervisor loop..."

# Spawn a background monitoring loop on the host.
(
	# Since code invokes a non-Bash program (i.e. slirp4netns), the Bash interpreter defers forking until invoking non-Bash program
	# Therefore, the $BASHPID will have the value of the parent Bash shell not a new PID if assigned without executin a sub-shell
	# command before the assignement.  Either
	# - use ":" to force sub-shell command
	# - place assignment within if block of read statement, which blocks (thus already running in new fork process)
	:	# this forces an immediate process fork by executing a command, which then gets the expected value for PID
	PID=$BASHPID
	BASH_INSTANCE_NAME="outside_ns_slirp4netns"
	if read -r UNSHARE_CHILD_PID < "$SLIRP4NETNS_UNSHARE_CHILD_PID_FIFO_PATH"; then
        log_msg "Captured Namespace PID: $UNSHARE_CHILD_PID"
        
        # Start slirp4netns and redirect the ready token into the FIFO
		# Open FD 3 in a non-blocking way in order to capture stderr output to log file
		exec 3<> "$SLIRP4NETNS_READY_FIFO_PATH"

		# Clear stdout/stderr caching instantly to write slirp4netns initialization output to log file
		exec stdbuf -o0 -e0 slirp4netns \
			--configure \
			--mtu=65520 \
			--ready-fd=3 \
			--disable-host-loopback \
			--api-socket="$SLIRP4NETNS_API_SOCKET_PATH" \
			--outbound-addr="$SLIRP4NETNS_HOST_IPV4" \
			"$UNSHARE_CHILD_PID" \
			tap0 \
			> "$SLIRP4NETNS_LOG_FILE_NAME" 2>&1
    fi	
) &

SLIRP_PID=$!
log_msg "[Host] SLIRP_PID: $SLIRP_PID"
log_msg "[Host] Handing over current terminal session to unshare..."

BUILD_INSIDE_NS_SCRIPT_PATH="$(dirname "$(readlink -f "$0")")/method_2-v0.3-build-inside_ns-env.bash"

# Execute unshare in the FOREGROUND, replacing the host script process
# NOTE: using Bash foreground exec command invocation replaces current process image; therefore, "trap cleanup() EXIT" will not be invoked
# NOTE: using Bash foreground invocation, forks a process to run unshare in foreground, parent process blocks by entering sleep state (waidpid()) until child process terminates
# NOTE: using Bash background invocation, creates Bash job, forks a process to run unshare in background, parent process continues (usually executing wait command)
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
	"$BUILD_INSIDE_NS_SCRIPT_PATH"