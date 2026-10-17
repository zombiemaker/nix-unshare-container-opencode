# This generates a GNU Bash script that when executed will run an interactive Bash session.
#
# To materialize the file system environment structure without opening it:
# - To build and get a result link: `nix-build fhs-env.nix`
# - To build and set an environment variable to nix store directory: `FHS_NIX_STORE_PATH=$(nix-build /fhs-env.nix)
# 
# To run commands within the file system environment (remember it starts a Bash
# interactive session so just give it Bash commands):
# - Option A: Run a command using the compiled symlink path
#   `./result/bin/bubblewrap-opencode -c "node -v && echo \$MY_CUSTOM_ENV_VAR"`
# - Option B: Run it on-the-fly without keeping a local result symlink
#   ` nix-build fhs.nix --no-out-link && $(nix-build fhs.nix --no-out-link)/bin/bubblewrap-opencode -c "kubectl get pods"`
{
  pkgs ? import <nixpkgs> { },
}:

pkgs.buildFHSEnv {
  name = "bubblewrap-opencode";

  # targetPkgs Packages to be installed for the main host’s architecture (i.e. 
  # x86_64 on x86_64 installations). Along with libraries, binaries are also installed
  targetPkgs =
    pkgs:
    (with pkgs; [
      nodejs
      buildah
      kubectl
      git
      shadow
      bubblewrap
    ]);

  # multiPkgs Packages to be installed for all architectures supported by a host
  # (i.e. i686 and x86_64 on x86_64 installations). Only libraries are installed by default.
  multiPkgs =
    pkgs:
    (with pkgs; [
    ]);

  # The profile string runs automatically inside the environment setup.
  # This sets the variables without needing an interactive user session.
  profile = ''
    export MY_CUSTOM_ENV_VAR="my-value"
    export NODE_ENV="production"
    export KUBECONFIG="/etc/kubernetes/cluster.yaml"
  '';

  runScript = "bash";
}