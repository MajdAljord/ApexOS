param([ValidateSet('Status','Check')][string]$Mode='Status')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\Modules\Apex.Common.psm1') -Force
try {
    $current=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $build=[int]$current.CurrentBuildNumber
    $isWindows11=$build -ge 22000 -and $current.ProductName -notmatch 'Server'
    $release=[string]$current.DisplayVersion
    $details=[pscustomobject]@{
        Product=$current.ProductName
        DisplayVersion=$release
        Build=$build
        Architecture=$env:PROCESSOR_ARCHITECTURE
        IsWindows11=$isWindows11
        Is26H2=($release -eq '26H2')
        ApexWindowsTestsPassed=$false
    }
    if($Mode -eq 'Status'){'Ready';exit 0}
    $log=Write-ApexLog -Action 'Windows Compatibility Check' -Result 'Complete' -Message ($details|ConvertTo-Json -Compress)
    "$($details|ConvertTo-Json -Depth 3)`nApex Windows tests have not been run on this build. Log: $log"
}catch{$log=Write-ApexLog -Action 'Windows Compatibility Check' -Result 'Failed' -Message $_.Exception.Message;[Console]::Error.WriteLine("$($_.Exception.Message) Log: $log");exit 1}