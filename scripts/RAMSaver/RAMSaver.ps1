param(
    [ValidateSet('Status', 'Set', 'Restore')][string]$Mode = 'Status',
    [ValidateSet('Balanced', 'Aggressive')][string]$Level = 'Balanced'
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\Modules\Apex.Common.psm1') -Force

$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'
$name = 'GlobalUserDisabled'

try {
    if ($Mode -eq 'Status') {
        $value = (Get-ItemProperty -LiteralPath $key -Name $name -ErrorAction SilentlyContinue).$name
        if ($value -eq 1) { 'AGGRESSIVE' }
        elseif ($value -eq 0) { 'BALANCED' }
        else { 'OFF' }
        exit 0
    }

    if ($Mode -eq 'Set') {
        Save-ApexRegistrySnapshot -Name 'ram-saver' -Values @(@{ Path = $key; Name = $name })
        New-Item -Path $key -Force | Out-Null
        $target = if ($Level -eq 'Aggressive') { 1 } else { 0 }
        Set-ItemProperty -LiteralPath $key -Name $name -Value $target -Type DWord
        $actual = (Get-ItemProperty -LiteralPath $key -Name $name).$name
        if ($actual -ne $target) { throw "Windows did not retain the $Level RAM Saver policy." }
        $result = $Level.ToUpperInvariant()
    } else {
        if (-not (Restore-ApexRegistrySnapshot -Name 'ram-saver')) { throw 'No Apex RAM Saver snapshot exists to restore.' }
        $result = 'OFF (previous policy restored)'
    }

    $log = Write-ApexLog -Action 'RAM Saver' -Result 'Success' -Message $result
    "RAM Saver: $result. Log: $log"
} catch {
    $log = Write-ApexLog -Action 'RAM Saver' -Result 'Failed' -Message $_.Exception.Message
    [Console]::Error.WriteLine("$($_.Exception.Message) Log: $log")
    exit 1
}