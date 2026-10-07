param(
    [string]$Configuration = 'Release',
    [string]$SevenZipPath = "$env:ProgramFiles\7-Zip\7z.exe"
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$playbookSource = Join-Path $root 'playbook-source'
$dist = Join-Path $root 'dist'
$payload = Join-Path $dist 'ApexDesktop'
$stage = Join-Path $dist 'ApexOS-Playbook'
$output = Join-Path $dist 'ApexOS.apbx'
$validator = Join-Path $PSScriptRoot 'validate_playbook.py'

if ($env:OS -ne 'Windows_NT') {
    throw 'BuildApexPlaybook.ps1 must be run on Windows.'
}
if (-not (Test-Path -LiteralPath $SevenZipPath -PathType Leaf)) {
    throw "7-Zip command-line executable not found: $SevenZipPath. Install 7-Zip or pass -SevenZipPath."
}
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    throw 'Python 3 is required to run scripts/validate_playbook.py.'
}

& $python.Source (Join-Path $PSScriptRoot 'validate_project.py')
if ($LASTEXITCODE -ne 0) { throw "Portable project validation failed with exit code $LASTEXITCODE." }
& $python.Source $validator
if ($LASTEXITCODE -ne 0) { throw "Playbook source validation failed with exit code $LASTEXITCODE." }

$architecture = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
$runtimeIdentifier = switch -Regex ($architecture) {
    '^ARM64$' { 'win-arm64'; break }
    '^AMD64$' { 'win-x64'; break }
    default { throw "Apex Playbook packaging requires a Windows 11 x64 or ARM64 build host; detected '$architecture'." }
}

& (Join-Path $PSScriptRoot 'BuildApex.ps1') -Configuration $Configuration -RuntimeIdentifier $runtimeIdentifier -SelfContained
if ($LASTEXITCODE -ne 0) { throw "ApexDesktop build failed with exit code $LASTEXITCODE." }
& $python.Source $validator --payload $payload
if ($LASTEXITCODE -ne 0) { throw "Packaged payload validation failed with exit code $LASTEXITCODE." }

if (Test-Path -LiteralPath $stage) {
    $pathSeparators = [char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $resolvedDist = [IO.Path]::GetFullPath($dist).TrimEnd($pathSeparators) + [IO.Path]::DirectorySeparatorChar
    $resolvedStage = [IO.Path]::GetFullPath($stage)
    if (-not $resolvedStage.StartsWith($resolvedDist, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove staging directory outside dist: $resolvedStage"
    }
    Remove-Item -LiteralPath $resolvedStage -Recurse -Force
}
New-Item -Path $stage -ItemType Directory -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $playbookSource 'playbook.conf') -Destination $stage
Copy-Item -LiteralPath (Join-Path $playbookSource 'Configuration') -Destination $stage -Recurse
Copy-Item -LiteralPath (Join-Path $playbookSource 'Executables') -Destination $stage -Recurse
$payloadStage = Join-Path $stage 'Executables\ApexDesktop'
New-Item -Path $payloadStage -ItemType Directory -Force | Out-Null
Get-ChildItem -LiteralPath $payload -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $payloadStage -Recurse
}

$fixedTimestamp = [DateTime]::SpecifyKind([DateTime]'2020-01-01T00:00:00', [DateTimeKind]::Utc)
Get-ChildItem -LiteralPath $stage -Force -Recurse | ForEach-Object { $_.LastWriteTimeUtc = $fixedTimestamp }
(Get-Item -LiteralPath $stage).LastWriteTimeUtc = $fixedTimestamp

if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output -Force }
Push-Location $stage
try {
    & $SevenZipPath a -t7z -mx=9 -mmt=off -pmalte $output playbook.conf Configuration Executables
    if ($LASTEXITCODE -ne 0) { throw "7-Zip failed with exit code $LASTEXITCODE." }
} finally {
    Pop-Location
}

& $SevenZipPath t -pmalte $output
if ($LASTEXITCODE -ne 0) { throw "7-Zip archive verification failed with exit code $LASTEXITCODE." }
$archiveListing = & $SevenZipPath l -slt $output
if ($LASTEXITCODE -ne 0) { throw "7-Zip archive listing failed with exit code $LASTEXITCODE." }
$archivePaths = @($archiveListing | ForEach-Object {
    if ($_ -match '^Path = (.+)$') { $Matches[1].Replace('/', '\') }
})
foreach ($requiredPath in @('playbook.conf', 'Configuration\main.yml', 'Configuration\tasks\install-apex.yml', 'Executables\Install-Apex.ps1', 'Executables\ApexDesktop\Apex Toolbox.exe')) {
    if ($archivePaths -notcontains $requiredPath) { throw "AME Playbook archive is missing required file: $requiredPath" }
}
if ($archivePaths | Where-Object { [IO.Path]::GetExtension($_) -in '.iso', '.wim', '.esd' }) {
    throw 'AME Playbook archive contains forbidden Windows installation media.'
}

Write-Output "Created AME Wizard Playbook: $output"
