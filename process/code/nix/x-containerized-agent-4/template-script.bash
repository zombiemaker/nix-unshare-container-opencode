#!/usr/bin/env bash

# This script creates level 1 Linux user namespace for running AI agent harness like OpenCode
# This script configures the level 1 Linux user namespace to support a level 2 Linux user namespace
# for daemonless Linux container programs like Buildah to create container images.
# Level 0 user namespace = namespace of host machine
# Level 1 user namespace = namespace for AI agent harness programs like OpenCode
# Level 2 user namespace = namespace for programs like Buildah

script_name=$(basename "$0")
echo "Running script: $script_name"


# Check if a custom marker variable is set. If not, re-run under unshare.
if [ -z "$IN_NAMESPACE" ]; then
	echo "Not in new namespace"
	echo "User outside namespace: $(whoami)"
	echo "PID outside namespace: $$"
	echo "Creating new namespace and re-executing script"
	export IN_NAMESPACE=1

	# --cgroup, -C creates new cgroup namespace
	# --ipc, -i creates new ipc namespace
	# --mount, -m creates new mount namespace
	# --net, -n creates new network namespace
	# --pid, -p creates new process PID namespace (forks process?)
	# --time, -T creates new time namespace
	# --user, -U creates new user ID / group ID namespace
	# --uts creates new uts namespace
	# --map-root-user, -r maps current user uid and gid to root inside namespace
	# --map-users <level 1 namespace uid>:<level 0 namespace uid>:<number of uids>
	# --map-groups <level 1 namespace gid>:<level 0 namespace gid>:<number of gids>
	# --clear-env do not pass the environment variables of the calling process to the unshared process.
	exec unshare \
		--user \
		--pid \
		--ipc \
		--mount \
		--time \
		--uts \
		--fork \
		--map-users 0:100000:65536 \
		--map-groups 0:100000:65536 \
		--map-root-user \
		"$0" "$@"
fi

# --- Everything below this line runs INSIDE the new user namespace ---
echo "User inside namespace: $(whoami)"
echo "PID inside namespace: $$"
echo "Granted full set of of all root capabilities including CAP_SYS_ADMIN"      

set -eo pipefail

# Default script variable values
DEBUG=false
MODE="server"
RANDOM_HOME_HOST_NAME=false
HOST_TEMP_PATH="./.temp"
CONTAINER_MOUNT_HOST_PATH="$HOST_TEMP_PATH/container-mount"
CONTAINER_FS_HOST_PATH="$HOST_TEMP_PATH/container-fs"
CONTAINER_BIN_HOST_PATH="$CONTAINER_FS_HOST_PATH/bin"
CONTAINER_ETC_HOST_PATH="$CONTAINER_FS_HOST_PATH/etc"
CONTAINER_HOME_HOST_PATH="$CONTAINER_FS_HOST_PATH/home"
CONTAINER_TEMP_HOST_PATH="$CONTAINER_FS_HOST_PATH/tmp"
CONTAINER_BUILDAH_HOST_PATH="$CONTAINER_FS_HOST_PATH/buildah"
CONTAINER_BUILDAH_RUNROOT_HOST_PATH="$CONTAINER_BUILDAH_HOST_PATH/runroot"
CONTAINER_BUILDAH_GRAPHROOT_HOST_PATH="$CONTAINER_BUILDAH_HOST_PATH/graphroot"
CONTAINER_BUILDAH_IMAGESTORE_HOST_PATH="$CONTAINER_BUILDAH_HOST_PATH/imagestore"
CONTAINER_WORKSPACE_HOST_PATH="$CONTAINER_FS_HOST_PATH/workspace"
CONTAINER_WORKSPACE_BUILDS_HOST_PATH="./.builds"
CONTAINER_WORKSPACE_DOWNLOADS_HOST_PATH="./.downloads"
CONTAINER_WORKSPACE_EXTERNAL_HOST_PATH="./external"
CONTAINER_WORKSPACE_GIT_HOST_PATH="./.gitt"
CONTAINER_WORKSPACE_OPENCODE_HOST_PATH="./.opencode"
CONTAINER_WORKSPACE_PROCESS_HOST_PATH="./process"
CONTAINER_WORKSPACE_PRODUCT_HOST_PATH="./product"
CONTAINER_USER_NAME="app-runner"
CONTAINER_USER_HOME_HOST_PATH="$CONTAINER_HOME_HOST_PATH/$CONTAINER_USER_NAME"
CONTAINER_USER_UID=$(id -u)
CONTAINER_USER_GID=$(id -g)
CONTAINER_PATH="@agentToolsBinPaths@:/bin"
CONTAINER_PS1="\[\e[0;36m\][🤖 container]\[\e[38;5;200m\]\w\n\[\e[0;33m\]\$ "

# Make temp directories on host
mkdir -p $HOST_TEMP_PATH
mkdir -p $CONTAINER_MOUNT_HOST_PATH
mkdir -p $CONTAINER_FS_HOST_PATH
mkdir -p $CONTAINER_BIN_HOST_PATH
mkdir -p $CONTAINER_ETC_HOST_PATH
mkdir -p $CONTAINER_HOME_HOST_PATH
mkdir -p $CONTAINER_TEMP_HOST_PATH
mkdir -p $CONTAINER_BUILDAH_RUNROOT_HOST_PATH
mkdir -p $CONTAINER_BUILDAH_GRAPHROOT_HOST_PATH
mkdir -p $CONTAINER_BUILDAH_IMAGESTORE_HOST_PATH
mkdir -p $CONTAINER_USER_HOME_HOST_PATH
mkdir -p $CONTAINER_WORKSPACE_HOST_PATH
mkdir -p $CONTAINER_WORKSPACE_BUILDS_HOST_PATH
mkdir -p $CONTAINER_WORKSPACE_DOWNLOADS_HOST_PATH
mkdir -p $CONTAINER_WORKSPACE_EXTERNAL_HOST_PATH
mkdir -p $CONTAINER_WORKSPACE_OPENCODE_HOST_PATH
mkdir -p $CONTAINER_WORKSPACE_PROCESS_HOST_PATH
mkdir -p $CONTAINER_WORKSPACE_PRODUCT_HOST_PATH


# Evaluate the list and bake a standard space-separated Bash array definition right here
mapfile -t NIX_STORE_PATHS < "@agentClosureLinuxNixOs@/store-paths"


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
    --random-home-name)
		RANDOM_HOME_HOST_NAME=true
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


# -------------------------------------------------------------------------
# --- BUBBLEWRAP-LIKE FILESYSTEM ISOLATION ---
# -------------------------------------------------------------------------
# Inside the namespace, we are root and have CAP_SYS_ADMIN.

# Setting enironment variables
PATH="$CONTAINER_PATH"      

# Force all inherited host mounts to be private inside this namespace so
# changes do not attempt to propagate back to the host.
mount --make-rprivate /

# Create a clean, blank slate for our new root filesystem
export SANDBOX_ROOT=$(realpath $CONTAINER_MOUNT_HOST_PATH)

echo "=== Preparing Sandbox Root at $SANDBOX_ROOT ==="

# Ensure the base sandbox root exists and is turned into a mount point (required for pivot_root)
# NOTE: must use absolute path for the value for SANDBOX_ROOT otherwise pivot_root will have issues
mount -t tmpfs -o exec,mode=0755 tmpfs "$SANDBOX_ROOT"
mount --make-private "$SANDBOX_ROOT"
mkdir -p "$SANDBOX_ROOT"/{dev,proc,sys,bin,buildah,etc,home,nix,run,tmp,usr/bin,workspace}
mkdir -p "$SANDBOX_ROOT/workspace"/{.git,.opencode,builds,downloads,external,process,product}


echo "=== Bind Mount Nix Store Paths ==="
for source_path in "${NIX_STORE_PATHS[@]}"; do
# Skip if the source path resolution failed or is empty
if [ -z "$source_path" ]; then continue; fi

# Ensure the source actually exists on the host
if [ ! -e "$source_path" ]; then
    echo "⚠️ Warning: Source path '$source_path' does not exist. Skipping." >&2
    continue
fi

# Mirror the exact path structure relative to the sandbox root
# Example: /nix/store/.../bin/bash becomes $SANDBOX_ROOT/nix/store/.../bin/bash
dest_path="${SANDBOX_ROOT}${source_path}"

if [ -d "$source_path" ]; then
    # Case A: Source is a directory
    echo "📁 Directory: $source_path -> $dest_path"
    mkdir -p "$dest_path"
    mount --bind "$source_path" "$dest_path"

elif [ -f "$source_path" ] || [ -L "$source_path" ]; then
    # Case B: Source is a file or a symlink to a file
    echo "📄 File:      $source_path -> $dest_path"
    # Ensure parent directory exists first
    mkdir -p "$(dirname "$dest_path")"
    # Create the empty target file skeleton
    touch "$dest_path"
    mount --bind "$source_path" "$dest_path"
fi
done
echo "=== FINISHED: Bind Mount Nix Store Paths ==="


echo "=== Linking GNU Bash & Env ==="
ln -s "@bashInteractive_nixStorePath@/bin/bash" "$SANDBOX_ROOT/bin/bash"
ln -s "@bashInteractive_nixStorePath@/bin/bash" "$SANDBOX_ROOT/bin/sh"
ln -s "@coreutils_nixStorePath@/bin/env"        "$SANDBOX_ROOT/bin/env"
ln -s "@coreutils_nixStorePath@/bin/env"        "$SANDBOX_ROOT/usr/bin/env"
echo "=== FINISHED: Linking GNU Bash & Env ==="


echo "=== Bind Mount For /dev ==="
mount -t tmpfs -o mode=0755 tmpfs "$SANDBOX_ROOT/dev"
touch \
    "$SANDBOX_ROOT/dev/full" \
	"$SANDBOX_ROOT/dev/null" \
    "$SANDBOX_ROOT/dev/random" \
    "$SANDBOX_ROOT/dev/tty" \
    "$SANDBOX_ROOT/dev/urandom" \
    "$SANDBOX_ROOT/dev/zero"

# /proc/self/fd is not a standard directory; it is a dynamic, magical gateway managed by the procfs kernel driver
# "ln -s" will reference the "/proc" path within the unshare namespace not the host namespace
ln -s /proc/self/fd      "$SANDBOX_ROOT/dev/fd"
ln -s /proc/self/fd/0    "$SANDBOX_ROOT/dev/stdin"
ln -s /proc/self/fd/1    "$SANDBOX_ROOT/dev/stdout"
ln -s /proc/self/fd/2    "$SANDBOX_ROOT/dev/stderr"

mount --bind /dev/full    		"$SANDBOX_ROOT/dev/full"
mount --bind /dev/null 			"$SANDBOX_ROOT/dev/null"
mount --bind /dev/random  		"$SANDBOX_ROOT/dev/random"
mount --bind /dev/tty     		"$SANDBOX_ROOT/dev/tty"
mount --bind /dev/urandom 		"$SANDBOX_ROOT/dev/urandom"
mount --bind /dev/zero    		"$SANDBOX_ROOT/dev/zero"

mkdir -p "$SANDBOX_ROOT/dev/pts"
mount -t devpts -o newinstance,ptmxmode=0666,mode=0620 devpts "$SANDBOX_ROOT/dev/pts"
rm -f "$SANDBOX_ROOT/dev/ptmx"
ln -s pts/ptmx "$SANDBOX_ROOT/dev/ptmx"
echo "=== FINISHED: Bind Mount For /dev ==="


echo "=== Bind Mount For General System ==="
mount -t tmpfs sys "$SANDBOX_ROOT/sys"
mkdir -p "$SANDBOX_ROOT/sys/devices/system/cpu"
touch "$SANDBOX_ROOT/sys/devices/system/cpu/online"
echo "0-15" > "$SANDBOX_ROOT/sys/devices/system/cpu/online"

touch "$SANDBOX_ROOT/etc/resolv.conf"
mount --bind /etc/resolv.conf "$SANDBOX_ROOT/etc/resolv.conf"

mkdir -p "$SANDBOX_ROOT/etc/ssl/certs"
mount --bind "@cacert_nixStorePath@/etc/ssl/certs" "$SANDBOX_ROOT/etc/ssl/certs"

mount --bind $CONTAINER_BIN_HOST_PATH "$SANDBOX_ROOT/bin"
mount --bind $CONTAINER_ETC_HOST_PATH "$SANDBOX_ROOT/etc"
mount --bind $CONTAINER_HOME_HOST_PATH "$SANDBOX_ROOT/home"
# mount --bind -o exec $CONTAINER_TEMP_HOST_PATH "$SANDBOX_ROOT/tmp"
mount -t tmpfs -o exec,mode=1777 tmpfs "$SANDBOX_ROOT/tmp"

# Replicate the minimal /run path OpenCode searches for on NixOS
mkdir -p "$SANDBOX_ROOT/run/current-system/sw/bin"
ln -s "@bashInteractive_nixStorePath@/bin/bash" "$SANDBOX_ROOT/run/current-system/sw/bin/bash"

# Bind standard NixOS library fallbacks if present
if [ -d /lib64 ]; then
  mkdir -p "$SANDBOX_ROOT/lib64"
  mount --bind /lib64 "$SANDBOX_ROOT/lib64"
  mount -o remount,ro,bind "$SANDBOX_ROOT/lib64"
fi
echo "=== FINISHED: Bind Mount For General System ==="


echo "=== Bind Mount For Fuse OverlayFS ==="
touch "$SANDBOX_ROOT/dev/fuse"
mount --bind /dev/fuse "$SANDBOX_ROOT/dev/fuse"
touch "$SANDBOX_ROOT/usr/bin/fuse-overlayfs"
mount --bind -o exec "@fuse_overlayfs_nixStorePath@/bin/fuse-overlayfs" "$SANDBOX_ROOT/usr/bin/fuse-overlayfs"
echo "=== FINISHED: Bind Mount For Fuse OverlayFS ==="


echo "=== Bind Mount For Buildah ==="
mount --bind $CONTAINER_BUILDAH_HOST_PATH "$SANDBOX_ROOT/buildah"
echo "=== FINISHED: Bind Mount For Buildah ==="


echo "=== Bind Mount For Workspace ==="
mount --bind $CONTAINER_WORKSPACE_BUILDS_HOST_PATH "$SANDBOX_ROOT/workspace/builds"
mount --bind $CONTAINER_WORKSPACE_DOWNLOADS_HOST_PATH "$SANDBOX_ROOT/workspace/downloads"
mount --bind $CONTAINER_WORKSPACE_EXTERNAL_HOST_PATH "$SANDBOX_ROOT/workspace/external"
mount --bind $CONTAINER_WORKSPACE_GIT_HOST_PATH "$SANDBOX_ROOT/workspace/.git"
mount --bind $CONTAINER_WORKSPACE_OPENCODE_HOST_PATH "$SANDBOX_ROOT/workspace/.opencode"
mount --bind $CONTAINER_WORKSPACE_PROCESS_HOST_PATH "$SANDBOX_ROOT/workspace/process"
mount --bind $CONTAINER_WORKSPACE_PRODUCT_HOST_PATH "$SANDBOX_ROOT/workspace/product"
echo "=== FINISHED: Bind Mount For Workspace ==="


echo "=== Create Configuration Files ==="
# Container /etc/passwd and /etc/group      
cat <<EOF > "$CONTAINER_ETC_HOST_PATH/passwd"
root:x:0:0:root:/root:/bin/bash
$CONTAINER_USER_NAME:x:$CONTAINER_USER_UID:$CONTAINER_USER_GID:$CONTAINER_USER_NAME:/home/$CONTAINER_USER_NAME:/bin/bash
EOF

cat <<EOF > "$CONTAINER_ETC_HOST_PATH/group"
root:x:0:
$CONTAINER_USER_NAME:x:$CONTAINER_USER_GID:
EOF


# Container /etc/subuid and /etc/subgid
cat <<EOF > "$CONTAINER_ETC_HOST_PATH/subuid"
# This defines UID allocation for level 2 namespace from the perspective of level 1 namespace
# Level 0 namespace = host machine namespace
# Level 1 namespace = unshare namespace
# Level 2 namespace = buildah container namespace
root:1000:10000
EOF

cat <<EOF >  "$CONTAINER_ETC_HOST_PATH/subgid"
# This defines GID allocation for level 2 namespace from the perspective of level 1 namespace
# Level 0 namespace = host machine namespace
# Level 1 namespace = unshare namespace
# Level 2 namespace = buildah container namespace
root:1000:10000
EOF


# Container /etc/containers
mkdir -p "$CONTAINER_ETC_HOST_PATH/containers"

# /etc/containers/containers.conf
cat <<EOF > "$CONTAINER_ETC_HOST_PATH/containers/containers.conf"
[engine]
# Explicitly forces chroot behavior at the engine layer
isolation = "chroot"

# Strips the engine from trying to escalate or alter supplemental group privileges
infra_command = ""
EOF


# /etc/containers/storage.conf
# Create a local storage.conf to force Buildah to use the VFS driver
# (Standard overlayfs requires kernel mounts that bwrap blocks by default)
cat <<EOF > "$CONTAINER_ETC_HOST_PATH/containers/storage.conf"
[storage]
driver = "overlay"

# Temporary/Runtime State Directory      
runroot = "/buildah/runroot"

# Permanent Image & Layer Storage Directory
graphroot = "/buildah/graphroot"

# (Optional) Separate Image Cache vs. Container Layer content
imagestore = "/buildah/imagestore" 

[storage.options.overlay]
mount_program = "/usr/bin/fuse-overlayfs"
EOF


# /etc/containers/registries.conf
cat <<EOF > "$CONTAINER_ETC_HOST_PATH/containers/registries.conf"
# /etc/containers/registries.conf
# This is the system-wide configuration file for container image registries 
# used by Buildah, Podman, and Skopeo.

# Note: If $HOME/.config/containers/registries.conf exists, it will completely 
# override this file for that specific user.

# Unqualified-search registries are used when you attempt to pull or build 
# from an image name that does not explicitly include a domain (e.g., "ubuntu" instead of "docker.io/library/ubuntu").
unqualified-search-registries = [
    "docker.io"
]

# Control what happens when an ambiguous short name is used.
# "enforcing" - Prompts the user to choose or relies strictly on secure aliases.
# "permissive" - Falls back to trying the unqualified-search-registries sequentially.
short-name-mode = "permissive"


# ==============================================================================
# INDIVIDUAL REGISTRY CONFIGURATIONS
# ==============================================================================

# Example 1: Standard Registry with an optional local mirror
[[registry]]
location = "docker.io"

# Optional: Add a local pull-through cache or mirror if you have one.
# [[registry.mirror]]
# location = "mirror.local.internal"

# Example 2: Allowing an insecure local registry (HTTP or self-signed certs)
# Useful for local development and testing with Buildah.
[[registry]]
location = "localhost:5000"
insecure = true

# Example 3: Blocking a specific registry entirely
# [[registry]]
# location = "bad-registry.internal"
# blocked = true
EOF


# /etc/containers/policy.json
cat <<EOF > "$CONTAINER_ETC_HOST_PATH/containers/policy.json"
{
"default": [
    {
    "type": "insecureAcceptAnything"
    }
],
"transports": {
    "docker": {
        "://redhat.com": [
            {
                "type": "signedBy",
                "keyType": "GPGKeys",
                "keyPath": "/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release"
            }
        ],
        "registry.redhat.io": [
            {
                "type": "signedBy",
                "keyType": "GPGKeys",
                "keyPath": "/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release"
            }
        ],
        "registry.fedoraproject.org": [
            {
                "type": "signedBy",
                "keyType": "GPGKeys",
                "keyPath": "/etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-39-primary"
            }
        ]
    },
    "docker-daemon": {
        "": [
            {
                "type": "insecureAcceptAnything"
            }
        ]
    }
}
}
EOF

mkdir -p "$CONTAINER_USER_HOME_HOST_PATH/.config/opencode"
cat <<EOF > "$CONTAINER_USER_HOME_HOST_PATH/.config/opencode/opencode.json"
{
  "$schema": "https://opencode.ai/config.json",
  "disableBuiltInProviders": true,
  "provider": {
    "strata": {
      "name": "strata",
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "baseURL": "http://192.168.1.90:9943/v1"
      },
      "models": {
        "qwen3.8-flash-next-iq3_s": {
          "name": "qwen3.8-flash-next-iq3_s"
        }
      }
    },
	"ollama-ejn": {
      "name": "ollama-ejn",
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "baseURL": "http://192.168.1.108:11434"
      },
      "models": {
        "qwen2.5-coder:7b": {
          "name": "qwen2.5-coder:7b"
        }
      }
    }
  },
  "model": "strata/qwen3.8-flash-next-iq3_s"
}
EOF


echo "=== FINISHED: Create Configuration Files ==="


echo "=== Switch Root Directory ==="
# Trick to to completely vanish old root without even needing a temporary directory
cd "$SANDBOX_ROOT"

# Pivot root directly onto itself. This puts the NEW root at / and the OLD root at / (overlapped)
mkdir -p "$SANDBOX_ROOT/old_root"
pivot_root . old_root

# Re-mount your essential kernel filesystems inside the new root
mount -t proc proc /proc

# Lazily unmount the old root (which is pinned underneath '.')
umount -l old_root
rmdir old_root
echo "=== FINISHED: Switch Root Directory ==="

# Move into the new root 
cd /workspace

# Define the validation function
check_executables() {
    # Capture all passed arguments into a local list
    local targets=("$@")

	# If no arguments were passed, print a warning and exit the function
    if [ ${#targets[@]} -eq 0 ]; then
        echo "⚠️ No executables provided to check."
        return 1
    fi

    # Loop through each item in the passed list
    for EXE in "${targets[@]}"; do
        # Check if the command exists and is executable in the current PATH
        if ! type "$EXE" &> /dev/null; then
            echo "❌ $EXE (Not found in PATH)"
            continue
        fi

        # Pass --version to prevent interactive hangs or instant dynamic-linker aborts
        "$EXE" --version &> /dev/null

        # Check the runtime exit status
        if [ $? -eq 0 ]; then
            echo "✅ $EXE"
        else
            echo "❌ $EXE (Failed execution)"
        fi
    done
}

# Define the list of executables to check
EXECUTABLES_TO_VERIFY=(
	"curl"
	"wget"
	"buildah"
	"git"
)


# --- START APPLICATION ---

if [[ "$MODE" == "server" ]]; then
	echo "🚀 Launching application"
	echo "📦 Starting Bubblewrap container"
	opencode serve

elif [[ "$MODE" == "shell" ]]; then
	echo "🚀 Launching shell"
	echo "📦 Starting Bubblewrap container"

	check_executables "${EXECUTABLES_TO_VERIFY[@]}"

	echo "💻 Starting Shell With Cleared Environment Variables"
	exec env -i \
	    PATH="$CONTAINER_PATH" \
	    PS1="$CONTAINER_PS1" \
	    HOME="/home/$CONTAINER_USER_NAME" \
	    USER="$CONTAINER_USER_NAME" \
	    TEMP="/tmp" \
		TEMPDIR="/tmp" \
		TERM="$TERM" \
		TMP="/tmp" \
		TMPDIR="/tmp" \
		bash --noprofile --norc
	bash --noprofile --norc

else
	echo "Unexpected MODE '$MODE'"
fi