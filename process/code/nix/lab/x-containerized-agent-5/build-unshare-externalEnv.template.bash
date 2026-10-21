#!/usr/bin/env bash

# --- Everything runs OUTSIDE the new unshare user namespace ---

# script_name=$(basename "$0")
script_name="$0"
echo "Running script: $script_name"
echo "Current working directory: $PWD"

# Handle Script Arguments
DEBUG=false
MODE="shell"
BUILD_INTERNAL_ENV_SCRIPT_PATH=""
INTERNAL_ENV_READY_FILE_PATH="/tmp/$SRANDOM"
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
			BUILD_INTERNAL_ENV_SCRIPT_PATH="$2"
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
if [[ -z "$BUILD_INTERNAL_ENV_SCRIPT_PATH" ]]; then
	echo "Error: --internal-env-script is required." >&2
	exit 1
fi

# Verify that the required start-shell-script parameter was provided
if [[ -z "$START_SHELL_SCRIPT_PATH" ]]; then
	echo "Error: --start-shell-script is required." >&2
	exit 1
fi


echo "User outside namespace: $(whoami)"
echo "PID outside namespace: $$"
echo "INTERNAL_ENV_READY_FILE_PATH = $INTERNAL_ENV_READY_FILE_PATH"


 echo "=== Initiate unshare Namespace Environment ==="
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
echo "📦 Starting unshare container"
unshare \
	--user \
	--pid \
	--ipc \
	--mount \
	--net \
	--time \
	--uts \
	--fork \
	--map-root-user \
	--map-users 0:100000:20000 \
	--map-groups 0:100000:20000 \
	stdbuf -oL -eL bash "$BUILD_INTERNAL_ENV_SCRIPT_PATH" \
		--ready-file-path "$INTERNAL_ENV_READY_FILE_PATH" \
		--start-shell-script "$START_SHELL_SCRIPT_PATH" \
		> "build-internalEnv-$SRANDOM.log" 2>&1 &

UNSHARE_PARENT_PID=$!
echo "Host PID for unshare parent process $UNSHARE_PARENT_PID"

# Give unshare process time to setup
sleep 1

# Use the forked unshare child process PID not the parent unshare wrapper process PID
UNSHARE_CHILD_PID=$(pgrep -P $UNSHARE_PARENT_PID -o)
echo "Host PID for unshare forked child process $UNSHARE_CHILD_PID"

# Clean up the background sleep process when this orchestrator exits
# NOTE: need kill -9 to kill sleep infinity
trap "kill -9 $UNSHARE_CHILD_PID 2>/dev/null" EXIT

# Attach slirp4netns from outside the namespace to connect it to the internet
slirp4netns --configure --mtu=65520 $UNSHARE_CHILD_PID tap0 &
SLIRP_PID=$!

# Clean up the background slirp4netns process when this orchestrator exits
trap "kill -9 $UNSHARE_CHILD_PID $SLIRP_PID 2>/dev/null" EXIT

echo "Waiting for file to appear at: $INTERNAL_ENV_READY_FILE_PATH"
CHECK_INTERVAL=2
TIMEOUT_LIMIT=120 # Maximum seconds to wait
SECONDS_WAITED=0

# Loop until the file exists
until [ -f "$INTERNAL_ENV_READY_FILE_PATH" ]; do
    if [ "$SECONDS_WAITED" -ge "$TIMEOUT_LIMIT" ]; then
        echo "Error: Timed out waiting for file." >&2
        exit 1
    fi
	
	sleep "$CHECK_INTERVAL"
	SECONDS_WAITED=$((SECONDS_WAITED + CHECK_INTERVAL))
	echo "Seconds waited: $SECONDS_WAITED"
done

echo "Success: $INTERNAL_ENV_READY_FILE_PATH file found! Proceeding with the rest of the script..."
rm $INTERNAL_ENV_READY_FILE_PATH


# NOTE: Need the Nix store path of "@startShellScriptShellWrapper_nixStorePath@/bin/@startShellScriptFileName@" bind mounted within container
# NOTE: nsenter starting bash process inherits a direct copy of host shell environment variables
# NOTE: exporting TERM to pass it through nsenter to the called script
export TERM="${TERM:-xterm-256color}"
nsenter \
	--keep-caps \
	--target $UNSHARE_CHILD_PID \
	--ipc \
	--mount \
	--net \
	--user \
	--uts \
	--wdns="/workspace" \
	bash "@startShellScriptShellWrapper_nixStorePath@/bin/@startShellScriptFileName@" --mode $MODE