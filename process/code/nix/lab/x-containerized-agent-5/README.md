# Goal: Fix opencode Crash Within unshare-Created Namespace

## Current Issues
- podman crashes because it is looking for needs "/sys/fs/cgroup"
  - need to build out "/sys" within unshare namespace
  - need separate network namespace within unshare namespace in order to define "/sys"
  - need to use slirp4netns on host namespace to enable unshare network namespace to connect to network

## Capabilities To Be Implemented
- Run podman and run container images
- Enable unshare network namespace to access network

## Capabilities Implemented
- Run opencode CLI within unshare namespace
- Run buildah and create container images within unshare namespace
- Separated flake.nix code from GNU Bash script code for creating unshare namespace
- Install software program tools to be used by AI agent harnes within unshare namespace using Nix packages