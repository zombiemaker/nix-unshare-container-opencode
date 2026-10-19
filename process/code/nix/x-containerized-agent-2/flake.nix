{
  description = "A containerized dev environment running Buildah inside an unshare namespace";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      # Define the architectures you want this flake to support
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      
      # Helper function to generate attributes for each system
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f (
        import nixpkgs {
          inherit system;
          config = { allowUnfree = true; };
        }
      ));
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          name = "buildah-container-env";

          # 1. Provide Buildah, unshare (util-linux), and any other dependencies
          packages = with pkgs; [
            buildah
            util-linux     # Provides the 'unshare' binary
            shadow         # Provides newuidmap/newgidmap if needed by unshare/buildah
            bashInteractive
          ];

          # 2. Inject your Bash entry script via the shellHook
          shellHook = ''
            # Ensure we are using a clean bash session
            if [ -z "$IN_NAMESPACE" ]; then
              echo "Running script: devShell shellHook"
              echo "Not in new namespace"
              echo "User outside namespace: $(whoami)"
              echo "PID outside namespace: $$"
              echo "Creating new namespace and re-executing shell"

              export IN_NAMESPACE=1

              # --map-root-user, -r maps current user to root inside namespace
              # --pid creates new process PID namespace (forks process)
              # --mount creates new mount namespace
              # --fork forks the specified program before executing
              exec unshare \
                --user \
                --map-users 100000:100000:65536 \
                --map-groups 100000:100000:65536 \
                --map-root-user \
                --pid \
                --mount \
                --fork \
                bash --rcfile <(echo "export IN_NAMESPACE=1; PS1='[namespace-shell]# '")
            fi

            # --- Everything below this line runs INSIDE the new user namespace ---
            echo "User inside namespace: $(whoami)"
            echo "PID inside namespace: $$"
            echo "Granted full set of all root capabilities including CAP_SYS_ADMIN"
            echo "Buildah version: $(buildah --version)"
          '';
        };
      });
    };
}
