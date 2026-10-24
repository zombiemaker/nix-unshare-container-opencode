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


NAMESPACE="Level 1 namespace (unshare)"
script_name="$NAMESPACE: $0"
echo "$NAMESPACE: running script: $script_name"
echo "$NAMESPACE: script arguments: $@"
echo "$NAMESPACE: current working directory: $PWD"
echo "$NAMESPACE: user name: $(whoami)"
echo "$NAMESPACE: PID: $$"
echo "$NAMESPACE: granted full set of of all root capabilities including CAP_SYS_ADMIN" 

set -eo pipefail

echo "=== Verify 2-Way Anonymous Pipe Communication ==="
# Test pipe to parent
# Read from FD 3 (passed from parent)
read -u 3 MESSAGE
echo "[Child] Received from parent: $MESSAGE"

# Write back to FD 4 (passed to parent)
echo "Hello from inside the absolute quarantine!" >&4
echo "=== FINISHED: Verify 2-Way Anonymous Pipe Communication ==="


# Default script variable values
DEBUG=false
CONTAINER_USER_NAME="root"
CONTAINER_USER_UID=$(id -u)
CONTAINER_USER_GID=$(id -g)

HOST_PATH_WORKSPACE=$(realpath .)
HOST_PATH_WORKSPACE_TEMP="$HOST_PATH_WORKSPACE/.temp"
HOST_PATH_WORKSPACE_BUILDS="$HOST_PATH_WORKSPACE_TEMP/builds"
HOST_PATH_WORKSPACE_DOWNLOADS="$HOST_PATH_WORKSPACE_TEMP/downloads"
HOST_PATH_WORKSPACE_EXTERNAL="$HOST_PATH_WORKSPACE/external"
HOST_PATH_WORKSPACE_GIT="$HOST_PATH_WORKSPACE/.git"
HOST_PATH_WORKSPACE_GITIGNORE="$HOST_PATH_WORKSPACE/.gitignore"
HOST_PATH_WORKSPACE_OPENCODE="$HOST_PATH_WORKSPACE/.opencode"
HOST_PATH_WORKSPACE_PROCESS="$HOST_PATH_WORKSPACE/process"
HOST_PATH_WORKSPACE_PRODUCT="$HOST_PATH_WORKSPACE/product"
# HOST_PATH_CONTAINER_* are host paths to container file system directories
HOST_PATH_CONTAINER_FS=$(realpath "$HOST_PATH_WORKSPACE_TEMP/container-fs")
HOST_PATH_CONTAINER_BIN="$HOST_PATH_CONTAINER_FS/bin"
HOST_PATH_CONTAINER_ETC="$HOST_PATH_CONTAINER_FS/etc"
HOST_PATH_CONTAINER_HOME="$HOST_PATH_CONTAINER_FS/home"
HOST_PATH_CONTAINER_TEMP="$HOST_PATH_CONTAINER_FS/tmp"
HOST_PATH_CONTAINER_WORKSPACE="$HOST_PATH_CONTAINER_FS/workspace"
HOST_PATH_CONTAINER_WORKSPACE_TEMP="$HOST_PATH_CONTAINER_WORKSPACE/.temp"
HOST_PATH_CONTAINER_WORKSPACE_BUILDS="$HOST_PATH_CONTAINER_WORKSPACE_TEMP/builds"
HOST_PATH_CONTAINER_WORKSPACE_DOWNLOADS="$HOST_PATH_CONTAINER_WORKSPACE_TEMP/downloads"
HOST_PATH_CONTAINER_WORKSPACE_EXTERNAL="$HOST_PATH_CONTAINER_WORKSPACE/external"
HOST_PATH_CONTAINER_WORKSPACE_GIT="$HOST_PATH_CONTAINER_WORKSPACE/.git"
HOST_PATH_CONTAINER_WORKSPACE_GITIGNORE="$HOST_PATH_CONTAINER_WORKSPACE/.gitignore"
HOST_PATH_CONTAINER_WORKSPACE_OPENCODE="$HOST_PATH_CONTAINER_WORKSPACE/.opencode"
HOST_PATH_CONTAINER_WORKSPACE_PROCESS="$HOST_PATH_CONTAINER_WORKSPACE/process"
HOST_PATH_CONTAINER_WORKSPACE_PRODUCT="$HOST_PATH_CONTAINER_WORKSPACE/product"
HOST_PATH_CONTAINER_USER_HOME="$HOST_PATH_CONTAINER_HOME/$CONTAINER_USER_NAME"
HOST_PATH_CONTAINER_BUILDAH="$HOST_PATH_CONTAINER_FS/buildah"
HOST_PATH_CONTAINER_BUILDAH_RUNROOT="$HOST_PATH_CONTAINER_BUILDAH/runroot"
HOST_PATH_CONTAINER_BUILDAH_GRAPHROOT="$HOST_PATH_CONTAINER_BUILDAH/graphroot"
HOST_PATH_CONTAINER_BUILDAH_IMAGESTORE="$HOST_PATH_CONTAINER_BUILDAH/imagestore"


# CONTAINER_PATH_* are container paths to container file system directories
# NOTE: paths in container workspace have to match relative location to host .git
CONTAINER_PATH_WORKSPACE="/workspace"
CONTAINER_PATH_WORKSPACE_TEMP="$CONTAINER_PATH_WORKSPACE/.temp"
CONTAINER_PATH_WORKSPACE_BUILDS="$CONTAINER_PATH_WORKSPACE_TEMP/builds"
CONTAINER_PATH_WORKSPACE_DOWNLOADS="$CONTAINER_PATH_WORKSPACE_TEMP/downloads"
CONTAINER_PATH_WORKSPACE_EXTERNAL="$CONTAINER_PATH_WORKSPACE/external"
CONTAINER_PATH_WORKSPACE_GIT="$CONTAINER_PATH_WORKSPACE/.git"
CONTAINER_PATH_WORKSPACE_GITIGNORE="$CONTAINER_PATH_WORKSPACE/.gitignore"
CONTAINER_PATH_WORKSPACE_OPENCODE="$CONTAINER_PATH_WORKSPACE/.opencode"
CONTAINER_PATH_WORKSPACE_PROCESS="$CONTAINER_PATH_WORKSPACE/process"
CONTAINER_PATH_WORKSPACE_PRODUCT="$CONTAINER_PATH_WORKSPACE/product"
CONTAINER_PATH_CONTAINER_USER_HOME="/home/$CONTAINER_USER_NAME"
CONTAINER_PATH_BUILDAH="/buildah"
CONTAINER_ENV_VAR_PATH="@agentToolsBinPaths@:/bin"

# HOST_PATH_CONTAINER_MOUNT_* = {HOST_PATH_CONTAINER_MOUNT} + {CONTAINER_PATH_*}
# NOTE: host path to directory for container mounts
HOST_PATH_CONTAINER_MOUNT="$HOST_PATH_WORKSPACE_TEMP/container-mount"
HOST_PATH_CONTAINER_MOUNT_WORKSPACE="${HOST_PATH_CONTAINER_MOUNT}${CONTAINER_PATH_WORKSPACE}"
HOST_PATH_CONTAINER_MOUNT_WORKSPACE_TEMP="${HOST_PATH_CONTAINER_MOUNT}${CONTAINER_PATH_WORKSPACE_TEMP}"
HOST_PATH_CONTAINER_MOUNT_WORKSPACE_EXTERNAL="${HOST_PATH_CONTAINER_MOUNT}${CONTAINER_PATH_WORKSPACE_EXTERNAL}"
HOST_PATH_CONTAINER_MOUNT_WORKSPACE_GIT="${HOST_PATH_CONTAINER_MOUNT}${CONTAINER_PATH_WORKSPACE_GIT}"
HOST_PATH_CONTAINER_MOUNT_WORKSPACE_GITIGNORE="${HOST_PATH_CONTAINER_MOUNT}${CONTAINER_PATH_WORKSPACE_GITIGNORE}"
HOST_PATH_CONTAINER_MOUNT_WORKSPACE_OPENCODE="${HOST_PATH_CONTAINER_MOUNT}${CONTAINER_PATH_WORKSPACE_OPENCODE}"
HOST_PATH_CONTAINER_MOUNT_WORKSPACE_PROCESS="${HOST_PATH_CONTAINER_MOUNT}${CONTAINER_PATH_WORKSPACE_PROCESS}"
HOST_PATH_CONTAINER_MOUNT_WORKSPACE_PRODUCT="${HOST_PATH_CONTAINER_MOUNT}${CONTAINER_PATH_WORKSPACE_PRODUCT}"
HOST_PATH_CONTAINER_MOUNT_BUILDAH="${HOST_PATH_CONTAINER_MOUNT}${CONTAINER_PATH_BUILDAH}"

# Make container mount directories on host
[[ -d $HOST_PATH_CONTAINER_FS ]] || mkdir -p $HOST_PATH_CONTAINER_FS
[[ -d $HOST_PATH_CONTAINER_BIN ]] || mkdir -p $HOST_PATH_CONTAINER_BIN
[[ -d $HOST_PATH_CONTAINER_ETC ]] || mkdir -p $HOST_PATH_CONTAINER_ETC
[[ -d $HOST_PATH_CONTAINER_HOME ]] || mkdir -p $HOST_PATH_CONTAINER_HOME
[[ -d $HOST_PATH_CONTAINER_TEMP ]] || mkdir -p $HOST_PATH_CONTAINER_TEMP
[[ -d $HOST_PATH_CONTAINER_USER_HOME ]] || mkdir -p $HOST_PATH_CONTAINER_USER_HOME
[[ -d $HOST_PATH_CONTAINER_WORKSPACE ]] || mkdir -p $HOST_PATH_CONTAINER_WORKSPACE
[[ -d $HOST_PATH_CONTAINER_WORKSPACE_TEMP ]] || mkdir -p $HOST_PATH_CONTAINER_WORKSPACE_TEMP
[[ -d $HOST_PATH_CONTAINER_WORKSPACE_BUILDS ]] || mkdir -p $HOST_PATH_CONTAINER_WORKSPACE_BUILDS
[[ -d $HOST_PATH_CONTAINER_WORKSPACE_DOWNLOADS ]] || mkdir -p $HOST_PATH_CONTAINER_WORKSPACE_DOWNLOADS
[[ -d $HOST_PATH_CONTAINER_WORKSPACE_EXTERNAL ]] || mkdir -p $HOST_PATH_CONTAINER_WORKSPACE_EXTERNAL
[[ -d $HOST_PATH_CONTAINER_WORKSPACE_GIT ]] || mkdir -p $HOST_PATH_CONTAINER_WORKSPACE_GIT
[[ -f $HOST_PATH_CONTAINER_WORKSPACE_GITIGNORE ]] || touch $HOST_PATH_CONTAINER_WORKSPACE_GITIGNORE
[[ -d $HOST_PATH_CONTAINER_WORKSPACE_OPENCODE ]] || mkdir -p $HOST_PATH_CONTAINER_WORKSPACE_OPENCODE
[[ -d $HOST_PATH_CONTAINER_WORKSPACE_PROCESS ]] || mkdir -p $HOST_PATH_CONTAINER_WORKSPACE_PROCESS
[[ -d $HOST_PATH_CONTAINER_WORKSPACE_PRODUCT ]] || mkdir -p $HOST_PATH_CONTAINER_WORKSPACE_PRODUCT
[[ -d $HOST_PATH_CONTAINER_BUILDAH_RUNROOT ]] || mkdir -p $HOST_PATH_CONTAINER_BUILDAH_RUNROOT
[[ -d $HOST_PATH_CONTAINER_BUILDAH_GRAPHROOT ]] || mkdir -p $HOST_PATH_CONTAINER_BUILDAH_GRAPHROOT
[[ -d $HOST_PATH_CONTAINER_BUILDAH_IMAGESTORE ]] || mkdir -p $HOST_PATH_CONTAINER_BUILDAH_IMAGESTORE
[[ -d $HOST_PATH_CONTAINER_MOUNT ]] || mkdir -p $HOST_PATH_CONTAINER_MOUNT


# Evaluate the list and bake a standard space-separated Bash array definition right here
mapfile -t NIX_STORE_PATHS < "@agentClosureLinuxNixOs@/store-paths"


# Display usage helper
usage() {
cat <<EOF
	Usage: $(basename "$0") [OPTIONS]

	Options:
		--mode MODE            "server" (default) or "shell"
		--ready-file-path	   File path in host namespace to indicate internal container env is ready
		--start-shell-script   File path in host namespace to bind mount in unshare namespace
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
		--ready-file-path)
			INTERNAL_ENV_READY_FILE_PATH=$2
			shift 2
			;;
		--start-shell-script)
			# Get the value of the next argument
			START_SHELL_SCRIPT_PATH="$2"
			shift 2 # Shift past the flag and its value
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

# Verify that the required internal-env-script parameter was provided
if [[ -z "$INTERNAL_ENV_READY_FILE_PATH" ]]; then
	echo "Error: --ready-file-path is required." >&2
	exit 1
fi

# Verify that the required start-shell-script parameter was provided
if [[ -z "$START_SHELL_SCRIPT_PATH" ]]; then
	echo "Error: --start-shell-script is required." >&2
	exit 1
fi


echo "=== Configure unshare Network Namespace ==="
# Bring up the loopback interface (slirp4netns doesn't do this automatically)
ip link set lo up

# Wait a brief moment for slirp4netns to fully provision 'tap0' if needed
for i in {1..5}; do
    if ip link show tap0 >/dev/null 2>&1; then break; fi
    sleep 0.5
done

echo "=== FINISHED: Configure unshare Network Namespace ==="


# -------------------------------------------------------------------------
# --- BUBBLEWRAP-LIKE FILESYSTEM ISOLATION ---
# -------------------------------------------------------------------------
# Inside the namespace, we are root and have CAP_SYS_ADMIN.

# Setting enironment variables
PATH="$CONTAINER_ENV_VAR_PATH"      

# Force all inherited host mounts to be private inside this namespace so
# changes do not attempt to propagate back to the host.
mount --make-rprivate /

echo "=== Preparing Sandbox Root at $HOST_PATH_CONTAINER_MOUNT ==="

# Ensure the base sandbox root exists and is turned into a mount point (required for pivot_root)
# NOTE: must use absolute path for the value for HOST_PATH_CONTAINER_FS otherwise pivot_root will have issues
# NOTE: using tmpfs results in any sub-items created using mount directory does not affect the real host mount directory
mount -t tmpfs -o exec,mode=0755 tmpfs $HOST_PATH_CONTAINER_MOUNT
mount --make-private $HOST_PATH_CONTAINER_MOUNT
mkdir -p $HOST_PATH_CONTAINER_MOUNT/{dev,proc,sys,bin,etc,home,nix,run,tmp,usr/bin,workspace}
mkdir -p $HOST_PATH_CONTAINER_MOUNT/workspace/{.git,.opencode,.temp/builds,.temp/downloads,external,process,product}


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
	# Example: /nix/store/.../bin/bash becomes $HOST_PATH_CONTAINER_MOUNT/nix/store/.../bin/bash
	dest_path="${HOST_PATH_CONTAINER_MOUNT}${source_path}"

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

# Making the start shell script wrapper available within namespace to be called later by script that initiated this script
mkdir -p "${HOST_PATH_CONTAINER_MOUNT}@startShellScriptShellWrapper_nixStorePath@"
mount --bind "@startShellScriptShellWrapper_nixStorePath@" "${HOST_PATH_CONTAINER_MOUNT}@startShellScriptShellWrapper_nixStorePath@"
echo "=== FINISHED: Bind Mount Nix Store Paths ==="


echo "=== Bind Mount For /dev ==="
# NOTE: opencode needs /dev to configured correctly to work (not sure what)
mount -t tmpfs -o mode=0755 tmpfs "$HOST_PATH_CONTAINER_MOUNT/dev"
touch \
    "$HOST_PATH_CONTAINER_MOUNT/dev/full" \
	"$HOST_PATH_CONTAINER_MOUNT/dev/null" \
    "$HOST_PATH_CONTAINER_MOUNT/dev/random" \
    "$HOST_PATH_CONTAINER_MOUNT/dev/tty" \
    "$HOST_PATH_CONTAINER_MOUNT/dev/urandom" \
    "$HOST_PATH_CONTAINER_MOUNT/dev/zero"

# /proc/self/fd is not a standard directory; it is a dynamic, magical gateway managed by the procfs kernel driver
# "ln -s" will reference the "/proc" path within the unshare namespace not the host namespace
ln -s /proc/self/fd      	"$HOST_PATH_CONTAINER_MOUNT/dev/fd"
ln -s /proc/self/fd/0    	"$HOST_PATH_CONTAINER_MOUNT/dev/stdin"
ln -s /proc/self/fd/1    	"$HOST_PATH_CONTAINER_MOUNT/dev/stdout"
ln -s /proc/self/fd/2    	"$HOST_PATH_CONTAINER_MOUNT/dev/stderr"

mount --bind /dev/full    	"$HOST_PATH_CONTAINER_MOUNT/dev/full"
mount --bind /dev/null 		"$HOST_PATH_CONTAINER_MOUNT/dev/null"
mount --bind /dev/random  	"$HOST_PATH_CONTAINER_MOUNT/dev/random"
mount --bind /dev/tty     	"$HOST_PATH_CONTAINER_MOUNT/dev/tty"
mount --bind /dev/urandom 	"$HOST_PATH_CONTAINER_MOUNT/dev/urandom"
mount --bind /dev/zero    	"$HOST_PATH_CONTAINER_MOUNT/dev/zero"

mkdir -p "$HOST_PATH_CONTAINER_MOUNT/dev/pts"
mount -t devpts -o newinstance,ptmxmode=0666,mode=0620 devpts "$HOST_PATH_CONTAINER_MOUNT/dev/pts"
rm -f "$HOST_PATH_CONTAINER_MOUNT/dev/ptmx"
ln -s pts/ptmx "$HOST_PATH_CONTAINER_MOUNT/dev/ptmx"
echo "=== FINISHED: Bind Mount For /dev ==="


echo "=== Bind Mount For General System ==="
mount --bind $HOST_PATH_CONTAINER_BIN 	"$HOST_PATH_CONTAINER_MOUNT/bin"
mount --bind $HOST_PATH_CONTAINER_ETC 	"$HOST_PATH_CONTAINER_MOUNT/etc"
mount --bind $HOST_PATH_CONTAINER_HOME 	"$HOST_PATH_CONTAINER_MOUNT/home"
mount -t tmpfs -o exec,mode=1777 tmpfs 	"$HOST_PATH_CONTAINER_MOUNT/tmp"

mount -t tmpfs sys "$HOST_PATH_CONTAINER_MOUNT/sys"
mkdir -p "$HOST_PATH_CONTAINER_MOUNT/sys/devices/system/cpu"
touch "$HOST_PATH_CONTAINER_MOUNT/sys/devices/system/cpu/online"
echo "0-15" > "$HOST_PATH_CONTAINER_MOUNT/sys/devices/system/cpu/online"

# NOTE: podman looks for "/sys/fs/cgroup"
# NOTE: to mount sysfs sysfs need to configure unshare with "--net" so that the unshare 
#       namespace owns its own network namespace
# NOTE: using this mounting for /sys breaks buildah and opencode
# mount -t sysfs sysfs "$HOST_PATH_CONTAINER_MOUNT/sys"

touch "$HOST_PATH_CONTAINER_MOUNT/etc/resolv.conf"
mount --bind /etc/resolv.conf "$HOST_PATH_CONTAINER_MOUNT/etc/resolv.conf"

mkdir -p "$HOST_PATH_CONTAINER_MOUNT/etc/ssl/certs"
mount --bind "@cacert_nixStorePath@/etc/ssl/certs" "$HOST_PATH_CONTAINER_MOUNT/etc/ssl/certs"


# Replicate the minimal /run path OpenCode searches for on NixOS
mkdir -p "$HOST_PATH_CONTAINER_MOUNT/run/current-system/sw/bin"
ln -s "@bashInteractive_nixStorePath@/bin/bash" "$HOST_PATH_CONTAINER_MOUNT/run/current-system/sw/bin/bash"

# Bind standard NixOS library fallbacks if present
# if [ -d /lib64 ]; then
#   mkdir -p "$HOST_PATH_CONTAINER_MOUNT/lib64"
#   mount --bind /lib64 "$HOST_PATH_CONTAINER_MOUNT/lib64"
#   mount -o remount,ro,bind "$HOST_PATH_CONTAINER_MOUNT/lib64"
# fi
echo "=== FINISHED: Bind Mount For General System ==="


echo "=== Bind Mount For Fuse OverlayFS ==="
touch "$HOST_PATH_CONTAINER_MOUNT/dev/fuse"
mount --bind /dev/fuse "$HOST_PATH_CONTAINER_MOUNT/dev/fuse"
touch "$HOST_PATH_CONTAINER_MOUNT/usr/bin/fuse-overlayfs"
mount --bind -o exec "@fuse_overlayfs_nixStorePath@/bin/fuse-overlayfs" "$HOST_PATH_CONTAINER_MOUNT/usr/bin/fuse-overlayfs"
echo "=== FINISHED: Bind Mount For Fuse OverlayFS ==="


echo "=== Linking GNU Bash & Env ==="
[[ -f "$HOST_PATH_CONTAINER_MOUNT/bin/bash" ]] || ln -s "@bashInteractive_nixStorePath@/bin/bash" "$HOST_PATH_CONTAINER_MOUNT/bin/bash"
[[ -f "$HOST_PATH_CONTAINER_MOUNT/bin/sh" ]] || ln -s "@bashInteractive_nixStorePath@/bin/bash" "$HOST_PATH_CONTAINER_MOUNT/bin/sh"
[[ -f "$HOST_PATH_CONTAINER_MOUNT/bin/env" ]] || ln -s "@coreutils_nixStorePath@/bin/env" "$HOST_PATH_CONTAINER_MOUNT/bin/env"
[[ -f "$HOST_PATH_CONTAINER_MOUNT/usr/bin/env" ]] || ln -s "@coreutils_nixStorePath@/bin/env" "$HOST_PATH_CONTAINER_MOUNT/usr/bin/env"
echo "=== FINISHED: Linking GNU Bash & Env ==="


echo "=== Bind Mount For Buildah ==="
mkdir -p $HOST_PATH_CONTAINER_MOUNT_BUILDAH
mount --bind $HOST_PATH_CONTAINER_BUILDAH 		$HOST_PATH_CONTAINER_MOUNT_BUILDAH
echo "=== FINISHED: Bind Mount For Buildah ==="


# NOTE: all mount directories created earlier
echo "=== Bind Mount For Workspace ==="
touch $HOST_PATH_CONTAINER_MOUNT_WORKSPACE_GITIGNORE
mount --bind $HOST_PATH_WORKSPACE_TEMP 			$HOST_PATH_CONTAINER_WORKSPACE_TEMP
mount --bind $HOST_PATH_WORKSPACE_EXTERNAL 		$HOST_PATH_CONTAINER_MOUNT_WORKSPACE_EXTERNAL
mount --bind $HOST_PATH_WORKSPACE_GIT 			$HOST_PATH_CONTAINER_MOUNT_WORKSPACE_GIT
mount --bind $HOST_PATH_WORKSPACE_GITIGNORE 	$HOST_PATH_CONTAINER_MOUNT_WORKSPACE_GITIGNORE
mount --bind $HOST_PATH_WORKSPACE_OPENCODE 		$HOST_PATH_CONTAINER_MOUNT_WORKSPACE_OPENCODE
mount --bind $HOST_PATH_WORKSPACE_PROCESS 		$HOST_PATH_CONTAINER_MOUNT_WORKSPACE_PROCESS
mount --bind $HOST_PATH_WORKSPACE_PRODUCT 		$HOST_PATH_CONTAINER_MOUNT_WORKSPACE_PRODUCT
echo "=== FINISHED: Bind Mount For Workspace ==="


echo "=== Create Configuration Files ==="
# Container /etc/passwd and /etc/group      
cat <<EOF > "$HOST_PATH_CONTAINER_ETC/passwd"
root:x:0:0:root:/root:/bin/bash
$CONTAINER_USER_NAME:x:$CONTAINER_USER_UID:$CONTAINER_USER_GID:$CONTAINER_USER_NAME:/home/$CONTAINER_USER_NAME:/bin/bash
EOF

cat <<EOF > "$HOST_PATH_CONTAINER_ETC/group"
root:x:0:
$CONTAINER_USER_NAME:x:$CONTAINER_USER_GID:
EOF


# Container /etc/subuid and /etc/subgid
# NOTE: buildah needs both host namespace and unshare namespace subuid and subgid configured correctly
cat <<EOF > "$HOST_PATH_CONTAINER_ETC/subuid"
# This defines UID allocation for level 2 namespace from the perspective of level 1 namespace
# Level 0 namespace = host machine namespace
# Level 1 namespace = unshare namespace
# Level 2 namespace = buildah container namespace
root:1000:10000
EOF

cat <<EOF >  "$HOST_PATH_CONTAINER_ETC/subgid"
# This defines GID allocation for level 2 namespace from the perspective of level 1 namespace
# Level 0 namespace = host machine namespace
# Level 1 namespace = unshare namespace
# Level 2 namespace = buildah container namespace
root:1000:10000
EOF


# Container /etc/containers
mkdir -p "$HOST_PATH_CONTAINER_ETC/containers"

# /etc/containers/containers.conf
cat <<EOF > "$HOST_PATH_CONTAINER_ETC/containers/containers.conf"
[engine]
# Explicitly forces chroot behavior at the engine layer
isolation = "chroot"

# Strips the engine from trying to escalate or alter supplemental group privileges
infra_command = ""
EOF


# /etc/containers/storage.conf
# Create a local storage.conf to force Buildah to use the fuse-overlafs overlay driver
# (Standard overlayfs requires kernel mounts that bwrap blocks by default)
cat <<EOF > "$HOST_PATH_CONTAINER_ETC/containers/storage.conf"
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
cat <<EOF > "$HOST_PATH_CONTAINER_ETC/containers/registries.conf"
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
cat <<EOF > "$HOST_PATH_CONTAINER_ETC/containers/policy.json"
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

mkdir -p "$HOST_PATH_CONTAINER_USER_HOME/.config/opencode"
cat <<EOF > "$HOST_PATH_CONTAINER_USER_HOME/.config/opencode/opencode.json"
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
cd "$HOST_PATH_CONTAINER_MOUNT"

# Pivot root directly onto itself. This puts the NEW root at / and the OLD root at / (overlapped)
mkdir -p "$HOST_PATH_CONTAINER_MOUNT/old_root"
pivot_root . old_root

echo "***** pre-mount: /proc  *****"
ls -la /proc

mount -t proc proc /proc

echo "***** post-mount: /proc *****"
ls -la /proc

# Create file to signal to host namespace process that internal environment is ready
touch "old_root/$INTERNAL_ENV_READY_FILE_PATH"

# Lazily unmount the old root (which is pinned underneath '.')
umount -l old_root
rmdir old_root

# Move into the new root 
cd /workspace



# Verify that Nix store path to start shell 
if [ -d "@startShellScriptShellWrapper_nixStorePath@" ]; then
    echo "@startShellScriptShellWrapper_nixStorePath@ directory exists!"
else
    echo "@startShellScriptShellWrapper_nixStorePath@ directory does not exist."
fi

echo "=== FINISHED: Switch Root Directory ==="


echo "=== Create Files For Future nsenter Sessions ==="
# quoting EOF to prevent Bash expansion
cat <<'EOF' >"$CONTAINER_PATH_CONTAINER_USER_HOME/.bash_profile"
#!/usr/bin/env bash

# If running bash, source the user's .bashrc if it exists
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
EOF


cat <<EOF >"$CONTAINER_PATH_CONTAINER_USER_HOME/.bashrc"
#!/usr/bin/env bash

# Used for every new interactive terminal session
export CONTAINER_RUNTIME=crun
export HOME="$CONTAINER_PATH_CONTAINER_USER_HOME"
export PATH="$CONTAINER_ENV_VAR_PATH"
export USER="$CONTAINER_USER_NAME"
export TEMP="/tmp"
export TEMPDIR="/tmp"
export TMP="/tmp"
export TMPDIR="/tmp"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"

# NOTE: source must precede usage of functions defined in functions.bash
source ~/functions.bash

# NOTE: escaped Bash expansion for TERM
TERM="\${TERM:-xterm-256color}"

# NOTE: escaped Bash expansion for get_git_prompt
PS1="\[\e[0;36m\][🤖 \u@\h]\[\e[0;33m\][\$(get_git_prompt)]\[\e[38;5;200m\][\w]\n\[\e[0;0m\]> "

# check for terminal window resizing
shopt -s checkwinsize

EOF

cat <<EOF >"$CONTAINER_PATH_CONTAINER_USER_HOME/.env"
EOF

# quoting EOF to prevent Bash expansion
cat <<'EOF' >"$CONTAINER_PATH_CONTAINER_USER_HOME/functions.bash"
#!/usr/bin/env bash

get_git_prompt() {
    # Check if we are inside a git repository
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        printf 'no-git'
        return
    fi

    # Get the current branch or commit hash
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)

    # Check repository status flags
    local status_output
    status_output=$(git status --porcelain 2>/dev/null)

    local dirty=""
    local untracked=""
    local ahead_behind=""

    # Check for modified/staged/untracked files
    if [[ -n "$status_output" ]]; then
        if echo "$status_output" | grep -q '^[MADRC ]'; then
            dirty="*"
        fi
        if echo "$status_output" | grep -q '??'; then
            untracked="?"
        fi
    fi

    # Check ahead/behind status relative to upstream
    local upstream
    upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
    if [[ -n "$upstream" ]]; then
        local counts
        counts=$(git rev-list --left-right --count HEAD...@{u} 2>/dev/null)
        local ahead
        local behind
        # ahead=$(echo "$counts" | cut -f1)
        # behind=$(echo "$counts" | cut -f2)
        read -r ahead behind <<< "$counts"

        if (( ahead > 0 )); then
            ahead_behind+="⇡"
        fi
        if (( behind > 0 )); then
            ahead_behind+="⇣"
        fi
    fi

    # Output the formatted prompt segment
    # echo "($branch$dirty$untracked$ahead_behind)"
    printf '(%s%s%s%s)' "$branlsch" "$dirty" "$untracked" "$ahead_behind"
}

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

export -f get_git_prompt
export -f check_executables
EOF

echo "=== FINISHED: Create Files For Future nsenter Sessions ==="


sleep infinity