param([string]$Configuration = 'Release')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'ValidateProject.ps1')
if ($LASTEXITCODE -ne 0) { throw "Project validation failed with exit code $LASTEXITCODE." }

$output = Join-Path $root 'dist/ApexDesktop'
dotnet publish (Join-Path $root 'src/ApexToolbox/ApexToolbox.csproj') --configuration $Configuration --output $output
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed with exit code $LASTEXITCODE." }

$folders = @(
    'Tools', 'Packages', 'Wallpapers', 'Backups', 'Logs',
    'Toolbox/ConfigurationServices', 'Toolbox/Scripts', 'Toolbox/Registry', 'Toolbox/Logs', 'Toolbox/config',
    'Scripts/Performance', 'Scripts/Gaming', 'Scripts/RAMSaver', 'Scripts/Power', 'Scripts/Drivers',
    'Scripts/Network', 'Scripts/Windows', 'Scripts/Explorer', 'Scripts/Security', 'Scripts/Repair',
    'Scripts/Diagnostics', 'Scripts/Privacy', 'Scripts/Modules'
)
foreach ($folder in $folders) {
    New-Item -Path (Join-Path $output $folder) -ItemType Directory -Force | Out-Null
}
Copy-Item -LiteralPath (Join-Path $root 'README.md') -Destination (Join-Path $output 'README.md') -Force
Write-Output "Apex Toolbox build complete: $output"