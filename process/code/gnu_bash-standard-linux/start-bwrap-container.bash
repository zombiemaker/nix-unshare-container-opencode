#!/usr/bin/env nix-shell
#!nix-shell -i bash --pure
# --- To get access to nix-store
#!nix-shell -p nix stdenv

# --- FOUNDATIONAL ENVIRONMENT & MULTI-LANGUAGE TOOLS ---
#!nix-shell -p which procps bash coreutils 
#!nix-shell -p net-tools iputils dig
#!nix-shell -p wget curl git gnugrep gnutar gnutls openssl cacert bubblewrap
#!nix-shell -p pixi mamba-cpp micromamba
#!nix-shell -p cmake gnumake go-task mise

# --- PYTHON ECOSYSTEM ---
#!nix-shell -p python314 python314Packages.pip "python314Packages.pipx.overridePythonAttrs (old: { doCheck = false; })" uv ruff

# --- JAVASCRIPT / NODE.JS ECOSYSTEM ---
#!nix-shell -p nodejs_24 biome

# --- C / C++ ECOSYSTEM ---
#!nix-shell -p clang_22 clang-tools

# --- GO ECOSYSTEM ---
#!nix-shell -p go_1_27 tinygo golangci-lint gotestsum

# --- WEBASSEMBLY ECOSYSTEM ---
#!nix-shell -p wasmtime wasmer wkg wit-bindgen wasm-tools binaryen

# --- POWERSHELL ECOSYSTEM ---
#!nix-shell -p powershell

# --- BASH / SHELL SCRIPTS ---
#!nix-shell -p shellcheck

# --- DATASETS & DATA STORAGE ---
#!nix-shell -p duckdb sqlite jq yq

# --- TEXT, CODE PARSING, & SEARCH TOOLS ---
#!nix-shell -p ast-grep tree-sitter ctags ripgrep ripgrep-all fd bat delta tree gawk gnused

# --- MEDIA, GRAPHICS, & DOCUMENT PROCESSING ---
#!nix-shell -p ffmpeg imagemagick graphviz pandoc links2

# --- SYSTEM TRACING & DEBUGGING ---
#!nix-shell -p strace lsof



set -eo pipefail

# Default values
HOST_TEMP="$(pwd)/.temp"
HOST_CONTAINER_BASE="$HOST_TEMP/container-fs"
HOST_CONTAINER_HOME="$HOST_CONTAINER_BASE/home"
HOST_CONTAINER_WORKSPACE="$HOST_CONTAINER_BASE/workspace"
CONTAINER_USER_NAME="app-runner"
CONTAINER_PORT=3080
SHARE_NET=true
MODE="server"

# Display usage helper
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -b, --base PATH        Host container base directory path (default: $HOST_CONTAINER_BASE)
  -h, --home PATH        Host container home directory path for all container users (default: $HOST_CONTAINER_HOME)
  -w, --workspace PATH   Host container workspace directory path (default: $HOST_CONTAINER_WORKSPACE)
  -u, --user NAME        Container user name (default: $CONTAINER_USER_NAME)
  -p, --port PORT        Container port (default: $CONTAINER_PORT)
  --no-net               Disable network access inside the container
  --mode MODE            "server" (default) or "shell"
  --help                 Display this help message
EOF
    exit 0
}

# Parse named parameters
while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--base)
            HOST_CONTAINER_BASE="$2"
            shift 2
            ;;
        -h|--home)
            HOST_CONTAINER_HOME="$2"
            shift 2
            ;;
        -u|--user)
            CONTAINER_USER_NAME="$2"
            shift 2
            ;;
        -p|--port)
            CONTAINER_PORT="$2"
            shift 2
            ;;
        --no-net)
            SHARE_NET=false
            shift
            ;;
        --mode)
            MODE="${2,,}"
            echo "MODE = '$MODE'"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo "Error: Unknown argument '$1'" >&2
            echo "Use --help for usage details." >&2
            exit 1
            ;;
    esac
done

HOST_TEMPLATE="$(pwd)/process/code/container/template"
HOST_CONTAINER_BIN="$HOST_CONTAINER_BASE/bin"
HOST_CONTAINER_USR="$HOST_CONTAINER_BASE/usr"
HOST_CONTAINER_NPM_GLOBAL="$HOST_CONTAINER_BASE/npm-global"
HOST_CONTAINER_SCRIPTS="$HOST_CONTAINER_BASE/scripts"
CONTAINER_BIN="/bin"
CONTAINER_USR="/usr"
CONTAINER_NPM_GLOBAL="/npm-global"
CONTAINER_NPM_GLOBAL_BIN="$CONTAINER_NPM_GLOBAL/bin"
CONTAINER_HOME="/home"
CONTAINER_SCRIPTS="/scripts"
CONTAINER_WORKSPACE="/workspace"
CONTAINER_USER_HOME="$CONTAINER_HOME/$CONTAINER_USER_NAME"
CONTAINER_USER_CONFIG="$CONTAINER_USER_HOME/.config"

# Create directories for container
mkdir -p "$HOST_CONTAINER_BIN"
mkdir -p "$HOST_CONTAINER_USR"
mkdir -p "$HOST_CONTAINER_HOME"
mkdir -p "$HOST_CONTAINER_NPM_GLOBAL"
mkdir -p "$HOST_CONTAINER_SCRIPTS"
mkdir -p "$HOST_CONTAINER_WORKSPACE"
mkdir -p "$HOST_CONTAINER_HOME/$CONTAINER_USER_NAME"
mkdir -p "$HOST_CONTAINER_HOME/$CONTAINER_USER_NAME/.config"

if [ -d "$HOST_TEMPLATE/scripts" ]; then
    cp -r "$HOST_TEMPLATE/scripts/." "$HOST_CONTAINER_SCRIPTS/"
    chmod +x "$HOST_CONTAINER_SCRIPTS"/*.bash 2>/dev/null || true
fi

# =====================================================================
# TASK-ORIENTED TOOL MAPPINGS
# =====================================================================

declare -A TASK_CATEGORIES=(
    # ["system_debugging"]="strace lsof ps"
    ["system_networking"]="ping netstat dig"
    ["shell_scripting"]="shellcheck bash pwsh"
    ["file_searching"]="env which ls fd tree"
    # ["file_viewing"]="bat cat delta"
    # ["software_package_management"]="nix pixi mamba micromamba"
    # ["text_tranforming"]="gawk awk sed jq yq"
    ["text_filtering"]="grep"
    # ["data_transforming"]="base64"
    # ["data_storing"]="duckdb sqlite3"
    ["code_linking"]="ldd readelf file"
    # ["code_search"]="rg rga ast-grep ctags tree-sitter"
    # ["python_tooling"]="uv ruff pip pipx python3"
    # ["javascript_tooling"]="node npm biome"
    # ["c_cpp_tooling"]="clang clang-tidy cmake make"
    # ["go_tooling"]="go tinygo golangci-lint gotestsum"
    # ["webassembly_tooling"]="wasmtime wasmer wkg wit-bindgen wasm-tools binaryen-unittests wasm-as wasm-ctor-eval wasm-dis wasm-emscripten-finalize wasm-fuzz-lattices wasm-fuzz-types wasm-merge wasm-metadce wasm-opt wasm-reduce wasm-spit-wasm2js"
    # ["document_media"]="pandoc ffmpeg magick dot links"
    # ["task_automation"]="go-task mise make"
    ["ai_agent_harness"]="opencode"
    ["version_control_transfer"]="git wget curl tar"
    ["containerization"]="bwrap"
)

ALL_RAW_TOOLS="${TASK_CATEGORIES[*]}"
TARGET_TOOLS=($(echo "$ALL_RAW_TOOLS" | tr ' ' '\n' | sort -u))

GENERATED_PATH_DIRS=()
RESOLVED_FILES=()

echo "Resolving paths and categorizing tools..."

for tool in "${TARGET_TOOLS[@]}"; do
    bin_path=$(which "$tool" 2>/dev/null || true)
    if [ -n "$bin_path" ]; then
        RESOLVED_FILES+=("$bin_path")
        dir_path=$(dirname "$bin_path")
        GENERATED_PATH_DIRS+=("$dir_path")
    else
        echo "Warning: Tool '$tool' not found in environment PATH" >&2
    fi
done

# Generate TOOLS_INSTALLED.json
JSON_OUT="$HOST_CONTAINER_WORKSPACE/TOOLS_INSTALLED.json"
cat <<EOF > "$JSON_OUT"
{
  "system_info": {
    "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "environment": "nix-bubblewrap-dsh"
  },
  "task_preferences": {
EOF

first_cat=true
for cat in "${!TASK_CATEGORIES[@]}"; do
    read -r -a tools_list <<< "${TASK_CATEGORIES[$cat]}"
    resolved_cat_tools=()
    
    for t in "${tools_list[@]}"; do
        p=$(which "$t" 2>/dev/null || true)
        if [ -n "$p" ]; then
            resolved_cat_tools+=("{\"name\": \"$t\", \"path\": \"$p\"}")
        fi
    done
    
    if [ ${#resolved_cat_tools[@]} -gt 0 ]; then
        if [ "$first_cat" = true ]; then
            first_cat=false
        else
            echo "," >> "$JSON_OUT"
        fi
        tools_json=$(IFS=,; echo "${resolved_cat_tools[*]}")
        echo -n "    \"$cat\": [$tools_json]" >> "$JSON_OUT"
    fi
done

echo "" >> "$JSON_OUT"
echo "  }" >> "$JSON_OUT"
echo "}" >> "$JSON_OUT"

# Generate TOOLS_PREFERENCES.md
MD_OUT="$HOST_CONTAINER_WORKSPACE/TOOLS_PREFERENCES.md"
cat <<EOF > "$MD_OUT"
# Container Tooling & Task Preferences

This container includes pre-configured tools. Prefer the prioritized tool sequences listed below when executing specific tasks.

EOF

for cat in "${!TASK_CATEGORIES[@]}"; do
    echo "## Category: $cat" >> "$MD_OUT"
    read -r -a tools_list <<< "${TASK_CATEGORIES[$cat]}"
    rank=1
    for t in "${tools_list[@]}"; do
        p=$(which "$t" 2>/dev/null || true)
        if [ -n "$p" ]; then
            echo "$rank. **\`$t\`** — \`$p\`" >> "$MD_OUT"
            ((rank++))
        fi
    done
    echo "" >> "$MD_OUT"
done

# =====================================================================
# GENERATE METHOD 1: WORKSPACE PROMPTS & MULTI-FILENAME DISCOVERY
# =====================================================================
mkdir -p "$HOST_CONTAINER_WORKSPACE/.dsh"
mkdir -p "$HOST_CONTAINER_HOME/$CONTAINER_USER_NAME/.dsh"

DSH_PROMPT_CONTENT='# Workspace Tooling & Execution Protocol

You have access to pre-installed system tools detailed in two workspace context files:
1. `TOOLS_INSTALLED.json`: Defines machine-readable tool paths mapped by category.
2. `TOOLS_PREFERENCES.md`: Specifies prioritized task execution sequences and primary tool recommendations.

## Tool Execution Protocol
- **Context Inspection:** Before selecting or running CLI commands, inspect `TOOLS_PREFERENCES.md` to identify the preferred tool for that task category.
- **Priority Fallbacks:** Use the highest-ranked available binary listed for the matching task category. If a primary tool is unavailable or unsuitable for a specific operation, fall back sequentially to the next ranked tool in the list.
- **Path Resolution:** Reference `TOOLS_INSTALLED.json` if explicit system paths or environment validation are required.
- **Explicit Execution:** Do not attempt to invoke unlisted binaries for core task categories when a designated preferred tool exists.'

# Write to standard workspace discovery hooks
echo "$DSH_PROMPT_CONTENT" > "$HOST_CONTAINER_WORKSPACE/.dsh/prompt.md"
echo "$DSH_PROMPT_CONTENT" > "$HOST_CONTAINER_WORKSPACE/.dsh/system.md"
echo "$DSH_PROMPT_CONTENT" > "$HOST_CONTAINER_WORKSPACE/.dsh/instructions.md"

# Write to user home global fallback
echo "$DSH_PROMPT_CONTENT" > "$HOST_CONTAINER_HOME/$CONTAINER_USER_NAME/.dsh/prompt.md"

# Legacy plain-text catalog
: > "$HOST_CONTAINER_WORKSPACE/TOOLS_INSTALLED"
for bin in "${RESOLVED_FILES[@]}"; do
    tool_name=$(basename "$bin")
    echo "Resolved $tool_name -> $bin" >> "$HOST_CONTAINER_WORKSPACE/TOOLS_INSTALLED"
done

# Explicitly resolve store paths for non-binary packages like cacert
echo "Resolving path to cacert"
if [ -n "$NIX_SSL_CERT_FILE" ]; then
    CACERT_PATH=$(echo "$NIX_SSL_CERT_FILE" | grep -oE '/nix/store/[^/]+-cacert-[^/]+')
    echo "Resolved cacert -> $CACERT_PATH"
    RESOLVED_FILES+=("$CACERT_PATH")
fi

# Deduplicate PATH directories in pure bash using an associative array
declare -A SEEN_DIRS
DEDUP_PATH_DIRS=()
for dir in "${GENERATED_PATH_DIRS[@]}"; do
    if [[ -z "${SEEN_DIRS["$dir"]}" ]]; then
        SEEN_DIRS["$dir"]=1
        DEDUP_PATH_DIRS+=("$dir")
    fi
done

# Construct the clean container PATH variable
CONTAINER_PATH="/bin:/scripts:/npm-global/bin"
for dir in "${DEDUP_PATH_DIRS[@]}"; do
    CONTAINER_PATH="${CONTAINER_PATH}:${dir}"
done

# Compute runtime dependency closures for all resolved binaries
CLOSURE_PATHS=$(nix-store -qR "${RESOLVED_FILES[@]}" | sort -u)

NIX_BIND_ARGS=(--tmpfs /nix/store)
for path in $CLOSURE_PATHS; do
  if [ -e "$path" ]; then
    NIX_BIND_ARGS+=(--ro-bind "$path" "$path")
  fi
done

# =====================================================================
# Find bash program
# =====================================================================
BASH_BIN=$(which bash)
ENV_BIN=$(which env)

# =====================================================================
# Find non-patched target binary linking dependencies
# =====================================================================
TARGET_BIN=$(which opencode)

# 1. Wrap the command in ( ) to initialize TARGET_BIN_STORE_PATHS as a proper array
mapfile -t TARGET_BIN_STORE_PATHS < <(ldd "$TARGET_BIN" 2>/dev/null | \
    grep -o '/nix/store/[^/]*' | \
    sort -u)

LINKER_STORE_PATH=$(readlink -f /lib64/ld-linux-x86-64.so.2 | grep -o '/nix/store/[^/]*')
echo "LINKER_STORE_PATH = $LINKER_STORE_PATH"

# 2. This array append now works perfectly
TARGET_BIN_STORE_PATHS+=("$LINKER_STORE_PATH")

# 3. To print an entire array, you must use "${ARRAY_NAME[@]}"
echo "TARGET_BIN_STORE_PATHS ="
printf "  %s\n" "${TARGET_BIN_STORE_PATHS[@]}"

# 4. Build the Bubblewrap read-only bind arguments
TARGET_BIN_BWRAP_ARGS=()
for path in ${TARGET_BIN_STORE_PATHS[@]}; do
    echo "TARGET_BIN_STORE_PATH item: $path"
    TARGET_BIN_BWRAP_ARGS+=("--ro-bind" "$path" "$path")
done

# 5. Also explicitly ensure the target binary's own Nix store directory is mapped 
# (in case it is an absolute path inside the store)
if [[ "$TARGET_BIN" == /nix/store/* ]]; then
    TARGET_BIN_STORE_DIR=$(echo "$TARGET_BIN" | grep -o '/nix/store/[^/]*')
    TARGET_BIN_BWRAP_ARGS+=("--ro-bind" "$TARGET_BIN_STORE_DIR" "$TARGET_BIN_STORE_DIR")
fi

# 6. Check if NIX_LD is set in your current shell
if [ -n "${NIX_LD:-}" ]; then
    echo "NIX_LD is pointing to: $NIX_LD"
    
    # 2. Extract the parent Nix store directory of the fallback linker
    NIX_LD_DIR=$(readlink "$NIX_LD" | grep -o '/nix/store/[^/]*')
    
    # 3. Append this directory to your Bubblewrap mount arguments array
    TARGET_BIN_BWRAP_ARGS+=("--ro-bind" "$NIX_LD_DIR" "$NIX_LD_DIR")
fi

# 7. Also, parse and bind everything inside NIX_LD_LIBRARY_PATH
if [ -n "${NIX_LD_LIBRARY_PATH:-}" ]; then
    # Split the colon-separated paths and bind each folder
    IFS=':' read -ra PATHS <<< "$NIX_LD_LIBRARY_PATH"
    for p in "${PATHS[@]}"; do
        if [ -d "$p" ]; then
            TARGET_BIN_BWRAP_ARGS+=("--ro-bind" "$p" "$p")
        fi
    done
fi


echo "TARGET_BIN_BWRAP_ARGS = "
printf "  %s\n" "${TARGET_BIN_BWRAP_ARGS[@]}"

# Define shared Bubblewrap base flags
BWRAP_BASE_ARGS=(
    --die-with-parent
    --dev /dev
    --proc /proc
    --tmpfs /tmp
    --unshare-all
    --bind "$HOST_CONTAINER_BIN" "$CONTAINER_BIN"
    --bind "$HOST_CONTAINER_HOME" "$CONTAINER_HOME"
    --bind "$HOST_CONTAINER_NPM_GLOBAL" "$CONTAINER_NPM_GLOBAL"
    --bind "$HOST_CONTAINER_SCRIPTS" "$CONTAINER_SCRIPTS"
    --bind "$HOST_CONTAINER_USR" "$CONTAINER_USR"
    --bind "$HOST_CONTAINER_WORKSPACE" "$CONTAINER_WORKSPACE"
    --ro-bind /etc/resolv.conf /etc/resolv.conf
    --symlink "$BASH_BIN" "/bin/bash"
    --symlink "$BASH_BIN" "/bin/sh"
    --symlink "$ENV_BIN" "/usr/bin/env"
    --setenv PATH "$CONTAINER_PATH"
    --setenv HOME "$CONTAINER_USER_HOME"
    --setenv XDG_DATA_HOME "$CONTAINER_USER_CONFIG"
    --setenv NPM_CONFIG_PREFIX "$CONTAINER_NPM_GLOBAL"
    --setenv NPM_CACHE_DIR "$CONTAINER_USER_NPM_CACHE"
    --setenv DSH_HOME "$CONTAINER_USER_HOME"
    --setenv CONTAINER_PORT "$CONTAINER_PORT"
    --setenv TERM "${TERM:-xterm-256color}"
    --setenv TEMP "/tmp"
    --setenv TEMPDIR "/tmp"
    --setenv TMP "/tmp"
    --setenv TMPDIR "/tmp"
    --setenv C_INCLUDE_PATH "$C_INCLUDE_PATH"
    --setenv CPLUS_INCLUDE_PATH "$CPLUS_INCLUDE_PATH"
    --setenv CC_FOR_TARGET "$CC_FOR_TARGET"
    --setenv CC "clang"
    --setenv CXX "clang++"
    --setenv CXX_FOR_TARGET "$CXX_FOR_TARGET"
    --setenv NIX_CFLAGS_COMPILE "$NIX_CFLAGS_COMPILE"
    --setenv NIX_CFLAGS_COMPILE_before "$NIX_CFLAGS_COMPILE_before"
    --setenv NIX_LDFLAGS "$NIX_LDFLAGS"
    --setenv NIX_LDFLAGS_before "$NIX_LDFLAGS_before"
    --setenv NIX_CC_FOR_TARGET "$NIX_CC_FOR_TARGET"
    --setenv NIX_DYNAMIC_LINKER_x86_64_unknown_linux_gnu "$NIX_DYNAMIC_LINKER_x86_64_unknown_linux_gnu"
    --setenv NIX_CC_WRAPPER_TARGET_HOST_x86_64_unknown_linux_gnu "$NIX_CC_WRAPPER_TARGET_HOST_x86_64_unknown_linux_gnu"
    --setenv NIX_CC_WRAPPER_TARGET_TARGET_x86_64_unknown_linux_gnu "$NIX_CC_WRAPPER_TARGET_TARGET_x86_64_unknown_linux_gnu"
    --setenv NIX_BINTOOLS_WRAPPER_TARGET_HOST_x86_64_unknown_linux_gnu "$NIX_BINTOOLS_WRAPPER_TARGET_HOST_x86_64_unknown_linux_gnu"
    --ro-bind /lib64 /lib64
    --setenv LD_LIBRARY_PATH "$LD_LIBRARY_PATH"
)

if [ "$SHARE_NET" = true ]; then
    BWRAP_BASE_ARGS+=(--share-net)
fi

# =====================================================================
# PHASE 1: PRE-INITIALIZE THE ENVIRONMENT (HEADLESS SETUP)
# =====================================================================
echo "=== Phase 1: Pre-initializing container ==="
echo "BASH_BIN = $BASH_BIN"
echo "ENV_BIN = $ENV_BIN"
bwrap \
    "${BWRAP_BASE_ARGS[@]}" \
    "${NIX_BIND_ARGS[@]}" \
    --chdir "$CONTAINER_WORKSPACE" \
    bash -c '
        # npm config set cafile $SSL_CERT_FILE

        # PACKAGE_NAME="pnpm"
        # PACKAGE_VERSION="@11.7.0"
        # if npm list "$PACKAGE_NAME" --depth=0 >/dev/null 2>&1; then
        #     echo "✅ $PACKAGE_NAME is installed locally."
        # else
        #     echo "❌ $PACKAGE_NAME is NOT installed locally."
        #     npm install "$PACKAGE_NAME$PACKAGE_VERSION"            
        # fi

        # PACKAGE_NAME="@deepseek-ai/dsh"
        # PACKAGE_VERSION="@0.2.0-rc.2"
        # if npm list "$PACKAGE_NAME" --depth=0 >/dev/null 2>&1; then
        #     echo "✅ $PACKAGE_NAME is installed locally."
        # else
        #     echo "❌ $PACKAGE_NAME is NOT installed locally."
        #     npm install "$PACKAGE_NAME$PACKAGE_VERSION"
        #     npm approve-scripts "$PACKAGE_NAME$PACKAGE_VERSION"
        # fi
    '

# =====================================================================
# PHASE 2: LAUNCH THE TARGET APP INSTANTLY
# =====================================================================
if [[ "$MODE" == "server" ]]; then
    echo "=== Phase 2: Launching application ==="
    bwrap \
        "${BWRAP_BASE_ARGS[@]}" \
        "${NIX_BIND_ARGS[@]}" \
        "${TARGET_BIN_BWRAP_ARGS[@]}" \
        --setenv PS1 "\[\e[0;36m\][dsh-container]\[\e[38;5;200m\]\w\n\[\e[0;33m\]\$ " \
        --chdir "$CONTAINER_WORKSPACE" \
        bash -c 'opencode serve'
elif [[ "$MODE" == "shell" ]]; then
    echo "=== Phase 2: Launching shell ==="
    bwrap \
        "${BWRAP_BASE_ARGS[@]}" \
        "${NIX_BIND_ARGS[@]}" \
        "${TARGET_BIN_BWRAP_ARGS[@]}" \
        --setenv PS1 "\[\e[0;36m\][dsh-container]\[\e[38;5;200m\]\w\n\[\e[0;33m\]\$ " \
        --chdir "$CONTAINER_WORKSPACE" \
        bash
else
    echo "Unexpected MODE '$MODE'"
fi