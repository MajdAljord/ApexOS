param(
    [string]$Configuration = 'Release',
    [string]$RuntimeIdentifier,
    [switch]$SelfContained
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if ($SelfContained -and [string]::IsNullOrWhiteSpace($RuntimeIdentifier)) {
    throw 'A runtime identifier is required for a self-contained Apex Toolbox publish.'
}

powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'ValidateProject.ps1')
if ($LASTEXITCODE -ne 0) { throw "Project validation failed with exit code $LASTEXITCODE." }

$output = Join-Path $root 'dist/ApexDesktop'
$publishArguments = @(
    (Join-Path $root 'src/ApexToolbox/ApexToolbox.csproj'),
    '--configuration', $Configuration,
    '--output', $output
)
if (-not [string]::IsNullOrWhiteSpace($RuntimeIdentifier)) {
    $publishArguments += @('--runtime', $RuntimeIdentifier)
}
if ($SelfContained) {
    $publishArguments += @('--self-contained', 'true')
}
dotnet publish @publishArguments
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
$wallpaperSource = Join-Path $root 'Wallpapers'
$wallpaperDestination = Join-Path $output 'Wallpapers'
if (Test-Path -LiteralPath $wallpaperDestination) {
    Remove-Item -LiteralPath $wallpaperDestination -Recurse -Force
}
New-Item -Path $wallpaperDestination -ItemType Directory -Force | Out-Null
if (Test-Path -LiteralPath $wallpaperSource -PathType Container) {
    Get-ChildItem -LiteralPath $wallpaperSource -File |
        Where-Object { $_.Extension -in '.jpg', '.jpeg', '.png', '.bmp', '.webp' } |
        ForEach-Object {
        $destination = Join-Path $wallpaperDestination $_.Name
        Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
    }
}
Copy-Item -LiteralPath (Join-Path $root 'README.md') -Destination (Join-Path $output 'README.md') -Force
Write-Output "Apex Toolbox build complete: $output"