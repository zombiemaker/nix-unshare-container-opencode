# Process Feature Spec 0000: Containerized AI Agent Environment

## From Outside Containerized Environment
- View / edit container user home directory
- Edit container user ~/.kube/config
- Connect to IPv4 services running inside container (e.g. OpenCode Web)

## From Inside Containerized Environment
- Persist container images across container instances
- Use OpenCode CLI
- Use OpenCode Web
- Use Buildah to build container images
- Use Podman to run containers
- Use kubectl to connect to Kubernetes clusters
- Use k9s to connect to Kubernetes clusters
- Deploy container images built inside container to Kubernetes clusters outside container
- Build Go source code programs for x86_64-linux, wasm-no_os, wasm-wasi
- Use Clang to build C source code programs for x86_64-linux, wasm-no_os, wasm-wasi
- Use Clang to build C++ source code programs
- Build Rust source code programs for x86_64-linux, wasm-no_os, wasm-wasi