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
script_name="$0"
echo "$NAMESPACE: running script: $script_name"
echo "$NAMESPACE: script arguments: $@"
echo "$NAMESPACE: current working directory: $PWD"
echo "$NAMESPACE: user name: $(whoami)"
echo "$NAMESPACE: PID: $$"
echo "$NAMESPACE: granted full set of of all root capabilities including CAP_SYS_ADMIN" 

set -eo pipefail

echo "#############################################"
echo "Pre-pivot_root tasks"
echo "#############################################"


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

INSIDE_NS_HOST_PATH_WORKSPACE="$PWD"
INSIDE_NS_HOST_PATH_WORKSPACE_TEMP="$INSIDE_NS_HOST_PATH_WORKSPACE/.temp"
INSIDE_NS_HOST_PATH_ROOTFS_MOUNT="$INSIDE_NS_HOST_PATH_WORKSPACE_TEMP/ns-rootfs_mount"
INSIDE_NS_HOST_PATH_ROOTFS_MOUNT_SOURCE="$INSIDE_NS_HOST_PATH_WORKSPACE_TEMP/ns-rootfs_source"
# NOTE: Using a host directory to persist container images
INSIDE_NS_HOST_PATH_ROOTFS_MOUNT_SOURCE_BUILDAH_RUN="$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT_SOURCE/buildah-run"

INSIDE_NS_PATH_CONTAINER_USER_HOME="/home/$CONTAINER_USER_NAME"
INSIDE_NS_PATH_WORKSPACE="/workspace"
INSIDE_NS_PATH_BUILDAH_RUN="/buildah-run"
# TODO: make buildah run files persistent to save images
INSIDE_NS_ENV_VAR_PATH="@agentToolsBinPaths@:/bin"

# Make container mount directories on host
[[ -d $INSIDE_NS_HOST_PATH_ROOTFS_MOUNT ]] || mkdir -p $INSIDE_NS_HOST_PATH_ROOTFS_MOUNT
[[ -d $INSIDE_NS_HOST_PATH_ROOTFS_MOUNT_SOURCE ]] || mkdir -p $INSIDE_NS_HOST_PATH_ROOTFS_MOUNT_SOURCE
[[ -d $INSIDE_NS_HOST_PATH_ROOTFS_MOUNT_SOURCE_BUILDAH_RUN ]] || mkdir -p $INSIDE_NS_HOST_PATH_ROOTFS_MOUNT_SOURCE_BUILDAH_RUN


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
PATH="$INSIDE_NS_ENV_VAR_PATH"     

echo "=== Initialize Container Root At $INSIDE_NS_HOST_PATH_ROOTFS_MOUNT ==="
# Make the mount space private before any mount operations
mount --make-rprivate /

# NOTE: must use absolute path for the value for HOST_PATH_CONTAINER_FS otherwise pivot_root will have issues
# NOTE: using tmpfs results in any sub-items created using mount directory does not affect the real host mount directory
mount -t tmpfs -o exec,mode=0755 tmpfs $INSIDE_NS_HOST_PATH_ROOTFS_MOUNT
mount --make-private $INSIDE_NS_HOST_PATH_ROOTFS_MOUNT
mkdir -p $INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/{bin,dev,etc,home,nix/store,proc,run,sys,tmp,usr/bin,workspace}
echo "=== FINISHED: Initialize Container Root At $INSIDE_NS_HOST_PATH_ROOTFS_MOUNT ==="

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
	# Example: /nix/store/.../bin/bash becomes $INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/nix/store/.../bin/bash
	dest_path="${INSIDE_NS_HOST_PATH_ROOTFS_MOUNT}${source_path}"

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
mkdir -p "${INSIDE_NS_HOST_PATH_ROOTFS_MOUNT}@startShellScriptShellWrapper_nixStorePath@"
mount --bind "@startShellScriptShellWrapper_nixStorePath@" "${INSIDE_NS_HOST_PATH_ROOTFS_MOUNT}@startShellScriptShellWrapper_nixStorePath@"
echo "=== FINISHED: Bind Mount Nix Store Paths ==="


echo "=== Bind Mount For /run, /sys, and /tmp ==="
# NOTE: using this mounting for /syst works with buildah and opencode
# mount -t tmpfs sys "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/sys"
# mkdir -p "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/sys/devices/system/cpu"
# touch "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/sys/devices/system/cpu/online"
# echo "0-15" > "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/sys/devices/system/cpu/online"

# NOTE: podman looks for a writable cgroup2 mounted at "/sys/fs/cgroup"
# NOTE: to mount sysfs sysfs need to configure unshare with "--net" so that the unshare 
#       namespace owns its own network namespace
# NOTE: using this mounting for /sys breaks buildah and opencode
mount -t sysfs -o nosuid,nodev,noexec sysfs "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/sys"
mkdir -p "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/sys/fs/cgroup"
mount -t cgroup2 cgroup "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/sys/fs/cgroup"

mount -t tmpfs -o exec,mode=0755 tmpfs "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/run"
mount -t tmpfs -o exec,mode=1777 tmpfs "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/tmp"
echo "=== FINISHED: Bind Mount For /run, /sys, and /tmp ==="


echo "=== Bind Mount For /dev ==="
# NOTE: opencode needs /dev to configured correctly to work (not sure what)
mount -t tmpfs -o nosuid,mode=755 tmpfs "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/dev"
touch \
    "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/dev/full" \
	"$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/dev/null" \
    "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/dev/random" \
    "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/dev/tty" \
    "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/dev/urandom" \
    "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/dev/zero"

mount --bind /dev/full    	"$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/dev/full"
mount --bind /dev/null 		"$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/dev/null"
mount --bind /dev/random  	"$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/dev/random"
mount --bind /dev/tty     	"$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/dev/tty"
mount --bind /dev/urandom 	"$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/dev/urandom"
mount --bind /dev/zero    	"$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/dev/zero"

# /proc/self/fd is not a standard directory; it is a dynamic, magical gateway managed by the procfs kernel driver
# "ln -s" will reference the "/proc" path within the unshare namespace not the host namespace
ln -s /proc/self/fd      	"$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/dev/fd"
ln -s /proc/self/fd/0    	"$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/dev/stdin"
ln -s /proc/self/fd/1    	"$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/dev/stdout"
ln -s /proc/self/fd/2    	"$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/dev/stderr"

mkdir -p "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/dev/pts"
mount -t devpts -o newinstance,ptmxmode=0666,mode=0620 devpts "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/dev/pts"
rm -f "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/dev/ptmx"
ln -s pts/ptmx "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/dev/ptmx"


# NOTE: podman needs the shared memory /dev/shm directory
mkdir -p "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/dev/shm"
# Mount a new, writeable tmpfs instance explicitly for POSIX shared memory
mount -t tmpfs -o rw,nosuid,nodev,noexec,size=64m tmpfs "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/dev/shm"

echo "=== FINISHED: Bind Mount For /dev ==="


echo "=== Bind Mount For Fuse OverlayFS ==="
touch "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/dev/fuse"
mount --bind /dev/fuse "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/dev/fuse"
touch "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/usr/bin/fuse-overlayfs"
mount --bind -o exec "@fuse_overlayfs_nixStorePath@/bin/fuse-overlayfs" "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/usr/bin/fuse-overlayfs"
echo "=== FINISHED: Bind Mount For Fuse OverlayFS ==="


echo "=== Bind Mount For General System ==="
touch "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/etc/resolv.conf"
mount --bind /etc/resolv.conf "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/etc/resolv.conf"

mkdir -p "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/etc/ssl/certs"
mount --bind "@cacert_nixStorePath@/etc/ssl/certs" "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/etc/ssl/certs"

# Replicate the minimal /run path OpenCode searches for on NixOS
mkdir -p "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/run/current-system/sw/bin"
ln -s "@bashInteractive_nixStorePath@/bin/bash" "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/run/current-system/sw/bin/bash"
echo "=== FINISHED: Bind Mount For General System ==="


echo "=== Linking GNU Bash & Env ==="
[[ -f "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/bin/bash" ]] 	 || ln -s "@bashInteractive_nixStorePath@/bin/bash" "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/bin/bash"
[[ -f "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/bin/sh" ]] 	 || ln -s "@bashInteractive_nixStorePath@/bin/bash" "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/bin/sh"
[[ -f "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/bin/env" ]] 	 || ln -s "@coreutils_nixStorePath@/bin/env" "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/bin/env"
[[ -f "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/usr/bin/env" ]] || ln -s "@coreutils_nixStorePath@/bin/env" "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/usr/bin/env"
echo "=== FINISHED: Linking GNU Bash & Env ==="


echo "=== Bind Mount For Buildah ==="
mkdir -p "${INSIDE_NS_HOST_PATH_ROOTFS_MOUNT}${INSIDE_NS_PATH_BUILDAH_RUN}"
mount --bind "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT_SOURCE_BUILDAH_RUN" "${INSIDE_NS_HOST_PATH_ROOTFS_MOUNT}${INSIDE_NS_PATH_BUILDAH_RUN}"
echo "=== FINISHED: Bind Mount For Buildah ==="


echo "=== Mount Workspace Directory ==="
mount --bind -o exec,mode=0755 "$INSIDE_NS_HOST_PATH_WORKSPACE" "${INSIDE_NS_HOST_PATH_ROOTFS_MOUNT}${INSIDE_NS_PATH_WORKSPACE}"
echo "=== FINISHED: Mount Workspace Directory ==="



echo "=== Switch Root Directory ==="
# Trick to to completely vanish old root without even needing a temporary directory
cd "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT"

# Pivot root directly onto itself. This puts the NEW root at / and the OLD root at / (overlapped)
mkdir -p "$INSIDE_NS_HOST_PATH_ROOTFS_MOUNT/old_root"
pivot_root . old_root

# NOTE: have to update working directory descriptor
cd /

# NOTE: have to update PATH to access executables
# export PATH="$POST_PIVOT_PATH"

# Mount /proc using target file system's structure
# NOTE: this has to occur before umount old_root?
mount -t proc proc /proc

# Create file to signal to host namespace process that internal environment is ready
touch "/old_root/$INTERNAL_ENV_READY_FILE_PATH"

# Disconnect old_root
umount -l /old_root
rmdir /old_root
cd /workspace
echo "=== FINISHED: Pivot To New Root ==="




# Verify that Nix store path to start shell 
if [ -d "@startShellScriptShellWrapper_nixStorePath@" ]; then
    echo "@startShellScriptShellWrapper_nixStorePath@ directory exists!"
else
    echo "@startShellScriptShellWrapper_nixStorePath@ directory does not exist."
fi

echo "=== FINISHED: Switch Root Directory ==="





echo "=== Create System & Applicatoin Configuration Files ==="
# Container /etc/passwd and /etc/group      
cat <<EOF > "/etc/passwd"
root:x:0:0:root:/root:/bin/bash
$CONTAINER_USER_NAME:x:$CONTAINER_USER_UID:$CONTAINER_USER_GID:$CONTAINER_USER_NAME:/home/$CONTAINER_USER_NAME:/bin/bash
EOF

cat <<EOF > "/etc/group"
root:x:0:
$CONTAINER_USER_NAME:x:$CONTAINER_USER_GID:
EOF


# Container /etc/subuid and /etc/subgid
# NOTE: buildah needs both host namespace and unshare namespace subuid and subgid configured correctly
cat <<EOF > "/etc/subuid"
# This defines UID allocation for level 2 namespace from the perspective of level 1 namespace
# Level 0 namespace = host machine namespace
# Level 1 namespace = unshare namespace
# Level 2 namespace = buildah container namespace
root:1000:10000
EOF

cat <<EOF >  "/etc/subgid"
# This defines GID allocation for level 2 namespace from the perspective of level 1 namespace
# Level 0 namespace = host machine namespace
# Level 1 namespace = unshare namespace
# Level 2 namespace = buildah container namespace
root:1000:10000
EOF


# Container /etc/containers
mkdir -p "/etc/containers"

# /etc/containers/containers.conf
cat <<EOF > "/etc/containers/containers.conf"
[engine]
# Explicitly forces chroot behavior at the engine layer
isolation = "chroot"

# NOTE: need this for podman to working without systemd
cgroup_manager = "cgroupfs"
events_logger = "file"

# Strips the engine from trying to escalate or alter supplemental group privileges
infra_command = ""
EOF


# /etc/containers/storage.conf
# Create a local storage.conf to force Buildah to use the fuse-overlafs overlay driver
# (Standard overlayfs requires kernel mounts that bwrap blocks by default)
cat <<EOF > "/etc/containers/storage.conf"
[storage]
driver = "overlay"

# Temporary/Runtime State Directory      
runroot = "$INSIDE_NS_PATH_BUILDAH_RUN/runroot"

# Permanent Image & Layer Storage Directory
graphroot = "$INSIDE_NS_PATH_BUILDAH_RUN/graphroot"

# (Optional) Separate Image Cache vs. Container Layer content
imagestore = "$INSIDE_NS_PATH_BUILDAH_RUN/imagestore" 

[storage.options.overlay]
mount_program = "/usr/bin/fuse-overlayfs"
EOF


# /etc/containers/registries.conf
cat <<EOF > "/etc/containers/registries.conf"
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
cat <<EOF > "/etc/containers/policy.json"
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

mkdir -p "$INSIDE_NS_PATH_CONTAINER_USER_HOME/.config/opencode"
cat <<EOF > "$INSIDE_NS_PATH_CONTAINER_USER_HOME/.config/opencode/opencode.json"
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
echo "=== FINISHED: Create System & Application Configuration Files ==="





echo "=== Create Files For Future nsenter Sessions ==="
# quoting EOF to prevent Bash expansion
cat <<'EOF' >"$INSIDE_NS_PATH_CONTAINER_USER_HOME/.bash_profile"
#!/usr/bin/env bash

echo "Running script: ~/.bash_profile"

# If running bash, source the user's .bashrc if it exists
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
EOF


# NOTE: using unquoted EOF - therefore escape any $ that should not be expanded here 
cat <<EOF >"$INSIDE_NS_PATH_CONTAINER_USER_HOME/.bashrc"
#!/usr/bin/env bash
# Set PATH early to call programs like id
export PATH="$INSIDE_NS_ENV_VAR_PATH"

echo "Running script: ~/.bashrc"
echo "UID: \$(id -u)"
echo "GID: \$(id -g)"

# Used for every new interactive terminal session
export CONTAINER_RUNTIME=crun
export HOME="$INSIDE_NS_PATH_CONTAINER_USER_HOME"
export USER="$CONTAINER_USER_NAME"
export TEMP="/tmp"
export TEMPDIR="/tmp"
export TMP="/tmp"
export TMPDIR="/tmp"
export XDG_RUNTIME_DIR="/run/user/\$(id -u)"

if [[ ! -d "\$XDG_RUNTIME_DIR" ]]; then
	echo "Creating XDG_RUNTIME_DIR directory: \$XDG_RUNTIME_DIR"
	mkdir -p \$XDG_RUNTIME_DIR
	chmod 0700 \$XDG_RUNTIME_DIR
fi

# NOTE: source must precede usage of functions defined in functions.bash
source ~/functions.bash

# NOTE: escaped Bash expansion for TERM
TERM="\${TERM:-xterm-256color}"

# NOTE: escaped Bash expansion for get_git_prompt
PS1="\[\e[0;36m\][🤖 \u@\h]\[\e[0;33m\][\$(get_git_prompt)]\[\e[38;5;200m\][\w]\n\[\e[0;0m\]> "

# check for terminal window resizing
shopt -s checkwinsize
EOF

cat <<EOF >"$INSIDE_NS_PATH_CONTAINER_USER_HOME/.env"
EOF

# quoting EOF to prevent Bash expansion
cat <<'EOF' >"$INSIDE_NS_PATH_CONTAINER_USER_HOME/functions.bash"
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