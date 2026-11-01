#!/usr/bin/env bash

# Returns the raw numeric ID of a specific namespace type via a reference variable
get_namespace_id() {
    local -r ns_type=$1    # e.g., "cgroup", "ipc", "mnt", "net", "pid", "pid_for_children", "time", "time_for_children", "user", "uts"
    local -r out_var=$2    # The name of the variable to store the result in
    
    local ns_path="/proc/self/ns/$ns_type"
    local target inode
    
    if [ -e "$ns_path" ]; then
        target=$(readlink "$ns_path")
        
        # Strip the 'type:[' prefix and trailing ']'
        inode="${target#*[}"
        inode="${inode%]}"
        
        # Assign back to the variable name passed by reference
        eval "$out_var=\$inode"
    else
        # Return empty or handle missing namespace type (e.g., old kernels)
        eval "$out_var=''"
        return 1
    fi
}


get_namespace_id_test() {
	# Fetching a single specific namespace ID directly
	get_namespace_id "net" current_net_id
	echo "The current network namespace ID is: $current_net_id"

	get_namespace_id "user" current_user_id
	echo "The current user namespace ID is: $current_user_id"
}

