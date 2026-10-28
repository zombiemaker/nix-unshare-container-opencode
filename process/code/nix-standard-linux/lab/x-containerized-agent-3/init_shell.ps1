#!/usr/bin/env pwsh
Push-Location
Set-Location $PSScriptRoot
$env:VSC_WORKSPACE_DIR_PATH = $PSScriptRoot
$env:VSC_WORKSPACE_DIR_PATH = $PSScriptRoot
$env:TEMP = "$env:VSC_WORKSPACE_DIR_PATH/.temp"
$env:TEMPDIR = "$env:VSC_WORKSPACE_DIR_PATH/.temp"
$env:TMP = "$env:VSC_WORKSPACE_DIR_PATH/.temp"
$env:TMPDIR = "$env:VSC_WORKSPACE_DIR_PATH/.temp"

if (-not (Test-Path "$($env:VSC_WORKSPACE_DIR_PATH)/.apps")) {
    New-Item -ItemType Directory -Path "$($env:VSC_WORKSPACE_DIR_PATH)/.apps"
}

if (-not (Test-Path "$($env:VSC_WORKSPACE_DIR_PATH)/.apps/bin")) {
    New-Item -ItemType Directory -Path "$($env:VSC_WORKSPACE_DIR_PATH)/.apps/bin"
}

if (-not (Test-Path "$($env:VSC_WORKSPACE_DIR_PATH)/.apps/include")) {
    New-Item -ItemType Directory -Path "$($env:VSC_WORKSPACE_DIR_PATH)/.apps/include"
}

if (-not (Test-Path "$($env:VSC_WORKSPACE_DIR_PATH)/.apps/lib")) {
    New-Item -ItemType Directory -Path "$($env:VSC_WORKSPACE_DIR_PATH)/.apps/lib"
}

if (-not (Test-Path "$($env:VSC_WORKSPACE_DIR_PATH)/.downloads")) {
    New-Item -ItemType Directory -Path "$($env:VSC_WORKSPACE_DIR_PATH)/.downloads"
}

if (-not (Test-Path "$($env:VSC_WORKSPACE_DIR_PATH)/.temp")) {
    New-Item -ItemType Directory -Path "$($env:VSC_WORKSPACE_DIR_PATH)/.temp"
}

if (-not (($env:PATH -split [System.IO.Path]::PathSeparator) -contains "$($env:VSC_WORKSPACE_DIR_PATH)/.apps /bin")) {
    Write-Host "Adding to PATH: $($env:VSC_WORKSPACE_DIR_PATH)/.apps/bin"
    $env:PATH = "$($env:VSC_WORKSPACE_DIR_PATH)/.apps/bin" + [System.IO.Path]::PathSeparator + "$($env:PATH)"
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