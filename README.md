# NixOS + Nix + Unshare Containerized AI Agent Harness (OpenCode)

Experimental containerized environment for OpenCode (or any other 
AI agent harness) to go nuts in with less concern that any agent actions will
destroy your system running it.  Utilizes Nix and Nixpkgs library to provision
software for the AI agent harness to use.

## Feature Highlights
- From inside unshare Linux namespace
  - Restricted network access reducing unauthorized exfiltration of data by malicious programs
  - Run programs provisioned by Nix derivations
  - Run OpenCode CLI / Web
  - Build container images using Buildah
  - Run container images using Podman
  - Run kubectl to connect to Kubernetes clusters
  - Run k9s to manage Kubernetes clusters
- From outside unshare Linux namespace
  - Configure set of Nix derivations (from nixpkgs or other locations) available to container namespace
  - Connect to OpenCode Web running within namespace
  - Access container user home directory and edit contents
  - Persist container images pulled or created
  - Share downloaded files between host namespace and container namespace

## Supported Environments
- NixOS Linux on x86_64 machines
- Linux + Nix on x86_64 machines
- Visual Studio Code

## Usage
- Clone repo
- Run "init_shell.ps1" script
- Follow options

## Key Files
- init_shell.ps1
- flake.nix
- process/code/nix/production/build-unshare-outside_ns.template.bash
- process/code/nix/production/build-unshare-inside_ns.template.bash
- process/code/nix/production/enter-unshare-ns.template.bash

## Prerequisite Host Environment
- The script creating the outside namespace environment expects a /run/slirp4netns.sock UNIX socket that receives requests for changes to machine firewall rules
- An example NixOS configuration is in [this file](process/code/nix-standard-linux/production/nixos/configuration.nix)
  - Creates a Linux user group (sbx-slirp4netns-sbx) for users authorized to access UNIX socket
  - Creates dummy network interface (slirp4netns_0) for slirp4netns
  - Binds an IPv4 address pool to slirp4netns_0 for multiple network namespaces
  - Creates a Linux netfilter rule chain SBX_SLIRP4NETNS_FW_OUTPUT
  - Creates a UNIX socket (/run/slirp4netns.sock)
  - Creates systemd service (sbx-slirp4netns-fw-daemon) that executes limited commands to change netfilter rules
    - Add ACCEPT rule for specific destination IPv4, tcp/udp/icmp, and destination port numbers
    - Add DROP rule for everything else
    - Remove all rules

## Process For Building Linux Namespace / Container Environment
- init_shell.ps1 invokes flake.nix
- flake.nix builds Nix derivations
- flake.nix builds GNU Bash scripts for 
  - building external namespace environment from template and adds script to /nix/store
  - building internal namespace environment from template and adds script to /nix/store
  - building initializes shell in unshare namespace from template and adds script to /nix/store
- flake.nix invokes GNU Bash to run /nix/store script that builds external namespace environment
- /nix/store script that builds external namespace environment
  - invokes unshare to create namespace and run /nix/store script that builds internal namespace environment
  - invokes slirp4netns to creat bridge network between unshare namespace and host network
  - invokes nsenter to enter created unshare namespace and run /nix/store script that initializes shell in unshare namespace

## TODOs
- document UNIX socket protocol