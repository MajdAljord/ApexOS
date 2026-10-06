param(
    [ValidateSet('Status','DismCheck','DismScan','DismRepair','SfcVerify','SfcRepair','WindowsUpdateDiagnose','WindowsUpdateRepair','InstallerDiagnose','InstallerRepair','ExplorerRepair','GamingServices','XboxSignIn','WinRE')]
    [string]$Mode='Status'
)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\Modules\Apex.Common.psm1') -Force

function Invoke-LoggedNative {
    param([string]$Action,[string]$Executable,[string[]]$Arguments,[int[]]$AllowedExitCodes=@(0))
    $output=& $Executable @Arguments 2>&1
    $code=$LASTEXITCODE
    $text=($output|Out-String).Trim()
    $result=if($code -in $AllowedExitCodes){'Success'}else{'Failed'}
    $log=Write-ApexLog -Action $Action -Result $result -Message "ExitCode=$code; $text"
    if($code -notin $AllowedExitCodes){throw "$Action failed (exit $code). Log: $log`n$text"}
    "Exit code: $code`n$text`nLog: $log"
}

function Assert-Administrator {
    if(-not(Test-ApexAdministrator)){throw 'This operation requires administrator privileges.'}
}

try {
    if($Mode -eq 'Status'){'Ready';exit 0}
    if($Mode -in @('DismCheck','DismScan','DismRepair','SfcVerify','SfcRepair','WindowsUpdateRepair','InstallerRepair')){Assert-Administrator}

    switch($Mode){
        'DismCheck' { Invoke-LoggedNative 'DISM CheckHealth' 'dism.exe' @('/Online','/Cleanup-Image','/CheckHealth') }
        'DismScan' { Invoke-LoggedNative 'DISM ScanHealth' 'dism.exe' @('/Online','/Cleanup-Image','/ScanHealth') }
        'DismRepair' { Invoke-LoggedNative 'DISM RestoreHealth' 'dism.exe' @('/Online','/Cleanup-Image','/RestoreHealth') }
        'SfcVerify' { Invoke-LoggedNative 'SFC Verify' 'sfc.exe' @('/verifyonly') }
        'SfcRepair' { Invoke-LoggedNative 'SFC Repair' 'sfc.exe' @('/scannow') @(0,1) }
        'WindowsUpdateDiagnose' {
            $services=Get-Service -Name wuauserv,bits,cryptsvc,usosvc -ErrorAction SilentlyContinue|Select-Object Name,Status,StartType
            $recent=@(Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-WindowsUpdateClient/Operational';Level=2;StartTime=(Get-Date).AddDays(-14)} -MaxEvents 20 -ErrorAction SilentlyContinue|Select-Object TimeCreated,Id,Message)
            $report=[pscustomobject]@{Services=$services;RecentErrors=$recent}|ConvertTo-Json -Depth 5
            $log=Write-ApexLog 'Windows Update Diagnostics' 'Complete' "Services=$($services.Count); recent errors=$($recent.Count)"
            "$report`nLog: $log"
        }
        'WindowsUpdateRepair' {
            $names=@('wuauserv','bits','cryptsvc')
            $initial=@(Get-Service -Name $names|Select-Object Name,Status)
            $running=@($initial|Where-Object Status -eq 'Running'|Select-Object -ExpandProperty Name)
            $renamed=[Collections.Generic.List[string]]::new()
            try {
                foreach($service in $running){Stop-Service -Name $service -Force -ErrorAction Stop}
                $stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
                foreach($folder in @('SoftwareDistribution','System32\catroot2')){
                    $source=Join-Path $env:windir $folder
                    if(Test-Path -LiteralPath $source){$destination="$source.ApexBackup-$stamp";Rename-Item -LiteralPath $source -NewName (Split-Path $destination -Leaf);$renamed.Add($destination)}
                }
            } finally {
                foreach($service in $running){Start-Service -Name $service -ErrorAction SilentlyContinue}
            }
            $remaining=@(foreach($service in $running){$current=Get-Service -Name $service;if($current.Status -ne 'Running'){$service}})
            if($remaining.Count){throw "Windows Update caches were archived, but services failed to return to Running: $($remaining -join ', ')"}
            $log=Write-ApexLog 'Windows Update Repair' 'Success' "Archived: $($renamed -join '; '); services restarted. No reboot requested."
            "Archived cache directories: $($renamed -join ', ')`nWindows Update services restarted. No reboot was requested.`nLog: $log"
        }
        'InstallerDiagnose' {
            $service=Get-CimInstance Win32_Service -Filter "Name='msiserver'"|Select-Object Name,State,StartMode,ExitCode
            $version=(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer' -ErrorAction SilentlyContinue).InstallerLocation
            $log=Write-ApexLog 'Windows Installer Diagnostics' 'Complete' "State=$($service.State); StartMode=$($service.StartMode)"
            "Windows Installer service: $($service|ConvertTo-Json -Compress)`nInstaller registry path: $version`nLog: $log"
        }
        'InstallerRepair' {
            $first=Invoke-LoggedNative 'Windows Installer Unregister' 'msiexec.exe' @('/unregister')
            $second=Invoke-LoggedNative 'Windows Installer Register' 'msiexec.exe' @('/regserver')
            "$first`n$second"
        }
        'ExplorerRepair' {
            Get-Process explorer -ErrorAction SilentlyContinue|Stop-Process -Force
            Start-Sleep -Milliseconds 700
            Start-Process explorer.exe
            $log=Write-ApexLog 'Explorer Repair' 'Success' 'Restarted the current-user shell.'
            "Explorer restarted. Log: $log"
        }
        'GamingServices' {
            $packages=@(Get-AppxPackage -AllUsers -Name Microsoft.GamingServices -ErrorAction SilentlyContinue|Select-Object Name,Version,PackageFullName,InstallLocation)
            $services=@(Get-Service -Name GamingServices,GamingServicesNet -ErrorAction SilentlyContinue|Select-Object Name,Status,StartType)
            $log=Write-ApexLog 'Gaming Services Diagnostics' 'Complete' "Packages=$($packages.Count); services=$($services.Count)"
            "Packages: $($packages|ConvertTo-Json -Depth 3)`nServices: $($services|ConvertTo-Json -Depth 3)`nDiagnostic only; no package was removed or reinstalled.`nLog: $log"
        }
        'XboxSignIn' {
            $packages=@(Get-AppxPackage -AllUsers|Where-Object Name -match 'XboxIdentityProvider|XboxApp|GamingServices'|Select-Object Name,Version,PackageFullName)
            $services=@(Get-Service -Name XblAuthManager,XblGameSave,XboxGipSvc,TokenBroker,wlidsvc -ErrorAction SilentlyContinue|Select-Object Name,Status,StartType)
            $log=Write-ApexLog 'Xbox Sign-in Diagnostics' 'Complete' "Packages=$($packages.Count); services=$($services.Count)"
            "Packages: $($packages|ConvertTo-Json -Depth 3)`nSign-in services: $($services|ConvertTo-Json -Depth 3)`nDiagnostic only; no authentication components were changed.`nLog: $log"
        }
        'WinRE' {
            $output=reagentc.exe /info 2>&1
            $code=$LASTEXITCODE
            $log=Write-ApexLog 'WinRE Diagnostics' $(if($code -eq 0){'Success'}else{'Failed'}) "ExitCode=$code; $($output -join ' ')"
            if($code -ne 0){throw "WinRE query failed (exit $code). Log: $log`n$($output -join "`n")"}
            "$($output -join "`n")`nLog: $log"
        }
    }
} catch {
    $log=Write-ApexLog -Action "Repair $Mode" -Result 'Failed' -Message $_.Exception.Message
    [Console]::Error.WriteLine("$($_.Exception.Message) Log: $log")
    exit 1
}