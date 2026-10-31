#!/usr/bin/env pwsh
Push-Location
Set-Location $PSScriptRoot
$env:WORKSPACE_ROOT_PATH = $PSScriptRoot
$env:PSModulePath = "$($env:WORKSPACE_ROOT_PATH)/process/code/powershell-core-linux/modules" +
    [System.IO.Path]::PathSeparator + "$($env:WORKSPACE_ROOT_PATH)/process/code/powershell-core-windows/modules" +
    [System.IO.Path]::PathSeparator + "$($env:WORKSPACE_ROOT_PATH)/product/code/powershell-core-linux/modules" +
    [System.IO.Path]::PathSeparator + "$($env:WORKSPACE_ROOT_PATH)/product/code/powershell-core-windows/modules" +
    [System.IO.Path]::PathSeparator + "$($env:PSModulePath)"
$env:TEMP = "$env:WORKSPACE_ROOT_PATH/.temp"
$env:TEMPDIR = "$env:TEMP"
$env:TMP = "$env:TEMP"
$env:TMPDIR = "$env:TEMP"

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/.apps")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/.apps"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/.apps/bin")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/.apps/bin"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/.apps/include")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/.apps/include"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/.apps/lib")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/.apps/lib"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/.opencode")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/.opencode"
}

if (-not (Test-Path "$($env:TEMP)")) {
    New-Item -ItemType Directory -Path "$($env:TEMP)"
}

if (-not (Test-Path "$($env:TEMP)/builds")) {
    New-Item -ItemType Directory -Path "$($env:TEMP)/builds"
}

if (-not (Test-Path "$($env:TEMP)/downloads")) {
    New-Item -ItemType Directory -Path "$($env:TEMP)/downloads"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/external/releases")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/external/releases"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/external/repos")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/external/repos"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/process/code/")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/process/code"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/process/code/gnu_bash-standard-linux")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/process/code/gnu_bash-standard-linux"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/process/code/gnu_bash-standard-linux/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/process/code/nix-standard-linux")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/process/code/nix-standard-linux"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/process/code/nix-standard-linux/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/process/code/powershell-core-linux")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/process/code/powershell-core-linux"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/process/code/powershell-core-linux/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/process/code/powershell-core-linux/modules")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/process/code/powershell-core-linux/modules"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/process/code/powershell-core-linux/modules/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/process/code/powershell-core-linux/scripts")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/process/code/powershell-core-linux/scripts"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/process/code/powershell-core-linux/scripts/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/process/code/python-cpython")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/process/code/python-cpython"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/process/code/python-cpython/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/process/data/")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/process/data"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/process/data/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/process/doc"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/adr")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/adr"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/adr/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/design_pattern")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/design_pattern"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/design_pattern/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/design_pattern/activity_system")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/design_pattern/activity_system"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/design_pattern/activity_system/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/design_pattern/application_system")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/design_pattern/application_system"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/design_pattern/application_system/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/design_pattern/computer_system")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/design_pattern/computer_system"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/design_pattern/computer_system/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/design_pattern/computer_network_system")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/design_pattern/computer_network_system"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/design_pattern/computer_network_system/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/design_pattern/data_storage_system")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/design_pattern/data_storage_system"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/design_pattern/data_storage_system/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/design_pattern/human_system")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/design_pattern/human_system"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/design_pattern/human_system/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/design_pattern/os_process_system")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/design_pattern/os_process_system"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/design_pattern/os_process_system/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/feature")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/feature"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/feature_impl")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/feature_impl"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/feature_impl/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/technology")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/technology"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/technology/products")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/technology/products"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/technology/products/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/technology/standards")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/technology/standards"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/process/doc/technology/standards/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/product/code/")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/product/code"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/product/code/")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/process/code"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/product/code/gnu_bash-standard-linux")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/product/code/gnu_bash-standard-linux"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/product/code/gnu_bash-standard-linux/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/product/code/nix-standard-linux")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/product/code/nix-standard-linux"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/product/code/nix-standard-linux/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/product/code/powershell-core-linux")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/product/code/powershell-core-linux"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/product/code/powershell-core-linux/modules")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/product/code/powershell-core-linux/modules"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/product/code/powershell-core-linux/modules/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/product/code/powershell-core-linux/scripts")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/product/code/powershell-core-linux/scripts"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/product/code/powershell-core-linux/scripts/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/product/code/python-cpython")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/product/code/python-cpython"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/product/code/python-cpython/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/product/data/")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/product/data"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/product/doc"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/adr")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/adr"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/adr/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/design_pattern/activity_system")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/design_pattern/activity_system"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/design_pattern/activity_system/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/design_pattern/application_system")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/design_pattern/application_system"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/design_pattern/application_system/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/design_pattern/computer_system")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/design_pattern/computer_system"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/design_pattern/computer_system/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/design_pattern/computer_network_system")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/design_pattern/computer_network_system"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/design_pattern/computer_network_system/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/design_pattern/data_storage_system")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/design_pattern/data_storage_system"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/design_pattern/data_storage_system/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/design_pattern/os_process_system")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/design_pattern/os_process_system"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/design_pattern/os_process_system/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/design_pattern/human_system")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/design_pattern/human_system"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/design_pattern/human_system/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/feature")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/feature"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/feature/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/feature_impl")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/feature_impl"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/feature_impl/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/technology")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/technology"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/technology/products")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/technology/products"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/technology/products/.emptydir"
}

if (-not (Test-Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/technology/standards")) {
    New-Item -ItemType Directory -Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/technology/standards"
    New-Item -ItemType File -Path "$($env:WORKSPACE_ROOT_PATH)/product/doc/technology/standards/.emptydir"
}

if (-not (($env:PATH -split [System.IO.Path]::PathSeparator) -contains "$($env:WORKSPACE_ROOT_PATH)/.apps/bin")) {
    Write-Host "Adding to PATH: $($env:WORKSPACE_ROOT_PATH)/.apps/bin"
    $env:PATH = "$($env:WORKSPACE_ROOT_PATH)/.apps/bin" + [System.IO.Path]::PathSeparator + "$($env:PATH)"
}

if (-not (($env:PATH -split [System.IO.Path]::PathSeparator) -contains "$($env:WORKSPACE_ROOT_PATH)/process/code/gnu_bash-standard-linux/production")) {
    Write-Host "Adding to PATH: $($env:WORKSPACE_ROOT_PATH)/process/code/gnu_bash-standard-linux/production"
    $env:PATH = "$($env:WORKSPACE_ROOT_PATH)/process/code/gnu_bash-standard-linux/production" + [System.IO.Path]::PathSeparator + "$($env:PATH)"
}

Pop-Location

Write-Host @"
To start Nix Flake shell:
    nix develop .#shells.<cpu_isa>.<os_family>(.<os_variants>).<name-of-shell>

Example:
    nix devlop .#shells.x86_64.linux.gnu_libc.pwsh_pixi_cpython
"@

$title = "Confirmation Required"
$message = @"
Which Nix shell environment:

0 = None
1 = latest.shells.x86_64.linux_nixos.shell
2 = latest.shells.x86_64.linux_nixos.server
3 = latest.shells.x86_64.linux.shell
4 = latest.shells.x86_64.linux.server
"@
$options = (0, 1, 2, 3, 4)
$default = 0 # Default to 'Yes' (index 0) if the user hits Enter

# Display the prompt and capture the choice index (0 for Yes, 1 for No)
$choice = $Host.UI.PromptForChoice($title, $message, $options, $default)

# Conditionally execute code based on the choice
switch ($choice) {
    0 {
        Write-Host "Starting without Nix shell environment"
    }

    1 {
        Write-Host "Starting Nix shell environment latest.shells.x86_64.linux_nixos.shell" -ForegroundColor Green
        nix develop .#latest.shells.x86_64.linux_nixos.shell
    }

    2 {
        Write-Host "Starting Nix shell environment latest.shells.x86_64.linux_nixos.server" -ForegroundColor Green
        nix develop .#latest.shells.x86_64.linux_nixos.server
    }

    3 {
        Write-Host "Starting Nix shell environment latest.shells.x86_64.linux.shell" -ForegroundColor Green
        nix develop .#latest.shells.x86_64.linux.shell
    }

    4 {
        Write-Host "Starting Nix shell environment latest.shells.x86_64.linux.server" -ForegroundColor Green
        nix develop .#latest.shells.x86_64.linux.server
    }
}