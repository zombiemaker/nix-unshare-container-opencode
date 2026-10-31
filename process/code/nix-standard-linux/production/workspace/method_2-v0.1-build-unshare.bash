#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="Level 0 namespace (host)"
script_name="$0"
echo "*************************************************************************"
echo "$NAMESPACE: running script: $script_name"
echo "$NAMESPACE: purpose: to start unshare namespace and setup environment outside of unshare namespace"
echo "$NAMESPACE: script arguments: $@"
echo "$NAMESPACE: current working directory: $PWD"
echo "$NAMESPACE: user name: $(whoami)"
echo "$NAMESPACE: PID: $$"
echo "$NAMESPACE: TMP: $TMP"

# network interface must match what is configured in /etc/nixos/configurations.nix
SLIRP4NETNS_HOST_NET_INTERFACE="slirp4netns_0"  # this is defined in /etc/nixos/configurations.nix

# Get first IP assigned to SLIRP4NETNS_HOST_NET_INTERFACE interface
if [ -n "$SLIRP4NETNS_HOST_NET_INTERFACE" ]; then
    SLIRP4NETNS_HOST_IPV4=$(ip -4 addr show $SLIRP4NETNS_HOST_NET_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
else
    echo "Error: No default network interface found." >&2
fi

echo "$NAMESPACE: SLIRP4NETNS_HOST_NET_INTERFACE: $SLIRP4NETNS_HOST_NET_INTERFACE"
echo "$NAMESPACE: SLIRP4NETNS_HOST_IPV4: $SLIRP4NETNS_HOST_IPV4"

# Random slirp4netns host forwarding port
SLIRP4NETNS_HOST_PORT_MIN=9500
SLIRP4NETNS_HOST_PORT_MAX=9999
SLIRP4NETNS_HOST_PORT_RANGE=$(( SLIRP4NETNS_HOST_PORT_MAX - SLIRP4NETNS_HOST_PORT_MIN + 1 ))

# Generate the random number for host port for port-forwarding
SLIRP4NETNS_HOST_PORT_1=$(( (RANDOM % SLIRP4NETNS_HOST_PORT_RANGE) + SLIRP4NETNS_HOST_PORT_MIN ))
echo "$NAMESPACE: SLIRP4NETNS_HOST_PORT_1 = $SLIRP4NETNS_HOST_PORT_1"
SLIRP4NETNS_NS_PORT_1=9500
echo "$NAMESPACE: SLIRP4NETNS_NS_PORT_1 = $SLIRP4NETNS_NS_PORT_1"

# TODO: change from single to multiple ip:port
SLIRP4NETNS_FW_ALLOWED_DEST_1_IP="192.168.1.90"
echo "$NAMESPACE: SLIRP4NETNS_FW_ALLOWED_DEST_1_IP = $SLIRP4NETNS_FW_ALLOWED_DEST_1_IP"
SLIRP4NETNS_FW_ALLOWED_DEST_1_PORT="9943"
echo "$NAMESPACE: SLIRP4NETNS_FW_ALLOWED_DEST_1_PORT = $SLIRP4NETNS_FW_ALLOWED_DEST_1_PORT"
SLIRP4NETNS_LOG_FILE_NAME="$TMP/slirp4netns-$SRANDOM.log"
echo "$NAMESPACE: SLIRP4NETNS_LOG_FILE_NAME: $SLIRP4NETNS_LOG_FILE_NAME"

# Create a unique named pipe on the host for synchronization handshake
SLIRP4NETNS_FIFO_PATH="/tmp/slirp4netns_ready_$$.fifo"
mkfifo "$SLIRP4NETNS_FIFO_PATH"
echo "$NAMESPACE: SLIRP4NETNS_FIFO_PATH: $SLIRP4NETNS_FIFO_PATH"

# Create a unique named pipe on the host for sending-receiving slirp4netns api commands
SLIRP4NETNS_API_SOCKET="/tmp/slirp4netns_api_$$.sock"
echo "$NAMESPACE: SLIRP4NETNS_API_SOCKET: $SLIRP4NETNS_API_SOCKET"
echo "*************************************************************************"



# Ensure cleanup on host script exits
cleanup() {
    rm -f "$SLIRP4NETNS_FIFO_PATH"
}
trap cleanup EXIT

log_msg() {
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

echo "[Host] Preparing background supervisor loop..."

# Spawn a background monitoring loop on the host.
(
    if read -r UNSHARE_PID < "$SLIRP4NETNS_FIFO_PATH"; then
        echo "[Host Background] Captured Namespace PID: $UNSHARE_PID"
        
        # Start slirp4netns and redirect the ready token into the FIFO
		exec slirp4netns \
			--configure \
			--mtu=65520 \
			--ready-fd=4 \
			--disable-host-loopback \
			--outbound-addr="$SLIRP4NETNS_HOST_IPV4" \
			--api-socket="$SLIRP4NETNS_API_SOCKET" \
			"$UNSHARE_PID" \
			tap0 4> "$SLIRP4NETNS_FIFO_PATH"
    fi	
) &

SLIRP_PID=$!
log_msg "[Host] SLIRP_PID: $SLIRP_PID"
log_msg "[Host] Handing over current terminal session to unshare..."

# Execute unshare in the FOREGROUND, replacing the host script process
exec unshare \
	--user \
	--cgroup \
	--ipc \
	--mount \
	--net \
	--pid \
	--time \
	--uts \
	--fork \
	--map-root-user \
	--map-users auto \
	--map-groups auto \
	bash -c '
    # Send our unshare PID to the background host loop to kick off slirp4netns
    # Determine our TRUE host-side PID by reading field 4 (PPID) of /proc/self/stat.
    # The parent of this shell is the unshare wrapper process, whose host PID is intact.
    TRUE_PID=$(cut -d" " -f4 /proc/self/stat)
    
    # Send the true host PID to the supervisor
    echo "$TRUE_PID" > '"$SLIRP4NETNS_FIFO_PATH"'
    
    # Block here until slirp4netns writes its readiness token back into the FIFO
    read -r _ < '"$SLIRP4NETNS_FIFO_PATH"'
    
	# NOTE: This has to be executed after UNSHARE_PID has been sent; otherwise, deadlock
	# Wait briefly for the slirp4netns API socket to be created
	until [ -S '"$SLIRP4NETNS_API_SOCKET"' ]; do sleep 0.5; done

	# Send JSON command to the API socket to configure the port forward
	echo "[Host Background] Configuring port forward: Host '$SLIRP4NETNS_HOST_PORT_1' -> NS '$SLIRP4NETNS_NS_PORT_1'"
	echo "{\"execute\": \"add_hostfwd\", \"arguments\": {\"proto\": \"tcp\", \"host_addr\": \"0.0.0.0\", \"host_port\": '$SLIRP4NETNS_HOST_PORT_1', \"guest_addr\": \"10.0.2.100\", \"guest_port\": '$SLIRP4NETNS_NS_PORT_1'}}" | nc -U '"$SLIRP4NETNS_API_SOCKET"' > /dev/null


    # Network is now live. Configure namespace firewalls & proxies.
    # iptables -A OUTPUT -o lo -j ACCEPT
    # iptables -A OUTPUT -p tcp -d 10.0.2.2 --dport 3128 -j ACCEPT
    # iptables -A OUTPUT -j DROP
    
    # export http_proxy="http://10.0.2.2:3128"
    # export https_proxy="http://10.0.2.2:3128"
    
    # D. Inject the custom prompt via environment variables instead of --rcfile
    export PROMPT_COMMAND='\''PS1="[ns-restricted] \u@\h:\w\$ "'\''
    
    echo "========================================================="
    echo " Sandboxed Namespace Environment Securely Initialized "
    echo "========================================================="
    
    # E. Drop CAP_NET_ADMIN and execute bash interactively
    exec setpriv --ambient-caps=-net_admin --bounding-set=-net_admin bash -i
'
