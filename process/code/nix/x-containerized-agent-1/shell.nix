{
  pkgs ? import <nixpkgs> { },
}:

(
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

    runScript = "bash";
  }
).env