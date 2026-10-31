#!/usr/bin/env bash
set -euo pipefail

# 1. Create a unique named pipe on the host for the synchronization handshake
FIFO_PATH="/tmp/slirp_ready_$$.fifo"
mkfifo "$FIFO_PATH"

# Ensure cleanup on host script exits
cleanup() {
    rm -f "$FIFO_PATH"
}
trap cleanup EXIT

echo "[Host] Preparing background supervisor loop..."

# 2. Spawn a background monitoring loop on the host.
(
    if read -r UNSHARE_PID < "$FIFO_PATH"; then
        echo "[Host Background] Captured Namespace PID: $UNSHARE_PID"
        
        # Start slirp4netns and redirect the ready token into the FIFO
        exec slirp4netns \
            --configure \
            --mtu=65520 \
            --ready-fd=4 \
            "$UNSHARE_PID" \
            tap0 4> "$FIFO_PATH"
    fi
) &

echo "[Host] Handing over current terminal session to unshare..."

# Execute unshare in the FOREGROUND, replacing the host script process
# NOTE: This works because it is not using --pid and --fork option
exec unshare --net --user --map-root-user bash -c '
    # Send our own PID to the background host loop to kick off slirp4netns
    echo "$$" > '"$FIFO_PATH"'
    
    # Block here until slirp4netns writes its readiness token back into the FIFO
    read -r _ < '"$FIFO_PATH"'
    
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
