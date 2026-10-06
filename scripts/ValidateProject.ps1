$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$issues = [Collections.Generic.List[string]]::new()
$isSource = Test-Path -LiteralPath (Join-Path $root 'src/ApexToolbox/ApexToolbox.csproj')
$configPath = Join-Path $root 'config/toolbox.json'
$protectedPath = Join-Path $root 'config/protected-components.json'
if (-not $isSource) {
    $configPath = Join-Path $root 'Toolbox/config/toolbox.json'
    $protectedPath = Join-Path $root 'Toolbox/config/protected-components.json'
}
$required = if ($isSource) {
    @('README.md','BUILD.md','CONTRIBUTING.md','LICENSE','docs/WINDOWS-VM-TESTING.md','src/ApexToolbox/ApexToolbox.csproj')
} else {
    @('README.md','Apex Toolbox.exe')
}
$required += @('scripts/Modules/Apex.Common.psm1')

foreach ($file in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $file))) { $issues.Add("Missing file: $file") }
}
if (-not (Test-Path -LiteralPath $configPath)) { $issues.Add("Missing Toolbox configuration: $configPath") }
if (-not (Test-Path -LiteralPath $protectedPath)) { $issues.Add("Missing protected-components manifest: $protectedPath") }
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) { $issues.Add('Missing dependency: .NET host (dotnet)') }

$config = $null
try { $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json }
catch { $issues.Add("Invalid Toolbox JSON: $($_.Exception.Message)") }
try { Get-Content -LiteralPath $protectedPath -Raw | ConvertFrom-Json | Out-Null }
catch { $issues.Add("Invalid protected-components JSON: $($_.Exception.Message)") }

if ($config) {
    if (-not $config.actions -or $config.actions.Count -eq 0) { $issues.Add('Toolbox configuration has no actions.') }
    $ids = @{}
    foreach ($action in $config.actions) {
        if ($ids.ContainsKey($action.id)) { $issues.Add("Duplicate action id: $($action.id)") }
        $ids[$action.id] = $true
        if (-not $action.category -or -not $action.title -or -not $action.description) { $issues.Add("Incomplete action metadata: $($action.id)") }
        if (-not $action.script.StartsWith('scripts/', [StringComparison]::OrdinalIgnoreCase)) { $issues.Add("Action script path must start with scripts/: $($action.script)"); continue }
        $scriptPath = [IO.Path]::GetFullPath((Join-Path $root $action.script))
        $rootPrefix = [IO.Path]::GetFullPath($root).TrimEnd('\') + '\'
        if (-not $scriptPath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { $issues.Add("Action script path escapes project: $($action.script)") }
        elseif (-not (Test-Path -LiteralPath $scriptPath)) { $issues.Add("Missing action script: $($action.script)") }
        foreach ($field in @('statusArgs','applyArgs','restoreArgs')) {
            if ($null -eq $action.$field) { $issues.Add("Missing $field on action: $($action.id)") }
        }
    }
}

$scriptRoot = Join-Path $root 'scripts'
$hashes = @{}
Get-ChildItem -LiteralPath $scriptRoot -Recurse -File | Where-Object { $_.Extension -in '.ps1','.psm1' } | ForEach-Object {
    $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    if ($hashes.ContainsKey($hash)) { $issues.Add("Duplicate script content: $($_.FullName) and $($hashes[$hash])") }
    else { $hashes[$hash] = $_.FullName }
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$parseErrors) | Out-Null
    foreach ($parseError in $parseErrors) { $issues.Add("PowerShell syntax error in $($_.Name): $($parseError.Message)") }
}

Get-ChildItem -LiteralPath $root -Recurse -Filter '*.reg' | ForEach-Object {
    if ((Get-Content -LiteralPath $_.FullName -TotalCount 1) -ne 'Windows Registry Editor Version 5.00') {
        $issues.Add("Invalid registry header: $($_.FullName)")
    }
}

if ($issues.Count) {
    $issues | ForEach-Object { [Console]::Error.WriteLine("ERROR: $_") }
    exit 1
}
Write-Output "Apex validation passed ($($config.actions.Count) configured actions)."
exit 0