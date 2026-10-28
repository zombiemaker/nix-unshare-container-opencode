# Containerized AI Agent Harness Environment

On a computer system running NixOS Linux, using the following technology components to create a Linux container environment for AI agent harness:
- Use powershell and init_shell.ps1 script to call "nix develop"
- Use nix and flake.nix script to:
  - provision software from Nix derivations for container environment
    - software that implements AI agent harness
    - software that are callable by AI agent harness program to perform on-machine or remote-machine actions
  - generate GNU Bash scripts to
    - create unshare namespaces for container environment
    - create network connection between container environment and host environment
    - create root file system for container environment 
    - create configurations for os and application programs
      - configuration for tls connection client apps
      - configuration for dns client apps
      - configuration for bash
      - configuration for git app
      - configuration for buildah app
      - configuration for podman app
      - configuration for opencode app
      - configuration for program development apps (e.g., clang, go, rust, mojo, dotnet, java, javascript, python, lua, etc.)
  - create Linux container environment for AI agent harness environment
  - start remotely-accessible AI agent harness server applications within Linux container environment
  - start interactive shell within Linux container environment


## Iteration Goals
- Fix opencode Crash Within unshare-Created Namespace

## Current Issues
- FIXED: podman crashes because it is looking for needs "/sys/fs/cgroup"
- FIXED: "opencode serve" works but "opencode" does not
- NOT A PROBLEM:/proc is not owned by root namespace user
- NOT A PROBLEM: /sys is not owned by root namespace user
- FIXED: git view mismatch between host namespace and container namespace for workspace root files
  - files in workspace root are not in the container workspace
  - git in container believes these files are deleted and therefore want to commit these as changes

## Checks
- fs ownerships
- network
  - can ping local network IPv4 address
  - can query DNS for google.com
  - local network client can connect to IPv4 port
- git
  - can 


## Capabilities To Be Implemented
- Run podman and run container images
- Enable unshare network namespace to access network

## Capabilities Implemented
- Run opencode CLI within unshare namespace
- Run buildah and create container images within unshare namespace
- Separated flake.nix code from GNU Bash script code for creating unshare namespace
- Install software program tools to be used by AI agent harnes within unshare namespace using Nix packages