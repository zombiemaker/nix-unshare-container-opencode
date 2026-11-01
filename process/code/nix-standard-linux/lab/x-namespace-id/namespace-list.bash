#!/usr/bin/env bash

# Declare associative array globally
declare -A namespaces

get_current_namespaces() {
    local -r dest_map=$1
    local ns target ns_name inode
    
    for ns in /proc/self/ns/*; do
        if [ -e "$ns" ]; then
            # Extract the namespace type (e.g., 'mnt')
            ns_name="${ns##*/}"
            
            # Read the symlink target (e.g., 'mnt:[4026531840]')
            target=$(readlink "$ns")
            
            # Strip the 'type:[' prefix
            inode="${target#*[}"
            # Strip the trailing ']'
            inode="${inode%]}"
            
            # Dynamically assign the clean numeric value to the global map
            declare -g "${dest_map}[$ns_name]=$inode"
        fi
    done
}

# Usage: Pass the name of the map (without the '$')
get_current_namespaces namespaces

# Example: Iterating over the map to view keys and values
for type in "${!namespaces[@]}"; do
    echo "$type -> ${namespaces[$type]}"
done