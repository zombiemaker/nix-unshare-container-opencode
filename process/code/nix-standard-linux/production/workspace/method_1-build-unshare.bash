#!/usr/bin/env bash
set -euo pipefail

# 1. Create an anonymous pipe for synchronization
# FD 3 = read end, FD 4 = write end
exec 3< <(file /dev/null) # Trick to allocate FDs cleanly
rm -f /tmp/slirp_ready.fifo
mkfifo /tmp/slirp_ready.fifo

echo "Starting orchestrator..."

# 2. Spawn unshare in the background
# We pass the write-end of the FIFO into unshare so it can wait for it
unshare --net --user --map-root-user bash -c '
    # Inside the unshare namespace
    echo "Namespace created. Waiting for slirp4netns to wire up the network..."
    
    # Block until slirp4netns writes to the FIFO
    read -r _ < /tmp/slirp_ready.fifo
    
    echo "Network is ready! Configuring internal routing..."
    # Perform internal iptables / proxy configurations here
    iptables -A OUTPUT -o lo -j ACCEPT
    iptables -A OUTPUT -p tcp -d 10.0.2.2 --dport 3128 -j ACCEPT
    iptables -A OUTPUT -j DROP
    
    export http_proxy="http://10.0.2.2:3128"
    export https_proxy="http://10.0.2.2:3128"
    
    # Hand over control to the interactive shell (retaining dropped caps if desired)
    exec capsh --drop=cap_net_admin -- -c '\''exec bash --rcfile <(echo "export PS1=\"[ns-sandbox] \\u@\\h:\\w\\$ \"") -i'\''
' &
UNSHARE_PID=$!

# 3. Give the background unshare process a brief instant to initialize its PID
until [ -d "/proc/$UNSHARE_PID" ]; do sleep 0.1; done

echo "Namespace PID is $UNSHARE_PID. Spawning slirp4netns in the background..."

# 4. Spawn slirp4netns in the background targeting the unshare process PID
# --ready-fd tells slirp4netns to write a token to FD 4 when the tap interface is live
slirp4netns \
    --configure \
    --mtu=65520 \
    --ready-fd=4 \
    "$UNSHARE_PID" \
    tap0 4> /tmp/slirp_ready.fifo &
SLIRP_PID=$!

# 5. Monitor and wait for the unshare process to finish
wait "$UNSHARE_PID"

# 6. Cleanup background slirp4netns and FIFO when the interactive shell exits
echo "Interactive shell exited. Cleaning up background tasks..."
kill "$SLIRP_PID" 2>/dev/null || true
rm -f /tmp/slirp_ready.fifo
