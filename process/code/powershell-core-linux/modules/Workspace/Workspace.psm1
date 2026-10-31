function Clear-WorkspaceTemp {
    if ([string]::IsNullOrWhiteSpace($env:WORKSPACE_ROOT_PATH)) {
        throw "Environment variable 'WORKSPACE_ROOT_PATH' is not set."
    }

    if ([string]::IsNullOrWhiteSpace($env:TEMP)) {
        throw "Environment variable 'TEMP' is not set."
    } 
    else {
        Write-Host "$env:TEMP"
    }

    Get-ChildItem -Path $env:TEMP -Force -ErrorAction SilentlyContinue | 
        Where-Object { 
            $_.Name -like ".bun-*" -or 
            $_.Name -like "nix-develop-*" -or 
            $_.Name -like "nix-shell-*" -or 
            $_.Name -like "clr-debug-*" -or 
            $_.Name -like "CoreFxPipe*" -or 
            $_.Name -like "dotnet-diagnostic*" -or 
            $_.Name -like "nix-shell*"
        } | Remove-Item -Force -Recurse -Confirm:$false -Verbose
}
