## Strict Repository & Directory Architecture

You MUST organize all generated code, files, data, and documentation according to the explicit top-level boundaries, tri-domain subdirectories, toolchain/runtime layouts, component structures, and environment lifecycles defined below. Never mix spaces or drift from this schema.

### 1. Top-Level Workspace Directories
The root of the workspace is divided into three mutually exclusive top-level directories. Every generated asset must resolve into exactly one of these scopes:

* **`product/` (Product Content):** All core application source code, product configurations, domain assets, data, and user-facing or technical documentation.
* **`process/` (CI/CD/Devops/Tools):** All infrastructure-as-code, automation scripts, pipelines, developer tool configurations, workflows, and process-related instructions.
* **`external/` (Third-Party & Multi-Repo Assets):** Content pulled from other repositories, vendor dependencies, or multi-repo integrations mapped into the local environment.

### 2. Tri-Domain Subdirectory Strategy
Within each of the three top-level directories (`product/`, `process/`, and `external/`), you MUST enforce a flat, three-pronged subdirectory pattern:

* **`code/`:** Contains all executable logic, application binaries, script modules, and source units.
* **`data/`:** Contains all database schemas, seed datasets, static assets, configuration matrices, JSON/YAML models, or runtime payloads.
* **`doc/`:** Contains all architectural decisions records (ADRs), user guides, markdown readmes, or process specifications.

### 3. Language, Toolchain, & Runtime Matrix Blueprint
Under any `code/` subdirectory, assets must be grouped using a strict tri-part snake_case format: **`[language]-[build_time_toolchain]-[runtime]`**. 

For each matrix directory, code must be divided into **separately deployable program components** (e.g., specific microservices, gateways, or matching library units). Client API libraries must live under their corresponding language-toolchain-runtime directories.

```text
workspace_root/
├── product/
│   ├── code/
│   │   ├── go-standard-linux/
│   │   │   ├── api_gateway/                       # Separately Deployable Component
│   │   │   │   ├── production/                    # Production code
│   │   │   │   │   ├── cmd/                       # Contains the main applications/entry points for the project.
│   │   │   │   │   │   ├── cli/
│   │   │   │   │   │   ├── api-server/
│   │   │   │   │   │   └── worker-server/
│   │   │   │   │   ├── internal/                  # Contains private application and package code
│   │   │   │   │   ├── pkg/                       # Contains reusable public utility code
│   │   │   │   │   └── vendor/                    # Contains code external to Go module
│   │   │   │   ├── test/                          # Unit & integration test code
│   │   │   │   └── lab/                           # Experiments / POC code
│   │   │   ├── scheduler/                         # Separately Deployable Component
│   │   │   │   ├── production/                    # Production code
│   │   │   │   │   ├── cmd/                       # Contains the main applications/entry points for the project.
│   │   │   │   │   │   ├── cli/
│   │   │   │   │   │   ├── api-server/
│   │   │   │   │   │   └── worker-server/
│   │   │   │   │   ├── internal/                  # Contains private application and package code
│   │   │   │   │   ├── pkg/                       # Contains reusable public utility code
│   │   │   │   │   └── vendor/                    # Contains code external to Go module
│   │   │   │   ├── test/                          # Unit & integration test code
│   │   │   │   └── lab/                           # Experiments / POC code
│   │   │   ├── client_request_handler/            # Separately Deployable Component
│   │   │   │   ├── production/                    # Production code
│   │   │   │   │   ├── cmd/                       # Contains the main applications/entry points for the project.
│   │   │   │   │   │   ├── cli/
│   │   │   │   │   │   ├── api-server/
│   │   │   │   │   │   └── worker-server/
│   │   │   │   │   ├── internal/                  # Contains private application and package code
│   │   │   │   │   ├── pkg/                       # Contains reusable public utility code
│   │   │   │   │   └── vendor/                    # Contains code external to Go module
│   │   │   │   ├── test/                          # Unit & integration tests
│   │   │   │   └── lab/                           # Experiments / POC code
│   │   │   ├── event_datastore_service/           # Separately Deployable Component
│   │   │   │   ├── production/                    # Production code
│   │   │   │   │   ├── cmd/                       # Contains the main applications/entry points for the project.
│   │   │   │   │   │   ├── cli/
│   │   │   │   │   │   ├── api-server/
│   │   │   │   │   │   └── worker-server/
│   │   │   │   │   ├── internal/                  # Contains private application and package code
│   │   │   │   │   │   ├── context/
│   │   │   │   │   │   │   ├── api-server/
│   │   │   │   │   │   │   └── api-server/
│   │   │   │   │   │   └── platform/
│   │   │   │   │   ├── pkg/                       # Contains reusable public utility code
│   │   │   │   │   └── vendor/                    # Contains code external to Go module
│   │   │   │   ├── test/                          # Unit & integration test code
│   │   │   │   └── lab/                           # Experiments / POC code
│   │   │   ├── projection_datastore_service/      # Separately Deployable Component
│   │   │   │   ├── production/                    # Production code
│   │   │   │   │   ├── cmd/                       # Contains the main applications/entry points for the project.
│   │   │   │   │   │   ├── cli/
│   │   │   │   │   │   ├── api-server/
│   │   │   │   │   │   └── worker-server/
│   │   │   │   │   ├── internal/                  # Contains private application and package code
│   │   │   │   │   │   ├── context/
│   │   │   │   │   │   │   ├── columnar/
│   │   │   │   │   │   │   ├── document/
│   │   │   │   │   │   │   ├── graph/
│   │   │   │   │   │   │   ├── kv/
│   │   │   │   │   │   │   ├── relational/
│   │   │   │   │   │   │   ├── time/
│   │   │   │   │   │   │   └── api-server/
│   │   │   │   │   │   └── platform/
│   │   │   │   │   ├── pkg/                       # Contains reusable public utility code
│   │   │   │   │   └── vendor/                    # Contains code external to Go module
│   │   │   │   ├── test/                          # Unit & integration test code
│   │   │   │   └── lab/                           # Experiments / POC code
│   │   │   ├── agent_runner_service/              # Separately Deployable Component
│   │   │   │   ├── production/                    # Production code
│   │   │   │   ├── test/                          # Unit & integration test code
│   │   │   │   └── lab/                           # Experiments / POC code
│   │   │   ├── agent_memory_service/              # Separately Deployable Component
│   │   │   │   ├── production/                    # Production code
│   │   │   │   ├── test/                          # Unit & integration test code
│   │   │   │   └── lab/                           # Experiments / POC code
│   │   │   ├── agent_tool_service/                # Separately Deployable Component
│   │   │   │   ├── production/                    # Production code
│   │   │   │   ├── test/                          # Unit & integration test code
│   │   │   │   └── lab/                           # Experiments / POC code
│   │   │   └── go_client_api/                     # Standard Go Client API component
│   │   ├── go-standard-wasm_3/
│   │   ├── go-standard-wasm_3_wasi_p1/
│   │   ├── go-tinygo-linux/
│   │   ├── go-tinygo-wasm_3/
│   │   ├── go-tinygo-wasm_3_wasi_p2/             # TinyGo compiled for WASI Preview 2
│   │   ├── javascript-standard-web_browser/
│   │   │   └── javascript_client_api/             # Browser-based JS Client API library
│   │   ├── javascript-standard-nodejs/
│   │   │   └── javascript_client_api/             # Node.js-based JS Client API library
│   │   ├── javascript-standard-deno/
│   │   │   └── javascript_client_api/             # Node.js-based JS Client API library
│   │   ├── javascript-standard-bun/
│   │   │   └── javascript_client_api/             # Node.js-based JS Client API library
│   │   ├── javascript-standard-cloudflare_worker/
│   │   │   └── javascript_client_api/             # Node.js-based JS Client API library
│   │   ├── typescript-standard-web_browser/
│   │   │   └── typescript_client_api/             # Browser-targeted TS Client API library
│   │   ├── typescript-standard-nodejs/
│   │   │   └── typescript_client_api/             # Node.js-targeted TS Client API library
│   │   ├── python-cpython-linux/                  # Standard Python on Linux
│   │   │   ├── python_client_api/                 # Python-specific Client API library
│   │   │   │   ├── production/
│   │   │   │   ├── test/
│   │   │   │   └── lab/
│   │   │   └── data_processor_service/            # Example standalone python component
│   │   ├── python-cpython-aws_lambda/             # Python optimized for serverless runtimes
│   │   ├── python-pypy-linux/                     # PyPy JIT-compiled for high-performance execution
│   │   ├── python-micro_python-esp32/             # MicroPython targeting microcontrollers
│   │   ├── nix-standard-linux/                    # Nix on Linux environments
│   │   ├── powershell-core-linux/                 # PowerShell 7+ on Linux environments
│   │   ├── powershell-core-windows/               # PowerShell 7+ on Windows environments
│   │   └── powershell-desktop-windows/            # Legacy Windows PowerShell 5.1
│   ├── data/
│   └── doc/
│       ├── adr/                                   # Architectural Decision Records
│       │   └── 0001-repo-directory-standard.md    # This specification file
│       └── features/                              # Fluid Feature Specifications
├── process/
│   ├── code/
│   │   ├── nix-standard-linux/                    # Nix on Linux environments
│   │   ├── powershell-core-linux/                 # PowerShell 7+ on Linux environments
│   │   ├── powershell-core-windows/               # PowerShell 7+ on Windows environments
│   │   └── powershell-desktop-windows/            # Legacy Windows PowerShell 5.1
│   ├── data/
│   └── doc/
└── external/
```

### 4. Deployable Component Lifecycle Boundaries
Every component directory found under a `[language]-[build_time_toolchain]-[runtime]/` structure MUST implement exactly three rigid environment/lifecycle subdirectories. Never put logic directly under the component root.

* **`production/`:** Holds production-grade source code, configuration manifests, and official application entries. This code must be optimized, clean, and complete.
* **`test/`:** Holds all automated unit tests, integration suites, mocking utilities, and test suites assigned to validate the production logic.
* **`lab/`:** Reserved entirely for experimental architectures, rapid prototyping, temporary proof-of-concept scripts, and sandbox code.

### 5. Architectural Violations & Guardrails (Strict Bans)
* **No Stray Files:** Do not create source code files inside a language-toolchain-runtime directory or a component directory root. Files belong strictly within `production/`, `test/`, or `lab/`.
* **Cross-Contamination:** Never mix production logic into the `lab/` directory, and never import `lab/` or `test/` modules into files located inside the `production/` tree.
* **Naming Alignment:** All microservices and library component folder names must use `snake_case` (e.g., `client_request_handler`, `typescript_client_api`). Do not use dashes (`-`) for component directory names to prevent layout-parsing confusion with the top-level folder syntax.
