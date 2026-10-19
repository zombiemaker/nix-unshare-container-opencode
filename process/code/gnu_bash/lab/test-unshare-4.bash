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
        --mount \
        --fork \
        "$0" "$@"
fi

# --- Everything below this line runs INSIDE the new user namespace ---
echo "User inside namespace: $(whoami)"
echo "PID inside namespace: $$"
echo "Granted full set of of all root capabilities including CAP_SYS_ADMIN"

# -------------------------------------------------------------------------
# --- BUBBLEWRAP-LIKE FILESYSTEM ISOLATION ---
# -------------------------------------------------------------------------
# Inside the namespace, we are root and have CAP_SYS_ADMIN.
# Let's turn off host mount propagation so our mounts are 100% private.
mount --make-rprivate /

# Create a clean, blank slate for our new root filesystem
export SANDBOX_ROOT=$(mktemp -d /tmp/sandbox.XXXXXX)
mount -t tmpfs none "$SANDBOX_ROOT"

# Create standard Linux directories inside the sandbox root
mkdir -p "$SANDBOX_ROOT"/{dev,proc,sys,bin,nix,tmp,etc}

# Mimic Bubblewrap's '--ro-bind' for critical NixOS paths
# (Crucial for NixOS: your applications must see /nix/store)
# mount --bind /nix "$SANDBOX_ROOT/nix"
# mount -o remount,ro,bind "$SANDBOX_ROOT/nix"
# mount --bind /bin "$SANDBOX_ROOT/bin"
#mount -o remount,ro,bind "$SANDBOX_ROOT/bin"

# # Provide safe, isolated kernel filesystems (like bwrap's --proc and --dev)
mount -t proc proc "$SANDBOX_ROOT/proc"
mount -t sysfs sysfs "$SANDBOX_ROOT/sys"
# mount -t devtmpfs devtmpfs "$SANDBOX_ROOT/dev"

# # Pivot into the new sandbox root
cd "$SANDBOX_ROOT"
mkdir old_root
pivot_root . old_root

# # Detach the old host root so the application can no longer see it at all
# umount -l /old_root
# rmdir /old_root

# -------------------------------------------------------------------------
# --- THE SANDBOX IS READY ---
# -------------------------------------------------------------------------
echo "Successfully sandboxed! I can only see a minimal environment."
echo "Listing / :"
ls -l /

# Execute an interactive shell or a specific app inside this Bubblewrap clone
exec /bin/sh