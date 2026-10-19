#!/usr/bin/env bash

# prerequisites:
# - user running script has privilege to use mapped user and group ID ranges
# - no other process is using the same set of mapped user and group ID ranges

# --user
#   unshare user namespace
# --map-users <inner_uid>:<outer_uid>:<count>
#   • inner_uid: The starting UID inside the new namespace.
#   • outer_uid: The starting UID on the host system.
#   • count: How many consecutive UIDs to map in this block
#   • auto: will map the first block of user IDs owned by the effective user from /etc/subuid to a block starting at user ID 0.
unshare \
    --user \
    --map-users 100000:100000:65536 \
    --map-groups 100000:100000:65536 \
    --fork \
    --kill-child \
    sleep 15 &

# get the PID of the unshare process
UNSHARE_PID=$!

# Give the process a brief millisecond to initialize
sleep 0.1


# NOTE: THIS IS NOT NEEDED BECAUSE the unshare command created a mapping of users and group
# Get the host UID and GID of the running harness user
# HOST_UID=$(id -u)
# HOST_GID=$(id -g)

# Provision the full sub-UID range into the new namespace via the host's setuid helpers
# (Assuming your NixOS subuid starts at 100000 with a count of 65536)
# newuidmap - set the uid mapping of a user namespace
# newuidmap <PID> <TARGET_NAMESPACE_START_UID> <HOST_NAMESPACE_START_UID> <COUNT_OF_UIDS_TO_MAP>
#   • <PID>: prodess ID for target namespace
#   • <TARGET_NAMESPACE_START_UID>: UID range start UID value within target namespace to map
#   • <HOST_NAMESPACE_START_UID>:  UID range start UID value within host namespace to map
#   • <COUNT_OF_UIDS_TO_MAP>: number of UIDs to map
# newuidmap $UNSHARE_PID 0 100000 65536
# newgidmap $UNSHARE_PID 0 100000 65536

# Open a dedicated File Descriptor pointing directly to the configured namespace
# Bash automatically assigns an available FD number to the variable UNSHARE_NAMESPACE_FILE_DESCRIPTOR
exec {UNSHARE_NAMESPACE_FILE_DESCRIPTOR}< /proc/$UNSHARE_PID/ns/user
echo "Bash-assigned file descriptor: $UNSHARE_NAMESPACE_FILE_DESCRIPTOR"

# run bwrap using file descriptor pointing to namespace
bwrap \
    --userns $UNSHARE_NAMESPACE_FILE_DESCRIPTOR \
    --proc /proc \
    --unshare-pid \
    --cap-add CAP_SYS_ADMIN \
    --cap-add CAP_SETUID \
    --cap-add CAP_SETGID \
    --cap-add CAP_SYS_CHROOT \
    --dev-bind /dev/fuse /dev/fuse \
    /bin/sh -c "
        export BUILDAH_ISOLATION=chroot
        export BUILDAH_DRIVER=vfs
        echo 'Now inside secure bwrap container with a fully mapped subuid user namespace!'
        buildah info
    "

# BUG: this is not killing the process
# echo "Killing unshare process $UNSHARE_PID"
# kill $UNSHARE_PID

echo "Closing file descriptor $UNSHARE_NAMESPACE_FILE_DESCRIPTOR"
exec {UNSHARE_NAMESPACE_FILE_DESCRIPTOR}<&-