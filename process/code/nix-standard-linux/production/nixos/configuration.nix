# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?

  # Bootloader
  boot = {
    loader.systemd-boot = {
      enable = true;
      configurationLimit = 5;
      memtest86.enable = true;
    };

    loader.efi.canTouchEfiVariables = true;

    # Use latest kernel.
    kernelPackages = pkgs.linuxPackages_6_18;

    binfmt.emulatedSystems = [
      "aarch64-linux"
      # "arm-linux"
      # "riscv32-linux"
      # "riscv64-linux"
      "wasm32-wasi"
      "wasm64-wasi"
      "x86_64-windows"
    ];
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      rocmPackages.clr
      rocmPackages.rocm-runtime
    ];
  };

  boot.initrd.kernelModules = [ "amdgpu" ]; # 20260917 removed NVIDIA GPU

  networking = {
    hostName = "dtpc-2025-0"; # Define your hostname
    interfaces = {
      wlp4s0 = {
        useDHCP = true;
      };
    };

    wireless = {
      enable = true;
      userControlled = true;

      secretsFile = "/etc/nixos/secrets/wifi-wpa-supplicant.conf";
      networks = {
        nknet = {
          authProtocols = [
            "SAE" # WPA3 personal only
          ];
          pskRaw = "ext:nknet_psk"; # works - file contains human-readable passphrase for WPA3
        };
      };

      interfaces = [
        "wlp4s0"
      ];
    };

    firewall = {
      # Disable the firewall
      # enable = false;
      allowPing = true;
      allowedTCPPorts = [
        22 # OpenSSH
        6443 # Kubernetes API server for K3s
      ];

      # slirp4netns port ranges
      allowedTCPPortRanges = [
        {
          from = 9500;
          to = 9999;
        }
      ];

      allowedUDPPorts = [
        # 8472 # required if K3s is joining other K3s nodes
      ];
    };
  };

  # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalisation properties.
  i18n = {
    defaultLocale = "en_US.UTF-8";

    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };

  security.unprivilegedUsernsClone = true;

  nix = {
    settings = {
      # Activates Nix experimental features at root/system-level not user level
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.rocmSupport = true; # 20260917 removed NVIDIA GPU

  # Select Nixpkgs to allowUnfree
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
    ];

  # List packages installed in system profile. To search, run:
  environment = {
    systemPackages = with pkgs; [
      git # for Nix Flakes
      git-lfs
      wget
      neovim
      nixd # language server for nix language
      tmux
      powershell
      stow # For dotfiles
      nixfmt # For Nix code development
      nixd # for Nix code development
      # cudaPackages.cudatoolkit # 20260917 removed NVIDIA GPU

      qemu
      bubblewrap # for container
      slirp4netns # for bridging between host network namespace and unshare network namespace
      podman-compose # compose podman container (podman NixOS feature activated)
      buildah
      skopeo
      kubectl
      k9s
    ];

    variables.EDITOR = "nvim";
    variables.HSA_OVERRIDE_GFX_VERSION = "11.0.0"; # 20260917 removed NVIDA GPU
  };

  # Enable the libvirt daemon
  virtualisation.libvirtd.enable = true;

  # Enable containerization using Podman
  virtualisation.podman = {
    enable = true;
    dockerCompat = true; # Creates a symlink from docker to podman
    defaultNetwork.settings.dns_enabled = true; # Required for containers under podman-compose to be able to talk to each other.
  };

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver = {
    enable = true;
    videoDrivers = [ "amdgpu" ];

    # Configure keymap in X11
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;

    settings = {
      # (dis)allow password authentication
      PasswordAuthentication = true;

      # (dis)allow root user login
      PermitRootLogin = "no";
    };

    # specify TCP port for daemon process to listen for incoming SSH client connections
    ports = [
      22
    ];
  };

  # Enable K3s
  services.k3s = {
    enable = true;
    role = "server";
    # Optional: Pass specific arguments to K3s (e.g., disabling Traefik if you prefer Nginx)
    # extraFlags = "--disable=traefik";
  };

  # This with slirp4netns is for sandboxing AI agents within a Linux namespace to restrict
  # destination network access that AI agents might try to connect to. Firewall rules should
  # direct traffic to a proxy server like mitmproxy to enable surveillance of traffic from AI
  # agents.  This service limits the types of iptables commands that non-root users configuring
  # slirp4netns can use.
  # Define the custom group
  users.groups.sbx-slirp4netns-fw = {
    name = "sbx-slirp4netns-fw";
    # Optional: Explicitly set a static GID if needed for shared file permissions
    gid = 1500;
  };

  # To view logs: journalctl -u sbx-slirp4netns-fw-daemon -f
  # To view iptables: sudo iptables -L -n -v --line-numbers
  systemd.services.sbx-slirp4netns-fw-daemon =
    let
      net_iface_device_name = "slirp4netns_0";

      # address pool that slirp4netns can bind to
      net_iface_ipv4_cidr_addr_pool = [
        "10.99.99.1/24"
        "10.99.99.2/24"
        "10.99.99.3/24"
        "10.99.99.4/24"
      ];

      iptables_chain_name = "SBX_SLIRP4NETNS_FW_OUTPUT";

      # Compile the worker logic into its own isolated store path script
      fw-worker = pkgs.writeShellScriptBin "sbx-fw-worker" ''
        PATH="${pkgs.which}/bin:${pkgs.iptables}/bin:${pkgs.gawk}/bin:$PATH"

        # Helper function to send logs directly to systemd journal
        log_msg() {
            # echo "$1" | systemd-cat -t sbx-slirp4netns-fw

            # Bypasses the socket and logs cleanly to systemd as "my-service-name"
            echo "$1" >&2
        }

        log_warn() {
            # echo "$1" | systemd-cat -t sbx-slirp4netns-fw -p warning

            # Bypasses the socket and logs cleanly to systemd as "my-service-name"
            echo "$1" >&2
        }

        parse_line() {
            local line="$1"
            if [[ "$line" =~ $regex ]]; then
                local pid="''${BASH_REMATCH[1]}"
                local gid="''${BASH_REMATCH[2]}"
                local src_ip="''${BASH_REMATCH[3]}"
                local action=""
                

                # Determine which branch matched to find the action
                if [[ -n "''${BASH_REMATCH[5]}" ]]; then
                    action="''${BASH_REMATCH[5]}" # ACCEPT
                    local dest_ip="''${BASH_REMATCH[6]}"
                    
                    # Extract and force the protocol to lowercase
                    local raw_proto="''${BASH_REMATCH[7]}"
                    local proto="''${raw_proto,,}" 
                    
                    # dest_port is empty if proto is icmp
                    local dest_port="''${BASH_REMATCH[8]}"

                    ACCEPT_RULE=""
                    if [[ "$proto" == "icmp" ]]; then
                        log_msg "(fw-worker) proto = icmp"
                        ACCEPT_RULE="${iptables_chain_name} -s $src_ip -d $dest_ip -p $proto -j ACCEPT"
                    fi

                    if [[ ("$proto" == "tcp") || ("$proto" == "udp") ]]; then
                        log_msg "(fw-worker) proto = $proto"
                        ACCEPT_RULE="${iptables_chain_name} -s $src_ip -d $dest_ip -p $proto --dport $dest_port -j ACCEPT"
                    fi
                    
                    log_msg "Matched: Action=$action -> Target: $dest_ip over $proto:$dest_port"
                    
                    if ! iptables -C $ACCEPT_RULE 2>/dev/null; then
                      log_msg "(fw-worker) Executing command: iptables -A $ACCEPT_RULE"                        
                      iptables -A $ACCEPT_RULE
                      exitcode=$?
                      
                      if [ $exitcode -eq 0 ]; then
                        log_msg "SUCCESS: Added rule '$ACCEPT_RULE'"
                      elif [ $exitcode -eq 1 ]; then
                        log_msg "ERROR: General Error"
                      else
                        log_msg "ERROR: Other"
                      fi
                    else
                      log_msg "(fw-worker) Rule already exists"
                    fi

                    # Send text to caller
                    echo "SUCCESS"
                    exit 0
                else
                    # DROP_ALL or DELETE_ALL
                    action="''${BASH_REMATCH[9]}"

                    if [ "$action" = "DROP_ALL" ]; then
                      log_msg "Matched: Action=$action"
                      DROP_ALL_RULE="${iptables_chain_name} -s $src_ip -j DROP"

                      if ! iptables -C $DROP_ALL_RULE 2>/dev/null; then
                        log_msg "(fw-worker) Executing command: iptables -A $DROP_ALL_RULE"
                        iptables -A $DROP_ALL_RULE
                        log_msg "SUCCESS: Added rule '$DROP_ALL_RULE'"
                      else
                        log_msg "(fw-worker) Rule already exists"
                      fi
                    elif [ "$action" = "DELETE_ALL" ]; then
                      log_msg "Matched: Action=$action"

                      # Verify that the specific target chain exists before proceeding
                      if ! iptables -S ${iptables_chain_name} &>/dev/null; then
                        log_msg "Error: Chain ${iptables_chain_name} does not exist." >&2
                        exit 1
                      fi

                      echo "Removing iptables rules from chain ${iptables_chain_name} matching source IP: $src_ip"

                      # Loop to find and delete matching rules by line number in reverse order.
                      # Reversing the order ensures line number indices do not shift for subsequent deletions.
                      LINE_NUMBERS=$(iptables -nL "${iptables_chain_name}" --line-numbers | grep -E "\b''${src_ip}\b" | awk '{print $1}' | sort -rn)

                      if [ -z "$LINE_NUMBERS" ]; then
                        log_msg "No matching rules found for $src_ip in chain ${iptables_chain_name}."
                        exit 0
                      fi

                      for line in $LINE_NUMBERS; do
                        if iptables -D "${iptables_chain_name}" "$line"; then
                          log_msg "Successfully deleted rule #$line from chain ${iptables_chain_name}"
                        fi
                      done

                    else
                      log_msg "No match: Action=$action"  
                      exit 1
                    fi

                    # Send text to caller
                    echo "SUCCESS"
                    exit 0
                fi
            else
                log_warn "Line failed validation."
                exit 1
            fi
        }

        # Wait for input from socat
        read -r input
        log_msg "(fw-worker) input: $input"

        # Array Index	Regex Pattern   Component	                                        Description / Extracted Value
        # ''${BASH_REMATCH[0]}	      (Entire Pattern)	                                The complete matched log line
        # ''${BASH_REMATCH[1]}	      ([0-9]+)	                                        First metric (e.g., Packet Count)
        # ''${BASH_REMATCH[2]}	      ([0-9]+)	                                        Second metric (e.g., Byte Count)
        # ''${BASH_REMATCH[3]}	      ([0-9.]+)	                                        Source identifier / Timestamp
        # ''${BASH_REMATCH[4]}	      ((ACCEPT) ... | (DROP_ALL|...))	                  The entire trailing action block
        # ''${BASH_REMATCH[5]}	      (ACCEPT)	                                        The literal string "ACCEPT" (Empty if Branch B)
        # ''${BASH_REMATCH[6]}	      ([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})  The destination IPv4 address (Empty if Branch B)
        # ''${BASH_REMATCH[7]}	      ([tT][cC][pP]|[uU][dD][pP]|[iI][cC][mM][pP])	    The network protocol (TCP, UDP, or ICMP) (Empty if Branch B)
        # ''${BASH_REMATCH[8]}	      ( +[0-9]+)?	                                      The trailing space and port number (Empty if ICMP or Branch B)
        # ''${BASH_REMATCH[9]}	      (DROP_ALL|DELETE_ALL)	                            The global drop/delete keyword (Empty if Branch A)

        regex='^([0-9]+) +([0-9]+) +([0-9.]+) +((ACCEPT) +([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}) +([tT][cC][pP]|[uU][dD][pP]|[iI][cC][mM][pP])( +[0-9]+)?|(DROP_ALL|DELETE_ALL))$'

        parse_line "$input"
        exit 0
      '';
    in {
      description = "Sandbox slirp4netns Firewall Control Daemon";
      wantedBy = [ "multi-user.target" ];
      path = [
        pkgs.iptables
        pkgs.socat
        pkgs.util-linux
        pkgs.iproute2
        fw-worker
      ];

      script = ''
        NET_INTERFACE_DEVICE_NAME="${net_iface_device_name}"

        # Interpolate the Nix list into a Bash array definition
        NET_IFACE_IPV4_CIDR_ADDRS=(
          ${lib.concatMapStringsSep "\n  " (pkgs.lib.escapeShellArg) net_iface_ipv4_cidr_addr_pool}
        )

        if ip link show "$NET_INTERFACE_DEVICE_NAME" >/dev/null 2>&1; then
            echo "Interface $NET_INTERFACE_DEVICE_NAME already exists."
            
            for ip_addr in "''${NET_IFACE_IPV4_CIDR_ADDRS[@]}"; do
                if ! ip addr show dev "$NET_INTERFACE_DEVICE_NAME" | grep -q "''${ip_addr%/*}"; then
                    echo "Adding missing IP $ip_addr to existing interface."
                    ip addr add "$ip_addr" dev "$NET_INTERFACE_DEVICE_NAME"
                fi
            done
        else
            echo "Creating interface $NET_INTERFACE_DEVICE_NAME."
            ip link add "$NET_INTERFACE_DEVICE_NAME" type dummy
            ip link set "$NET_INTERFACE_DEVICE_NAME" up
            
            for ip_addr in "''${NET_IFACE_IPV4_CIDR_ADDRS[@]}"; do
                echo "Binding $ip_addr to $NET_INTERFACE_DEVICE_NAME."
                ip addr add "$ip_addr" dev "$NET_INTERFACE_DEVICE_NAME"
            done
        fi

        # --- NAT (MASQUERADE) RULES ENFORCEMENT ---
        # Iterate over the addresses to ensure outward-bound traffic is masqueraded 
        # behind the host's primary physical layout IP.
        for ip_addr in "''${NET_IFACE_IPV4_CIDR_ADDRS[@]}"; do
            BARE_IP="''${ip_addr%/*}"
            
            # Check if the masquerade rule already exists for this specific source IP
            if ! iptables -t nat -C POSTROUTING -s "$BARE_IP" -j MASQUERADE 2>/dev/null; then
                echo "Adding NAT Masquerade rule for $BARE_IP"
                iptables -t nat -A POSTROUTING -s "$BARE_IP" -j MASQUERADE
            fi
        done



        SOCKET_PATH="/run/sbx-slirp4netns-fw.sock"
        rm -f "$SOCKET_PATH"

        if ! iptables -S ${iptables_chain_name} &>/dev/null; then
            echo "iptables chain ${iptables_chain_name} is missing...creating it"
            iptables -N ${iptables_chain_name} || true
        fi

        if ! iptables -C OUTPUT -j ${iptables_chain_name} 2>/dev/null; then
            echo "iptables jump rule is missing...adding it"
            iptables -I OUTPUT -j ${iptables_chain_name}
        fi

        echo "systemd daemon started. ${iptables_chain_name} iptables chain initialized."

        # Exec directly into the clean binary path, eliminating escaping entirely
        exec socat -d UNIX-LISTEN:"$SOCKET_PATH",fork,mode=0660,group=sbx-slirp4netns-fw EXEC:"${fw-worker}/bin/sbx-fw-worker"
      '';

      serviceConfig = {
          Type = "simple";
      
          # Use writeShellScript to safely build and execute the cleanup sequence
          ExecStop = pkgs.writeShellScript "sbx-fw-cleanup" ''
            NET_INTERFACE_DEVICE_NAME="${net_iface_device_name}"

            NET_IFACE_IPV4_CIDR_ADDRS=(
              ${lib.concatMapStringsSep "\n  " (pkgs.lib.escapeShellArg) net_iface_ipv4_cidr_addr_pool}
            )

            echo "Stopping systemd daemon. Commencing iptables and interface cleanup..."

            # --- NAT (MASQUERADE) RULES CLEANUP ---
            for ip_addr in "''${NET_IFACE_IPV4_CIDR_ADDRS[@]}"; do
                BARE_IP="''${ip_addr%/*}"
                if iptables -t nat -C POSTROUTING -s "$BARE_IP" -j MASQUERADE 2>/dev/null; then
                    echo "Removing NAT Masquerade rule for $BARE_IP"
                    iptables -t nat -D POSTROUTING -s "$BARE_IP" -j MASQUERADE
                fi
            done

            # --- FILTER CHAIN CLEANUP ---
            if iptables -C OUTPUT -j ${iptables_chain_name} 2>/dev/null; then
                echo "Removing jump rule to ${iptables_chain_name} from OUTPUT chain."
                iptables -D OUTPUT -j ${iptables_chain_name}
            fi

            if iptables -S ${iptables_chain_name} &>/dev/null; then
                echo "Flushing and destroying iptables chain ${iptables_chain_name}."
                iptables -F ${iptables_chain_name}
                iptables -X ${iptables_chain_name}
            fi

            # --- INTERFACE CLEANUP ---
            if ip link show "$NET_INTERFACE_DEVICE_NAME" >/dev/null 2>&1; then
                echo "Removing virtual interface $NET_INTERFACE_DEVICE_NAME."
                ip link del "$NET_INTERFACE_DEVICE_NAME"
            fi

            rm -f /run/sbx-slirp4netns-fw.sock
            echo "Cleanup complete."
          '';
          
          syslogIdentifier = "sbx-slirp4netns-fw-daemon";
          standardOutput = "journal";
          standardError = "journal";
          RemainAfterExit = true;
      };
    };

  # Install nix-ld
  # - nix-ld is used for programs that use dynamically linked libraries but do not have the ELF header set to use the library loader located in /nix/store
  # - nix-ld adds symbolic link to directory in NIX_LD_LIBRARY_PATH directory to each <nix-store-path-for-nix-package>/lib object
  # - add Nix package reference to list set in libraries attribute
  # - nix-ld uses the Nix package reference to locate it in the Nix store
  # - nix-ld expects the "lib" subdirectory in the Nix store object for the Nix package
  programs.nix-ld = {
    enable = true;
    package = pkgs.nix-ld;
    libraries = [
      # 20260917 removed NVIDIA GPU
      # config.boot.kernelPackages.nvidiaPackages.production
      pkgs.glibc
      # pkgs.libbsd
      pkgs.rocmPackages.clr # to enable non-Nix aware binaries to find libray files like libamdhip64.so
    ];
  };

  # Install firefox.
  programs.firefox.enable = true; # AppImage

  security.sudo.extraConfig = ''
    Defaults timestamp_timeout = 180
  '';

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users = {
    swfactory = {
      isNormalUser = true;
      description = "Software Factory";
      extraGroups = [
        "networkmanager"
        "wheel"
        "qemu-libvirtd"
        "libvirtd"
        "video"
        "render"
        "sbx-slirp4netns-fw"
      ];

      packages = with pkgs; [
        kdePackages.kate
      ];

      # shell = pkgs.powershell;
      shell = pkgs.bash;

      # enable user to define uid and gid in linux namespaces for containers
      subUidRanges = [
        {
          startUid = 100000;
          count = 65536;
        }
      ];
      subGidRanges = [
        {
          startGid = 100000;
          count = 65536;
        }
      ];
    };
  };
}