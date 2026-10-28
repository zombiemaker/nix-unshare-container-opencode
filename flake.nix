{
  description = "A standard devShell that drops into a highly isolated Bubblewrap environment for an AI agent";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    zm_pixi_repo.url = "github:zombiemaker/nix-zm_pixi";
    zm_opencode_repo.url = "github:zombiemaker/nix-zm_opencode";
  };

  outputs = { 
    self, 
    nixpkgs, 
    zm_pixi_repo,
    zm_opencode_repo
  }:

  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
    zm_pixi = zm_pixi_repo.v0_75_0.machine_code.x86_64.linux.musl_libc;

    humanTools_shell = [
      pkgs.tmux
      pkgs.zellij
    ];
    
    agentTools_nixos = [
      pkgs.nix
      pkgs.stdenv
      pkgs.util-linux # pivot_root
    ];

    agentTools_os = [
      pkgs.binutils # readelf
      pkgs.coreutils
      pkgs.file
    ];

    agentTools_os_containers = [
      pkgs.aardvark-dns
      pkgs.catatonit
      pkgs.conmon
      pkgs.crun
      pkgs.buildah
      pkgs.img
      pkgs.netavark
      pkgs.podman
      pkgs.skopeo
      pkgs.slirp4netns
      pkgs.fuse-overlayfs
      pkgs.fuse # for fusermount to unmount fuse-overlays
    ];

    agentTools_os_processes = [
      pkgs.procps
      pkgs.strace
    ];

    agentTools_os_networks = [
      pkgs.dig
      pkgs.iputils
      pkgs.net-tools
      pkgs.procps
      pkgs.strace
    ];

    agentTools_os_files = [
      pkgs.fd
      pkgs.lsof
      pkgs.mount
      pkgs.tree
      pkgs.umount
      pkgs.which
    ];

    agentTools_os_security = [
      pkgs.bubblewrap
      pkgs.cacert
      pkgs.gnutls
      pkgs.openssl
    ];

    agentTools_data_text = [
      pkgs.ast-grep
      pkgs.bat
      pkgs.ctags
      pkgs.gawk
      pkgs.gnugrep
      pkgs.gnused
      pkgs.neovim
      pkgs.jq
      pkgs.less
      pkgs.more
      pkgs.ripgrep
      pkgs.tree-sitter
      pkgs.xmlstarlet
      pkgs.yq
    ];

    agentTools_data_image = [
      pkgs.graphiz
      pkgs.imagemagick
    ];

    agentTools_data_audio = [
      pkgs.ffmpeg
    ];

    agentTools_data_packages = [
      pkgs.gnutar
      pkgs.mamba-cpp
      pkgs.micromamba
      pkgs.nuget
      zm_pixi
    ];

    agentTools_data_avro = [
      pkgs.avro-tools
      pkgs.avro-c
      pkgs.avro-cpp
      pkgs.python314Packages.avro
      pkgs.python314Packages.fastavro
    ];
    
    agentTools_data_flatbuffers = [
      pkgs.flatbuffers
      pkgs.parquet-tools
      pkgs.nail-parquet
    ];

    agentTools_data_git = [
      pkgs.git
      pkgs.delta
    ];

    agentTools_data_parquet = [
      pkgs.parquet-tools
      pkgs.nail-parquet
    ];

    agentTools_data_store = [
      pkgs.duckdb
      pkgs.sqlite
      pkgs.ladybugdb
      # rocksdb?
    ];

    agentTools_http = [
      pkgs.curl
      pkgs.wget
    ];

    agentTools_machine_task = [
      pkgs.gnumake
    ];

    ###############################
    # Messaging Agent Tools
    ###############################

    agentTools_nats = [
      pkgs.natscli
      pkgs.nats-kafka
      pkgs.nats-server
      pkgs.nats-top
    ];

    agentTools_apacheKafka = [
      pkgs.apacheKafka
    ];

    agentTools_eclipseZenoh = [
      pkgs.zenoh
      pkgs.zenoh-backend-rocksdb
      pkgs.zenoh-backend-influxdb
      pkgs.zenoh-backend-filesystem
      pkgs.zenoh-plugin-mqtt
      pkgs.zenoh-plugin-webserver
      pkgs.zenoh-plugin-dds
      pkgs.zenoh-c
      pkgs.zenoh-cpp
      # zm_zenoh_backend_sql # https://github.com/eclipse-zenoh/zenoh-backend-sql
      # zm_zenoh_backend_s3 # https://github.com/eclipse-zenoh/zenoh-backend-s3
      # zm_zenoh_go # https://github.com/eclipse-zenoh/zenoh-go
      # zm_zenoh_python # https://github.com/eclipse-zenoh/zenoh-python
      # zm_zenoh_ts # https://github.com/eclipse-zenoh/zenoh-ts
      # zm_zenoh_java # https://github.com/eclipse-zenoh/zenoh-java
      # zm_zenoh_csharp # https://github.com/eclipse-zenoh/zenoh-csharp
      # zm_zenoh_flat # https://github.com/eclipse-zenoh/zenoh-flat
    ];

    ###############################
    # Code Stack Agent Tools
    ###############################
    agentTools_codeStack_c = [
      pkgs.clang_22
      pkgs.clang-tools
      pkgs.cmake
      pkgs.gcc
      pkgs.ninja
    ];

    agentTools_codeStack_cpp = [
      pkgs.clang_22
      pkgs.clang-tools
      pkgs.cmake
      pkgs.gcc
      pkgs.ninja
    ];

    agentTools_codeStack_csharp_10_dotnet = [
      # pkgs.dotnet-runtime_10
      pkgs.dotnet-sdk_10
      pkgs.omnisharp-roslyn
      pkgs.nuget
    ];

    agentTools_codeStack_csharp_mono = [
      pkgs.mono
      pkgs.nuget
    ];

    agentTools_codeStack_csharp_blazorServer = [
    ];

    agentTools_codeStack_csharp_blazorWasm = [
    ];

    agentTools_codeStack_gnuBash = [
      pkgs.bashInteractive
      pkgs.shellcheck
    ];

    agentTools_codeStack_elixer = [];

    agentTools_codeStack_go_1_27_standard = [
      pkgs.go_1_27
      pkgs.gopls
      pkgs.go-tools
      pkgs.gotools
    ];

    agentTools_codeStack_go_1_27_tinygo = [
      pkgs.tinygo
      pkgs.gopls
      pkgs.go-tools
      pkgs.gotools
    ];

    agentTools_codeStack_whatwg_css = [];

    agentTools_codeStack_whatwg_dom = [];

    agentTools_codeStack_whatwg_html = [];

    agentTools_codeStack_java_25_corretto  = [
      # pkgs.corretto25
      pkgs.javaPackages.compiler.corretto25
    ];

    agentTools_codeStack_java_25_eclipseTemurin  = [
      # pkgs.temurin-bin-25
      # pkgs.temurin-jre-bin-25
      pkgs.javaPackages.compiler.temurin-bin.jdk-25
      pkgs.gradle_9
      pkgs.gradle-completion
      pkgs.gradle-dependency-tree-diff
    ];

    agentTools_codeStack_javaScript = [];

    agentTools_codeStack_javaScript_bun = [
      pkgs.bun
    ];

    agentTools_codeStack_javaScript_deno = [];

    agentTools_codeStack_javaScript_nodejs = [
      pkgs.nodejs
    ];

    agentTools_codeStack_javaScript_webBrowser = [];

    agentTools_codeStack_lua_luaJit = [
      pkgs.luajit
    ];

    agentTools_codeStack_mojo = [
      zm_pixi
    ];
    
    agentTools_codeStack_powershell = [
      pkgs.powershell
      pkgs.powershell-editor-services
      pkgs.tree-sitter
      pkgs.tree-sitter-grammars.tree-sitter-powershell
    ];

    agentTools_codeStack_python_3_14_cpython = [
      pkgs.python314
      pkgs.python314Packages.pip
      pkgs.uv
      pkgs.ruff
      zm_pixi
    ];

    agentTools_codeStack_python_3_11_pypy = [
      pkgs.pypy311
    ];

    agentTools_codeStack_r = [];

    agentTools_codeStack_ruby = [];

    agentTools_codeStack_rust = [
      pkgs.rustup
      pkgs.rust-bindgen # generates Rust FFI code to C libraries
      pkgs.rust-cbindgen # generates C bindings from Rust code
    ];

    agentTools_codeStack_typescript = [];

    agentTools_codeStack_typescript_deno = [];

    agentTools_codeStack_typescript_nodejs = [];

    agentTools_codeStack_wasm = [
      pkgs.wasm-tools
    ];

    agentTools_codeStack_wasm_wasi = [
      pkgs.wit-bindgen
      pkgs.wasmtime
      pkgs.wasmer
      pkgs.wkg
    ];

    agentTools_codeStack_wasm_webBrowser = [];

    ###############################
    # Cloud Stack Agent Tools
    ###############################

    agentTools_cloudStack_aws = [];

    agentTools_cloudStack_azure = [];

    agentTools_cloudStack_cloudFlare = [];

    agentTools_cloudStack_digitalOcean = [];

    agentTools_cloudStack_googleCloud = [];

    agentTools_cloudStack_vmware = [];

    agentTools_cloudStack_kubernetes = [
      pkgs.k9s
      pkgs.kubectl
    ];
    

    # ACTION: Select derivations groups to make available to AI agent harness
    agentTools_Selected = agentTools_nixos ++
      humanTools_shell ++
      agentTools_os ++
      agentTools_os_containers ++
      agentTools_os_processes ++
      agentTools_os_files ++
      agentTools_os_networks ++
      agentTools_os_security ++
      agentTools_machine_task ++
      agentTools_http ++
      agentTools_data_git ++
      agentTools_data_text ++
      agentTools_data_packages ++
      agentTools_codeStack_gnuBash ++ 
      agentTools_codeStack_powershell ++
      agentTools_codeStack_c ++
      agentTools_codeStack_csharp_10_dotnet ++
      agentTools_codeStack_go_1_27_standard ++
      agentTools_codeStack_whatwg_css ++
      agentTools_codeStack_whatwg_dom ++
      agentTools_codeStack_whatwg_html ++
      agentTools_codeStack_java_25_eclipseTemurin ++
      agentTools_codeStack_javaScript_bun ++
      agentTools_codeStack_javaScript_nodejs ++
      agentTools_codeStack_python_3_14_cpython ++
      agentTools_codeStack_python_3_11_pypy ++
      agentTools_codeStack_rust ++
      agentTools_codeStack_wasm ++
      agentTools_codeStack_wasm_wasi ++
      agentTools_cloudStack_kubernetes;


    ###############################################################################
    # NixOS-Native Linux ELF
    ###############################################################################
    zm_opencode_linux_nixos = zm_opencode_repo.v2_2_0.machine_code.x86_64.linux_nixos.gnu_libc;

    # Define the collection of tool derivations the AI Agent is allowed to use
    agentTools_LinuxNixOs = agentTools_Selected ++
      [ zm_opencode_linux_nixos ];

    agentClosureLinuxNixOs = pkgs.closureInfo { rootPaths = agentTools_LinuxNixOs; };

    startShellScriptFileName_LinuxNixOs = "ai-agent-harness-start-shell-linux_nixos";
    startShellScriptShellWrapper_LinuxNixOs = pkgs.replaceVarsWith {
      src = ./process/code/nix/production/workspace/start-unshare-shell.template.bash;
      replacements = {
        # opencode_server_hostname="0.0.0.0";
        # opencode_server_port=9000;
      };

      # Set executable permission
      name = startShellScriptFileName_LinuxNixOs;
      dir = "bin";
      isExecutable = true;
    };

    buildInsideNamespaceEnvScriptFileName_LinuxNixOs = "ai-agent-harness-build-unshare-inside-ns-env-linux_nixos";
    buildInsideNamespaceEnvScriptShellWrapper_LinuxNixOs = pkgs.replaceVarsWith {
      src = ./process/code/nix/production/workspace/build-unshare-inside_ns.template.bash;
      replacements = {
        agentToolsBinPaths = pkgs.lib.makeBinPath agentTools_LinuxNixOs;
        agentClosureLinuxNixOs = agentClosureLinuxNixOs;
        bashInteractive_nixStorePath = pkgs.bashInteractive;
        coreutils_nixStorePath = pkgs.coreutils;
        fuse_overlayfs_nixStorePath = pkgs.fuse-overlayfs;
        cacert_nixStorePath = pkgs.cacert;
        startShellScriptShellWrapper_nixStorePath = startShellScriptShellWrapper_LinuxNixOs;
        opencode_shell="${pkgs.bashInteractive}//bin/bash";
        # opencode_server_hostname="0.0.0.0";
        # opencode_server_port=9000;
        # opencode_server_cors="[ \"http://localhost\" ]";
        # opencode_custom_llm_provider_1_id="local.strata";
        # opencode_custom_llm_provider_1_name="local-strata";
        # opencode_custom_llm_provider_1_base_url="p1_url";
        # opencode_custom_llm_provider_1_model_1_id="qwen-3.8.fn";
        # opencode_custom_llm_provider_1_model_1_name="qwen3.8-flash-next-iq3_s";
        # opencode_custom_llm_provider_1_model_1_limit_context=262144;
        # opencode_custom_llm_provider_1_model_1_limit_output=32768;
        # opencode_custom_llm_provider_1_model_2_id="p1_m2_id";
        # opencode_custom_llm_provider_1_model_2_name="p1_m2_name";
        # opencode_custom_llm_provider_1_model_2_limit_context=32768;
        # opencode_custom_llm_provider_1_model_2_limit_output=16384;
        # opencode_custom_llm_provider_1_model_3_id="p1_m3_id";
        # opencode_custom_llm_provider_1_model_3_name="p1_m3_name";
        # opencode_custom_llm_provider_1_model_3_limit_context=32768;
        # opencode_custom_llm_provider_1_model_3_limit_output=16384;
        # opencode_custom_llm_provider_2_id="local.llama.cpp";
        # opencode_custom_llm_provider_2_name="local-llama-cpp";
        # opencode_custom_llm_provider_2_base_url="p2_url";
        # opencode_custom_llm_provider_2_model_1_id="qwen-3-embedding-0.6b";
        # opencode_custom_llm_provider_2_model_1_name="Qwen/Qwen3-Embedding-0.6B-GGUF:Q8_0";
        # opencode_custom_llm_provider_2_model_1_limit_context=32768;
        # opencode_custom_llm_provider_2_model_1_limit_output=16384;
        # opencode_custom_llm_provider_2_model_2_id="p2_m2_id";
        # opencode_custom_llm_provider_2_model_2_name="p2_m2_name";
        # opencode_custom_llm_provider_2_model_2_limit_context=32768;
        # opencode_custom_llm_provider_2_model_2_limit_output=16384;
        # opencode_custom_llm_provider_2_model_3_id="p2_m3_id";
        # opencode_custom_llm_provider_2_model_3_name="p2_m3_name";
        # opencode_custom_llm_provider_2_model_3_limit_context=32768;
        # opencode_custom_llm_provider_2_model_3_limit_output=16384;
        # opencode_custom_llm_provider_3_id="local.ollama";
        # opencode_custom_llm_provider_3_name="local-ollama";
        # opencode_custom_llm_provider_3_base_url="p3_url";
        # opencode_custom_llm_provider_3_model_1_id="qwen-2.5-coder-7b";
        # opencode_custom_llm_provider_3_model_1_name="qwen-2.5-coder:7b";
        # opencode_custom_llm_provider_3_model_1_limit_context=32768;
        # opencode_custom_llm_provider_3_model_1_limit_output=16384;
        # opencode_custom_llm_provider_3_model_2_id="p3_m2_id";
        # opencode_custom_llm_provider_3_model_2_name="p3_m2_name";
        # opencode_custom_llm_provider_3_model_2_limit_context=32768;
        # opencode_custom_llm_provider_3_model_2_limit_output=16384;
        # opencode_custom_llm_provider_3_model_3_id="p3_m3_id";
        # opencode_custom_llm_provider_3_model_3_name="p3_m3_name";
        # opencode_custom_llm_provider_3_model_3_limit_context=32768;
        # opencode_custom_llm_provider_3_model_3_limit_output=16384;
      };

      # Set executable permission
      name = buildInsideNamespaceEnvScriptFileName_LinuxNixOs;
      dir = "bin";
      isExecutable = true;
    };

    # Build a GNU Bash script that provisions the unshare namespaces and pivot_root
    buildOutsideNamespaceEnvScriptFileName_LinuxNixOs = "ai-agent-harness-build-unshare-outside-ns-env-linux_nixos";
    buildOutsideNamespaceEnvScriptShellWrapper_LinuxNixOs = pkgs.replaceVarsWith {
      src = ./process/code/nix/production/workspace/build-unshare-outside_ns.template.bash;
      replacements = {
        startShellScriptShellWrapper_nixStorePath = startShellScriptShellWrapper_LinuxNixOs;
        startShellScriptFileName = startShellScriptFileName_LinuxNixOs;
        # NOTE: slirp4netns can only bind specifc ip address to either outbound-addr or port-forward-host-addr
        # NOTE: use the IP address of the machine running unshare not VS Code machine IP address
        slirp4netns_port_forward_host_addr="0.0.0.0";
      };

      # Set executable permission
      name = buildOutsideNamespaceEnvScriptFileName_LinuxNixOs;
      dir = "bin";
      isExecutable = true;
    };

  
  ###############################################################################
  # Traditional Linux ELF & nix-ld Shimmed
  ###############################################################################
  zm_opencode_linux = zm_opencode_repo.v2_2_0.machine_code.x86_64.linux.gnu_libc;
  
  # Define the collection of tool derivations the AI Agent is allowed to use
  agentTools_Linux = agentTools_Selected ++
    [ zm_opencode_linux ];

  # Create a closure path containing the store paths of ALL dependencies
  agentClosureLinux = pkgs.closureInfo { rootPaths = agentTools_Linux; };

  

  in {
    v0_1_0 = {
      shells = {
        x86_64 = {
          linux_nixos = {
            shell = pkgs.mkShell {
              name = "containerized-opencode-linux_nixos-shell";
              shellHook = ''
                echo "🔐 Initializing isolated AI workspace..."
                exec ${buildOutsideNamespaceEnvScriptShellWrapper_LinuxNixOs}/bin/${buildOutsideNamespaceEnvScriptFileName_LinuxNixOs} \
                  --internal-env-script ${buildInsideNamespaceEnvScriptShellWrapper_LinuxNixOs}/bin/${buildInsideNamespaceEnvScriptFileName_LinuxNixOs} \
                  --start-shell-script ${startShellScriptShellWrapper_LinuxNixOs}/bin/${startShellScriptFileName_LinuxNixOs} \
                  --mode shell
              '';
            };

            server = pkgs.mkShell {
              name = "containerized-opencode-linux_nixos-server";
              shellHook = ''
                echo "🔐 Initializing isolated AI workspace..."
                exec ${buildOutsideNamespaceEnvScriptShellWrapper_LinuxNixOs}/bin/${buildOutsideNamespaceEnvScriptFileName_LinuxNixOs} \
                  --internal-env-script ${buildInsideNamespaceEnvScriptShellWrapper_LinuxNixOs}/bin/${buildInsideNamespaceEnvScriptFileName_LinuxNixOs} \
                  --start-shell-script ${startShellScriptShellWrapper_LinuxNixOs}/bin/${startShellScriptFileName_LinuxNixOs} \
                  --mode server
              '';
            };
          };

          linux = pkgs.mkShell {
            shell = pkgs.mkShell {
              name = "containerized-opencode-linux-shell";
              shellHook = ''
                echo "🔐 Initializing isolated AI workspace..."
                echo "not implemented"
                exit 1
              '';
            };

            server = pkgs.mkShell {
              name = "containerized-opencode-linux-server";
              shellHook = ''
                echo "🔐 Initializing isolated AI workspace..."
                echo "not implemented"
                exit 1
              '';
            };
          };

          default = self.v0_1_0.shells.x86_64.linux_nixos;
        };
      };
    };

    latest = self.v0_1_0;
  };
}
