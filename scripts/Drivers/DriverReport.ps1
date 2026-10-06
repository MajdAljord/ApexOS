param(
    [ValidateSet('Status','List','Problems','Display','Network','Audio','USB','Bluetooth','Export','SearchUpdates')]
    [string]$Mode='Status'
)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\Modules\Apex.Common.psm1') -Force

function Write-DriverLog {
    param([string]$Action,[string]$Detail)
    $log=Write-ApexLog -Action $Action -Result 'Success' -Message $Detail
    "`nLog: $log"
}

try {
    if($Mode -eq 'Status'){'Ready';exit 0}
    $allDrivers=@(Get-CimInstance Win32_PnPSignedDriver)

    if($Mode -eq 'Export'){
        $directory=Get-ApexLogDirectory
        $path=Join-Path $directory ("Apex-Drivers-{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
        $allDrivers|Select-Object DeviceName,DeviceID,DriverProviderName,DriverVersion,DriverDate,IsSigned,InfName|Export-Csv -LiteralPath $path -NoTypeInformation -Encoding UTF8
        $log=Write-ApexLog -Action 'Driver Inventory Export' -Result 'Success' -Message $path
        "Driver inventory exported: $path`nLog: $log"
        exit 0
    }

    if($Mode -eq 'Problems'){
        $devices=@(Get-CimInstance Win32_PnPEntity|Where-Object { $_.ConfigManagerErrorCode -ne 0 }|Select-Object Name,PNPDeviceID,PNPClass,ConfigManagerErrorCode,Status)
        if(-not $devices.Count){'No device-reported driver errors found.'}else{$devices|Format-Table -AutoSize|Out-String|Write-Output}
        $missing=@($devices|Where-Object ConfigManagerErrorCode -eq 28)
        "Problem devices: $($devices.Count); missing-driver indicators: $($missing.Count)"
        Write-DriverLog 'Driver Problem Scan' "Problems=$($devices.Count); Missing=$($missing.Count)"
        exit 0
    }

    if($Mode -in @('Display','Network','Audio','USB','Bluetooth')){
        $class= switch($Mode){'Display'{'Display'}'Network'{'Net'}'Audio'{'MEDIA'}'USB'{'USB'}'Bluetooth'{'Bluetooth'}}
        $devices=@(Get-PnpDevice -Class $class -ErrorAction SilentlyContinue|Select-Object Status,Class,FriendlyName,InstanceId)
        $rows=foreach($device in $devices){
            $driver=$allDrivers|Where-Object DeviceID -eq $device.InstanceId|Select-Object -First 1
            [pscustomobject]@{Status=$device.Status;Device=$device.FriendlyName;Provider=$driver.DriverProviderName;Version=$driver.DriverVersion;Date=$driver.DriverDate;InstanceId=$device.InstanceId}
        }
        if(-not @($rows).Count){"No $Mode devices were returned by Windows PnP."}else{$rows|Format-Table -Wrap -AutoSize|Out-String|Write-Output}
        Write-DriverLog "$Mode Driver Diagnostics" "Devices=$(@($rows).Count)"
        exit 0
    }

    if($Mode -eq 'SearchUpdates'){
        $session=New-Object -ComObject Microsoft.Update.Session
        $searcher=$session.CreateUpdateSearcher()
        $search=$searcher.Search("IsInstalled=0 and Type='Driver'")
        if($search.Updates.Count -eq 0){'Windows Update returned no applicable driver updates.'}
        else{for($index=0;$index -lt $search.Updates.Count;$index++){[pscustomobject]@{Title=$search.Updates.Item($index).Title;IsDownloaded=$search.Updates.Item($index).IsDownloaded;RebootRequired=$search.Updates.Item($index).RebootRequired}|Format-List|Out-String|Write-Output}}
        Write-DriverLog 'Windows Update Driver Search' "Available=$($search.Updates.Count); installed=0"
        exit 0
    }

    $allDrivers|Select-Object DeviceName,DriverProviderName,DriverVersion,DriverDate,IsSigned,InfName|Sort-Object DeviceName|Format-Table -Wrap -AutoSize|Out-String|Write-Output
    Write-DriverLog 'Driver Inventory' "Installed signed-driver entries=$($allDrivers.Count)"
} catch {
    $log=Write-ApexLog -Action 'Driver Center' -Result 'Failed' -Message $_.Exception.Message
    [Console]::Error.WriteLine("$($_.Exception.Message) Log: $log")
    exit 1
}