#!/usr/bin/env bash

echo "Script to experiment with unshare and mounting /proc"

set -euo pipefail
echo "whoami outside namespace: $(whoami) (UID: $(id -u))"


echo "=== Define Script To Run Inside Namespace ==="
container_commands() {
	set -euo pipefail
	echo "whoami inside namespace: $(whoami) (UID: $(id -u))"

	if [ ! -v "$TARGET_CONTAINER_MOUNT"]; then
		echo "Error: undefined TARGET_CONTAINER_MOUNT"
		exit 1
	elsif
		echo "TARGET_CONTAINER_MOUNT: $TARGET_CONTAINER_MOUNT"
	fi
	
	# TARGET_NIX_STORE_PATHS should be 
	if [ ! -v "$TARGET_NIX_STORE_PATHS"]; then
		echo "Error: undefined TARGET_NIX_STORE_PATHS"
		exit 1
	elsif
		echo "TARGET_NIX_STORE_PATHS: $TARGET_NIX_STORE_PATHS"
	fi


	mount -t tmpfs -o exec,mode=0755 tmpfs $TARGET_CONTAINER_MOUNT
	mount --make-private $TARGET_CONTAINER_MOUNT  # this might be an issue for "nix build"
	mkdir -p $TARGET_CONTAINER_MOUNT/{dev,proc,sys,bin,etc,home,nix/store,run,tmp,usr/bin,workspace}

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

	# Switch root
	cd $TARGET_CONTAINER_MOUNT
	mkdir -p $TARGET_CONTAINER_MOUNT/old_root
	pivot_root . ./old_root
	mount -t proc proc /proc
	cd /

	# start interactive bash
	bash --norc --noprofile
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

# "nix path-info" produces a string of newline-separated strings NOT AN ARRAY
# convert into Bash array
readarray -t TARGET_NIX_DRVS_CLOSURE_NAMES < <(nix path-info --recursive "${TARGET_NIX_DRVS[@]}" | xargs -n1 basename | sed -E 's/^[0-9a-z]+-//')
echo "~~~ Items in TARGET_NIX_DRVS_CLOSURE_NAMES ~~~"
printf '%s\n' "${TARGET_NIX_DRVS_CLOSURE_NAMES[@]}"
echo "~~~ FINISHED: Items in TARGET_NIX_DRVS_CLOSURE_NAMES ~~~"

# Nix store path of all target packages and their runtime dependency packages
readarray -t TARGET_NIX_DRVS_CLOSURE_NIX_STORE_PATHS < <(nix path-info --recursive "${TARGET_NIX_DRVS[@]}")
echo "~~~ Items in TARGET_NIX_DRVS_CLOSURE_NIX_STORE_PATHS ~~~"
printf '%s\n'  "${TARGET_NIX_DRVS_CLOSURE_NIX_STORE_PATHS[@]}"
echo "~~~ FINISHED: Items in TARGET_NIX_DRVS_CLOSURE_NIX_STORE_PATHS ~~~"


# Check if Nix actually returned any paths
if [ ${#TARGET_NIX_DRVS_CLOSURE_NIX_STORE_PATHS[@]} -eq 0 ]; then
    echo "Error: No Nix store paths were returned." >&2
    exit 1
fi

# Build target packages and their runtime dependency packages
nix build --no-link $(nix path-info --recursive --derivation "${TARGET_NIX_DRVS[@]}")
echo "--- FINISHED: Build nixpkgs derivations and generate list of nix store paths ---"


echo "--- Build Container PATH Environment Variable ---"
CONTAINER_ENV_VAR_PATH=""
for nix_store_path in "${TARGET_NIX_DRVS_CLOSURE_NIX_STORE_PATHS[@]}"; do
	if [[ -d "$nix_store_path/bin" ]]; then
		echo "Adding to container PATH: $nix_store_path/bin"
		CONTAINER_ENV_VAR_PATH="$nix_store_path/bin:$CONTAINER_ENV_VAR_PATH"
	fi
done
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
	--fork \
	env -i \
		PATH="$CONTAINER_ENV_VAR_PATH" \
		TERM="${TERM:-xterm-256color}" \
		PS1="\[\e[0;36m\][🤖 \u@\h]\[\e[38;5;200m\][\w]\[\e[0;33m\][no-git-script]\n\[\e[0;0m\]> " \
		TARGET_CONTAINER_MOUNT=$(realpath "$HOST_PATH_CONTAINER_MOUNT") \
		TARGET_NIX_STORE_PATHS=$(IFS=,; echo "${TARGET_NIX_DRVS_CLOSURE_NIX_STORE_PATHS[*]}") \
		bash -c "$(declare -f container_commands); container_commands"
echo "=== FINISHED: Execute unshare ==="