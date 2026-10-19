#!/usr/bin/env bash

script_name=$(basename "$0")
echo "Running script: $script_name"

# Check if a custom marker variable is set. If not, re-run under unshare.
if [ -z "$IN_NAMESPACE" ]; then
    echo "Not in unshare namespace"
    echo "User outside namespace: $(whoami)"
    echo "PID outside namespace: $$"

    export IN_NAMESPACE=1
    # -U creates the user namespace, -r maps current user to root inside it
    exec unshare -Ur "$0" "$@"
fi

# --- Everything below this line runs INSIDE the new user namespace ---
echo "User inside namespace: $(whoami)"
echo "PID inside namespace: $$"
