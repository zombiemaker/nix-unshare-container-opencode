#!/usr/bin/env bash

# --- Everything runs INSIDE the new unshare user namespace ---

# This script creates level 1 Linux user namespace for running AI agent harness like OpenCode
# This script configures the level 1 Linux user namespace to support a level 2 Linux user namespace
# for daemonless Linux container programs like Buildah to create container images.
# Level 0 user namespace = namespace of host machine
# Level 1 user namespace = namespace for AI agent harness programs like OpenCode
# Level 2 user namespace = namespace for programs like Buildah
#
# Capabilities provided:
# - Run opencode CLI
# - Run buildah to create container images
# - Access files provided by NixOS Nix environment
#
# Capabilities not working:
# - Run podman to run container images
# - Access network

# script_name=$(basename "$0")
script_name="$0"
echo "Running script: $script_name"
echo "Current working directory: $PWD"

echo "User inside namespace: $(whoami)"
echo "PID inside namespace: $$"
echo "Granted full set of of all root capabilities including CAP_SYS_ADMIN" 

set -eo pipefail
echo "@agentToolsBinPaths@"
echo "@agentClosureLinuxNixOs@"
echo "@bashInteractive_nixStorePath@"
echo "@coreutils_nixStorePath@"
echo "@fuse_overlayfs_nixStorePath@"
echo "@cacert_nixStorePath@"
env -i \
	PATH="@agentToolsBinPaths@" \
	PS1="\[\e[0;36m\][🤖 container]\[\e[38;5;200m\]\w\n\[\e[0;33m\]\$ " \
	TERM="${TERM:-xterm-256color}" \
	bash --noprofile --norc
bash