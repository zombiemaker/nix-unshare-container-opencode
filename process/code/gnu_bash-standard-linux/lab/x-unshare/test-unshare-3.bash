#!/usr/bin/env bash

script_name=$(basename "$0")
echo "Running script: $script_name"

# Check if a custom marker variable is set. If not, re-run under unshare.
if [ -z "$IN_NAMESPACE" ]; then
    echo "Not in new namespace"
    echo "User outside namespace: $(whoami)"
    echo "PID outside namespace: $$"


    echo "Creating new namespace and re-executing script"
    export IN_NAMESPACE=1
    # --map-root-user, -r maps current user to root inside namespace
    # --cgroup, -C creates new cgroup namespace
    # --mount, -m creates new mount namespace
    # --net, -n creates new network namespace
    # --pid, -p creates new process PID namespace (forks process?)
    # --time, -T creates new time namespace
    # --user, -U creates new user ID / group ID namespace
    # --uts creates new uts namespace
    exec unshare \
        --user \
        --map-users 100000:100000:65536 \
        --map-groups 100000:100000:65536 \
        --map-root-user \
        --pid \
        --fork \
        "$0" "$@"
fi

# --- Everything below this line runs INSIDE the new user namespace ---
echo "User inside namespace: $(whoami)"
echo "PID inside namespace: $$"
echo "Granted full set of of all root capabilities including CAP_SYS_ADMIN"

# Verifying capabilities

if command -v capsh &> /dev/null; then
    capsh --print
else
    echo "libcap/capsh not installed, but capabilities are active."
fi
