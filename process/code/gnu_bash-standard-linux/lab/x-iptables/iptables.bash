gid=1500
ip="192.168.1.90"
port="9943"

iptables -N SANDBOX_OUTPUT
iptables -I OUTPUT -j SANDBOX_OUTPUT
iptables -A SANDBOX_OUTPUT -m owner --gid-owner "$gid" -d "$ip" -p tcp --dport "$port" -j ACCEPT
iptables -A SANDBOX_OUTPUT -m owner --gid-owner "$gid" -j DROP