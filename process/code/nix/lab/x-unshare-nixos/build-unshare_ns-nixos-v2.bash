#!/usr/bin/env bash

echo "Script to experiment with unshare and mounting /proc"

set -euo pipefail
echo "whoami outside namespace: $(whoami) (UID: $(id -u))"


echo "=== Define Script To Run Inside Namespace ==="
container_commands() {
	set -euo pipefail
	echo "whoami inside namespace: $(whoami) (UID: $(id -u))"

	if [[ ! -v TARGET_CONTAINER_MOUNT ]]; then
		echo "Error: undefined TARGET_CONTAINER_MOUNT"
		exit 1
	elif [[ -z "$TARGET_CONTAINER_MOUNT" ]]; then
    	echo "Error: TARGET_CONTAINER_MOUNT is set but empty"
    	exit 1
	else
		echo "TARGET_CONTAINER_MOUNT: $TARGET_CONTAINER_MOUNT"
	fi
	
	# TARGET_NIX_STORE_PATHS should be 
	if [[ ! -v TARGET_NIX_STORE_PATHS ]]; then
		echo "Error: undefined TARGET_NIX_STORE_PATHS"
		exit 1
	elif [[ -z "$TARGET_NIX_STORE_PATHS" ]]; then
    	echo "Error: TARGET_NIX_STORE_PATHS is set but empty"
    	exit 1
	else
		echo "TARGET_NIX_STORE_PATHS: $TARGET_NIX_STORE_PATHS"
	fi


	echo "=== Initialize Container Root At $TARGET_CONTAINER_MOUNT ==="
	# IMMEDIATELY make the mount space private before any mount operations
	mount --make-rprivate /
	mount -t tmpfs -o exec,mode=0755 tmpfs $TARGET_CONTAINER_MOUNT
	mount --make-private $TARGET_CONTAINER_MOUNT
	mkdir -p $TARGET_CONTAINER_MOUNT/{dev,proc,sys,bin,etc,home,nix/store,run,tmp,usr/bin,workspace}
	echo "=== FINISHED: Initialize Container Root At $TARGET_CONTAINER_MOUNT ==="

	echo "=== Mount Container /nix/store Directories ==="
	# Loop through the pre-built paths passed from the host environment
	# Loop through the paths and create target directories
	IFS=',' read -ra PATHS <<< "$TARGET_NIX_STORE_PATHS"
	for target_nix_store_path in "${PATHS[@]}"; do
		if [ -z "$target_nix_store_path" ]; then
			echo "Error: Empty target_nix_store_path value"
			exit 1
		fi

		# Extract just the folder name (e.g., "abcdef...-my-package")
		TARGET_CONTAINER_MOUNT_NIX_STORE_PATH="${TARGET_CONTAINER_MOUNT}${target_nix_store_path}"
		
		echo "Creating directory: $TARGET_CONTAINER_MOUNT_NIX_STORE_PATH"
		mkdir -p "$TARGET_CONTAINER_MOUNT_NIX_STORE_PATH"

		echo "mounting $target_nix_store_path"
		mount --bind $target_nix_store_path $TARGET_CONTAINER_MOUNT_NIX_STORE_PATH

	done
	echo "=== FINISHED: Mount Container /nix/store Directories ==="

	echo "=== Mount Container System Directories ==="
	mount -t proc proc "$TARGET_CONTAINER_MOUNT/proc"
	ls -la "$TARGET_CONTAINER_MOUNT/proc"

	# NOTE: to mount sys need "unshare --net" option
	mount -t sysfs sys "$TARGET_CONTAINER_MOUNT/sys"
	mount -t tmpfs dev "$TARGET_CONTAINER_MOUNT/dev"
	echo "=== FINISHED: Mount Container System Directories ==="


	echo "=== Pivot To New Root ==="
	# Switch root
	cd $TARGET_CONTAINER_MOUNT
	mkdir -p $TARGET_CONTAINER_MOUNT/old_root
	# pivot_root . ./old_root
	# umount -l /old_root/proc
	# umount -l /old_root/sys
	# umount -l /old_root
	# rmdir ./old_root
	# mount -t proc proc /proc
	# cd /
	echo "=== FINISHED: Pivot To New Root ==="

	# start interactive bash
	# NOTE: "--login" forces Bash to re-read its true namespace PID from the kernel!
	exec bash --login --noprofile
}
echo "=== FINISHED: Define Script To Run Inside Namespace ==="



echo "=== Perform Work Outside Namespace ==="
echo "--- Build nixpkgs derivations and generate list of nix store paths ---"
TARGET_NIX_DRVS=(
	"nixpkgs#bashInteractive"
	"nixpkgs#coreutils"
	"nixpkgs#mount"
	"nixpkgs#umount"
	"nixpkgs#which"
	"nixpkgs#busybox"
)

# BUILD FIRST: Ensure paths exist in the store before querying them
# Passing the attributes directly to 'nix build' is faster and safer than building via '.drv' inputs
nix build --no-link "${TARGET_NIX_DRVS[@]}"

# QUERY ONCE: Capture the full runtime closure store paths into an array
readarray -t TARGET_NIX_DRVS_CLOSURE_NIX_STORE_PATHS < <(nix path-info --recursive "${TARGET_NIX_DRVS[@]}")

# Check if Nix actually returned any paths
if [ ${#TARGET_NIX_DRVS_CLOSURE_NIX_STORE_PATHS[@]} -eq 0 ]; then
    echo "Error: No Nix store paths were returned." >&2
    exit 1
fi

echo "~~~ Items in TARGET_NIX_DRVS_CLOSURE_NIX_STORE_PATHS ~~~"
printf '%s\n'  "${TARGET_NIX_DRVS_CLOSURE_NIX_STORE_PATHS[@]}"
echo "~~~ FINISHED: Items in TARGET_NIX_DRVS_CLOSURE_NIX_STORE_PATHS ~~~"

# DERIVE NAMES LOCALLY: Process the local array instead of making another slow external Nix call
TARGET_NIX_DRVS_CLOSURE_NAMES=()
for path in "${TARGET_NIX_DRVS_CLOSURE_NIX_STORE_PATHS[@]}"; do
    # Extract basename and strip the hash prefix using pure Bash or simple piping
    base_name=$(basename "$path")
    clean_name=${base_name#*-}
    TARGET_NIX_DRVS_CLOSURE_NAMES+=("$clean_name")
done

echo "~~~ Items in TARGET_NIX_DRVS_CLOSURE_NAMES ~~~"
printf '%s\n' "${TARGET_NIX_DRVS_CLOSURE_NAMES[@]}"
echo "~~~ FINISHED: Items in TARGET_NIX_DRVS_CLOSURE_NAMES ~~~"

echo "--- FINISHED: Build nixpkgs derivations and generate list of nix store paths ---"


echo "--- Build Container PATH Environment Variable ---"
CONTAINER_ENV_VAR_PATH=""
for nix_store_path in "${TARGET_NIX_DRVS_CLOSURE_NIX_STORE_PATHS[@]}"; do
	if [[ -d "$nix_store_path/bin" ]]; then
		echo "Adding to container PATH: $nix_store_path/bin"
		CONTAINER_ENV_VAR_PATH="$nix_store_path/bin:$CONTAINER_ENV_VAR_PATH"
	fi
done

# Strip trailing colon if necessary
CONTAINER_ENV_VAR_PATH=${CONTAINER_ENV_VAR_PATH%:}
echo "--- Build Container PATH Environment Variable ---"

echo "--- Create host namespace directory to mount container root directory ---"
HOST_PATH_CONTAINER_MOUNT="./mnt"
[[ -d $HOST_PATH_CONTAINER_MOUNT ]] || mkdir -p $HOST_PATH_CONTAINER_MOUNT
echo "--- FINISHED: Create host namespace directory to mount container root directory ---"

echo "=== FINISHED: Perform Work Outside Namespace ==="


echo "=== Execute unshare ==="
export -f container_commands
unshare \
	--user \
	--map-root-user \
	--pid \
	--mount \
	--net \
	--ipc \
	--uts \
	--fork \
	--mount-proc \
	env -i \
		PATH="$CONTAINER_ENV_VAR_PATH" \
		TERM="${TERM:-xterm-256color}" \
		PS1="\[\e[0;36m\][🤖 \u@\h]\[\e[38;5;200m\][\w]\[\e[0;33m\][no-git-script]\n\[\e[0;0m\]> " \
		TARGET_CONTAINER_MOUNT=$(realpath "$HOST_PATH_CONTAINER_MOUNT") \
		TARGET_NIX_STORE_PATHS=$(IFS=,; echo "${TARGET_NIX_DRVS_CLOSURE_NIX_STORE_PATHS[*]}") \
		bash -c "$(declare -f container_commands); container_commands"

echo "=== FINISHED: Execute unshare ==="