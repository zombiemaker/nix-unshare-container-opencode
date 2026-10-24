#!/usr/bin/env bash

NAMESPACE="Level 1 namespace (unshare)"
script_name="$0"
echo "*************************************************************************"
echo "$NAMESPACE: running script: $script_name"
echo "$NAMESPACE: purpose: to initalize nsenter session into namespace"
echo "$NAMESPACE: script arguments: $@"
echo "$NAMESPACE: current working directory: $PWD"
echo "$NAMESPACE: user name: $(whoami)"
echo "$NAMESPACE: PID: $$"
echo "$NAMESPACE: TMP: $TMP"
echo "*************************************************************************"

DEBUG=false
MODE="shell"

# Display usage helper
usage() {
cat <<EOF
	Usage: $(basename "$0") [OPTIONS]

	Options:
		--mode MODE            "server" (default) or "shell"
		--debug                Prints debug messages
		--help                 Display this help message
EOF
exit 0
}

# Parse named parameters
while [[ $# -gt 0 ]]; do
	case "$1" in
		--mode)
			MODE="${2,,}"
			shift 2
			;;
		--debug)
			DEBUG=true
			;;
		--help)
			usage
			;;
		*)
			echo "Error: Unknown argument '$1'" >&2
			echo "Use --help for usage details." >&2
			exit 1
			;;
	esac
done

# Fallback gracefully to xterm-256color if TERM is completely empty/unbound
REAL_TERM="${TERM:-xterm-256color}"

# Capture the actual pseudo-terminal dimensions from the active standard input
REAL_LINES=$(tput lines 2>/dev/null || echo 24)
REAL_COLUMNS=$(tput cols 2>/dev/null || echo 80)


# --- START APPLICATION ---
if [[ "$MODE" == "server" ]]; then
	echo "🚀 Launching application"
	echo "💻 Starting OpenCode"
	exec /usr/bin/env -i \
		TERM="$REAL_TERM" \
		LINES="$REAL_LINES" \
		COLUMNS="$REAL_COLUMNS" \
		bash \
		--rcfile /home/root/.bashrc \
		-c "opencode serve"

elif [[ "$MODE" == "shell" ]]; then
	echo "🚀 Launching shell"
	echo "💻 Starting Shell"
	exec /usr/bin/env -i \
		TERM="$REAL_TERM" \
		LINES="$REAL_LINES" \
		COLUMNS="$REAL_COLUMNS" \
		bash \
		--rcfile /home/root/.bashrc

else
	echo "Unexpected MODE '$MODE'"
fi