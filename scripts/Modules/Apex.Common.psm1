Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:ApexRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))

function Get-ApexRoot { return $script:ApexRoot }

function Get-ApexWritableDirectory {
    param([Parameter(Mandatory)][string]$Preferred, [Parameter(Mandatory)][string]$Fallback)
    foreach ($directory in @($Preferred, $Fallback)) {
        try {
            New-Item -Path $directory -ItemType Directory -Force | Out-Null
            $probe = Join-Path $directory ('.apex-write-' + [guid]::NewGuid().ToString('N'))
            Set-Content -LiteralPath $probe -Value 'test' -ErrorAction Stop
            Remove-Item -LiteralPath $probe -Force
            return $directory
        } catch {
            if ($directory -eq $Fallback) { throw }
        }
    }
}

function Get-ApexLogDirectory {
    return (Get-ApexWritableDirectory (Join-Path $script:ApexRoot 'Logs') (Join-Path $env:LOCALAPPDATA 'ApexOS\Logs'))
}

function Get-ApexBackupDirectory {
    return (Get-ApexWritableDirectory (Join-Path $script:ApexRoot 'Backups') (Join-Path $env:LOCALAPPDATA 'ApexOS\Backups'))
}

function Write-ApexLog {
    param([Parameter(Mandatory)][string]$Action, [Parameter(Mandatory)][string]$Result, [string]$Message = '')
    $directory = Get-ApexLogDirectory
    $path = Join-Path $directory ("Apex-{0}-{1}.log" -f ($Action -replace '[^A-Za-z0-9-]', '-'), (Get-Date -Format 'yyyy-MM-dd'))
    Add-Content -LiteralPath $path -Value ("{0} | {1} | {2} | {3}" -f (Get-Date -Format o), $Action, $Result, $Message)
    return $path
}

function Test-ApexAdministrator {
    $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-ApexSnapshotPath {
    param([Parameter(Mandatory)][string]$Name)
    $directory = Get-ApexWritableDirectory (Join-Path $script:ApexRoot 'Backups\Settings') (Join-Path $env:LOCALAPPDATA 'ApexOS\Backups\Settings')
    return Join-Path $directory "$Name.json"
}

function Get-ApexSnapshotDirectory {
    return (Split-Path (Get-ApexSnapshotPath -Name '.apex-path-probe') -Parent)
}

function Save-ApexRegistrySnapshot {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][array]$Values)
    $path = Get-ApexSnapshotPath -Name $Name
    if (Test-Path -LiteralPath $path) { return }
    $snapshot = foreach ($item in $Values) {
        $key = Get-Item -LiteralPath $item.Path -ErrorAction SilentlyContinue
        $exists = $null -ne $key -and $key.GetValueNames() -contains $item.Name
        [pscustomobject]@{
            Path = $item.Path
            Name = $item.Name
            Exists = $exists
            Value = if ($exists) { $key.GetValue($item.Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) } else { $null }
            Kind = if ($exists) { [string]$key.GetValueKind($item.Name) } else { 'DWord' }
        }
    }
    $snapshot | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $path -Encoding UTF8
}

function Restore-ApexRegistrySnapshot {
    param([Parameter(Mandatory)][string]$Name)
    $path = Get-ApexSnapshotPath -Name $Name
    if (-not (Test-Path -LiteralPath $path)) { return $false }
    foreach ($item in (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)) {
        if ($item.Exists) {
            New-Item -Path $item.Path -Force | Out-Null
            $kind = [Enum]::Parse([Microsoft.Win32.RegistryValueKind], [string]$item.Kind)
            Set-ItemProperty -LiteralPath $item.Path -Name $item.Name -Value $item.Value -Type $kind -Force
        } else {
            Remove-ItemProperty -LiteralPath $item.Path -Name $item.Name -ErrorAction SilentlyContinue
        }
    }
    Remove-Item -LiteralPath $path -Force
    return $true
}

Export-ModuleMember -Function Get-ApexRoot, Get-ApexLogDirectory, Get-ApexBackupDirectory, Get-ApexSnapshotPath, Get-ApexSnapshotDirectory, Write-ApexLog, Test-ApexAdministrator, Save-ApexRegistrySnapshot, Restore-ApexRegistrySnapshot