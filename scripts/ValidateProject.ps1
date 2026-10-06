$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$issues = [Collections.Generic.List[string]]::new()
$required = @(
    'README.md', 'BUILD.md', 'CONTRIBUTING.md', 'LICENSE',
    'config/toolbox.json', 'config/protected-components.json',
    'src/ApexToolbox/ApexToolbox.csproj', 'scripts/Modules/Apex.Common.psm1'
)

foreach ($file in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $file))) { $issues.Add("Missing file: $file") }
}
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) { $issues.Add('Missing dependency: .NET SDK (dotnet)') }

$config = $null
try { $config = Get-Content -LiteralPath (Join-Path $root 'config/toolbox.json') -Raw | ConvertFrom-Json }
catch { $issues.Add("Invalid JSON in toolbox.json: $($_.Exception.Message)") }
try { Get-Content -LiteralPath (Join-Path $root 'config/protected-components.json') -Raw | ConvertFrom-Json | Out-Null }
catch { $issues.Add("Invalid JSON in protected-components.json: $($_.Exception.Message)") }

if ($config) {
    if (-not $config.actions -or $config.actions.Count -eq 0) { $issues.Add('Toolbox configuration has no actions.') }
    $ids = @{}
    foreach ($action in $config.actions) {
        if ($ids.ContainsKey($action.id)) { $issues.Add("Duplicate action id: $($action.id)") }
        $ids[$action.id] = $true
        if (-not $action.category -or -not $action.title -or -not $action.description) { $issues.Add("Incomplete action metadata: $($action.id)") }
        $scriptPath = [IO.Path]::GetFullPath((Join-Path $root $action.script))
        if (-not $scriptPath.StartsWith(($root.TrimEnd('\') + '\'), [StringComparison]::OrdinalIgnoreCase)) { $issues.Add("Action script path escapes project: $($action.script)") }
        elseif (-not (Test-Path -LiteralPath $scriptPath)) { $issues.Add("Missing action script: $($action.script)") }
        foreach ($field in @('statusArgs', 'applyArgs', 'restoreArgs')) {
            if ($null -eq $action.$field) { $issues.Add("Missing $field on action: $($action.id)") }
        }
    }
}

$hashes = @{}
Get-ChildItem -LiteralPath (Join-Path $root 'scripts') -Recurse -File |
    Where-Object { $_.Extension -in '.ps1', '.psm1' } |
    ForEach-Object {
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        if ($hashes.ContainsKey($hash)) { $issues.Add("Duplicate script content: $($_.FullName) and $($hashes[$hash])") }
        else { $hashes[$hash] = $_.FullName }
    }

Get-ChildItem -LiteralPath (Join-Path $root 'scripts') -Recurse -File | Where-Object { $_.Extension -in '.ps1', '.psm1' } | ForEach-Object {
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
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