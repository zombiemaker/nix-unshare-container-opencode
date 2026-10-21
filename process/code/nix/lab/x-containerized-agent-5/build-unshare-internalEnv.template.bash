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

echo "$@"

script_name="$0"
echo "Running script: $script_name"
echo "Current working directory: $PWD"
echo "User inside namespace: $(whoami)"
echo "PID inside namespace: $$"
echo "Granted full set of of all root capabilities including CAP_SYS_ADMIN" 

set -eo pipefail

# Default script variable values
DEBUG=false
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
CONTAINER_USER_NAME="root"
CONTAINER_USER_HOME_HOST_PATH="$CONTAINER_HOME_HOST_PATH/$CONTAINER_USER_NAME"
CONTAINER_USER_UID=$(id -u)
CONTAINER_USER_GID=$(id -g)
CONTAINER_PATH="@agentToolsBinPaths@:/bin"
CONTAINER_PS1="PS1="\[\e[0;36m\][🤖 \u@\h]\[\e[0;33m\][$(get_git_prompt)]\[\e[38;5;200m\][\w]\n\[\e[0;0m\]> "
CONTAINER_TERM="${TERM:-xterm-256color}"

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

# Making the start shell script wrapper available within namespace to be called later by script that initiated this script
mkdir -p "${SANDBOX_ROOT}@startShellScriptShellWrapper_nixStorePath@"
mount --bind "@startShellScriptShellWrapper_nixStorePath@" "${SANDBOX_ROOT}@startShellScriptShellWrapper_nixStorePath@"
echo "=== FINISHED: Bind Mount Nix Store Paths ==="


echo "=== Linking GNU Bash & Env ==="
ln -s "@bashInteractive_nixStorePath@/bin/bash" "$SANDBOX_ROOT/bin/bash"
ln -s "@bashInteractive_nixStorePath@/bin/bash" "$SANDBOX_ROOT/bin/sh"
ln -s "@coreutils_nixStorePath@/bin/env"        "$SANDBOX_ROOT/bin/env"
ln -s "@coreutils_nixStorePath@/bin/env"        "$SANDBOX_ROOT/usr/bin/env"
echo "=== FINISHED: Linking GNU Bash & Env ==="


echo "=== Bind Mount For /dev ==="
# NOTE: opencode needs /dev to configured correctly to work (not sure what)
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
mount --bind $CONTAINER_BIN_HOST_PATH "$SANDBOX_ROOT/bin"
mount --bind $CONTAINER_ETC_HOST_PATH "$SANDBOX_ROOT/etc"
mount --bind $CONTAINER_HOME_HOST_PATH "$SANDBOX_ROOT/home"
# mount --bind -o exec $CONTAINER_TEMP_HOST_PATH "$SANDBOX_ROOT/tmp"
mount -t tmpfs -o exec,mode=1777 tmpfs "$SANDBOX_ROOT/tmp"

# podman looks for "/sys/fs/cgroup"
# to mount sysfs sysfs need to configure unshare with "--net" so that the unshare 
# namespace owns its own network namespace
mount -t sysfs sysfs "$SANDBOX_ROOT/sys"

touch "$SANDBOX_ROOT/etc/resolv.conf"
mount --bind /etc/resolv.conf "$SANDBOX_ROOT/etc/resolv.conf"

mkdir -p "$SANDBOX_ROOT/etc/ssl/certs"
mount --bind "@cacert_nixStorePath@/etc/ssl/certs" "$SANDBOX_ROOT/etc/ssl/certs"


# Replicate the minimal /run path OpenCode searches for on NixOS
mkdir -p "$SANDBOX_ROOT/run/current-system/sw/bin"
ln -s "@bashInteractive_nixStorePath@/bin/bash" "$SANDBOX_ROOT/run/current-system/sw/bin/bash"

# Bind standard NixOS library fallbacks if present
# if [ -d /lib64 ]; then
#   mkdir -p "$SANDBOX_ROOT/lib64"
#   mount --bind /lib64 "$SANDBOX_ROOT/lib64"
#   mount -o remount,ro,bind "$SANDBOX_ROOT/lib64"
# fi
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
# NOTE: buildah needs both host namespace and unshare namespace subuid and subgid configured correctly
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
# Create a local storage.conf to force Buildah to use the fuse-overlafs overlay driver
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

# Create file to signal to host namespace process that internal environment is ready
touch "old_root/$INTERNAL_ENV_READY_FILE_PATH"

# Re-mount your essential kernel filesystems inside the new root
mount -t proc proc /proc

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
cat <<EOF >"/home/$CONTAINER_USER_NAME/.bash_profile"
#!/usr/bin/env bash

# If running bash, source the user's .bashrc if it exists
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
EOF


cat <<EOF >"/home/$CONTAINER_USER_NAME/.bashrc"
#!/usr/bin/env bash

# Used for every new interactive terminal session
export CONTAINER_RUNTIME=crun
export HOME="/home/$CONTAINER_USER_NAME"
export PATH="$CONTAINER_PATH"
export USER="$CONTAINER_USER_NAME"
export TEMP="/tmp"
export TEMPDIR="/tmp"
export TMP="/tmp"
export TMPDIR="/tmp"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
TERM="$CONTAINER_TERM"
PS1="$CONTAINER_PS1"

# check for terminal window resizing
shopt -s checkwinsize

source ~/functions.bash
EOF

cat <<EOF >"/home/$CONTAINER_USER_NAME/.env"
EOF

cat <<EOF >"/home/$CONTAINER_USER_NAME/functions.bash"
#!/usr/bin/env bash

get_git_prompt() {
    # Check if we are inside a git repository
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
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
        ahead=$(echo "$counts" | cut -f1)
        behind=$(echo "$counts" | cut -f2)

        if (( ahead > 0 )); then
            ahead_behind+="⇡"
        fi
        if (( behind > 0 )); then
            ahead_behind+="⇣"
        fi
    fi

    # Output the formatted prompt segment
    echo "($branch$dirty$untracked$ahead_behind)"
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
EOF

echo "=== FINISHED: Create Files For Future nsenter Sessions ==="


sleep infinity