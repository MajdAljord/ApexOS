param([ValidateSet('Status','Generate')][string]$Mode='Status')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\Modules\Apex.Common.psm1') -Force

try {
    if($Mode -eq 'Status'){'Ready';exit 0}
    $computer=Get-CimInstance Win32_ComputerSystem
    $os=Get-CimInstance Win32_OperatingSystem
    $build=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $type=if($computer.PCSystemType -eq 3){'Laptop'}else{'Desktop/Other'}
    $board=Get-CimInstance Win32_BaseBoard|Select-Object Manufacturer,Product,Version
    $cpu=Get-CimInstance Win32_Processor|Select-Object Name,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed
    $gpu=Get-CimInstance Win32_VideoController|Select-Object Name,DriverVersion,DriverDate,AdapterRAM
    $storage=Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3'|Select-Object DeviceID,VolumeName,Size,FreeSpace
    $drivers=Get-CimInstance Win32_PnPSignedDriver|Select-Object DeviceName,DriverProviderName,DriverVersion,DriverDate
    $problems=Get-CimInstance Win32_PnPEntity|Where-Object ConfigManagerErrorCode -ne 0|Select-Object Name,PNPDeviceID,ConfigManagerErrorCode
    $network=Get-NetAdapter -IncludeHidden -ErrorAction SilentlyContinue|Select-Object Name,InterfaceDescription,Status,LinkSpeed
    $audio=Get-CimInstance Win32_SoundDevice|Select-Object Name,Status,Manufacturer
    $usb=Get-CimInstance Win32_USBController|Select-Object Name,Status,Manufacturer
    $bluetooth=Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue|Select-Object Status,FriendlyName,InstanceId
    $startup=Get-CimInstance Win32_StartupCommand|Select-Object Name,Location,Command,User
    $serviceNames=@('wuauserv','bits','WinDefend','msiserver','BthServ','Audiosrv','PlugPlay','Winmgmt','WlanSvc','BFE','MpsSvc','XblAuthManager','GamingServices')
    $services=Get-Service -Name $serviceNames -ErrorAction SilentlyContinue|Select-Object Name,DisplayName,Status
    $recentErrors=@(Get-WinEvent -FilterHashtable @{LogName='System';Level=2;StartTime=(Get-Date).AddDays(-1)} -MaxEvents 20 -ErrorAction SilentlyContinue|Select-Object TimeCreated,Id,ProviderName,Message)
    $plan=powercfg.exe /getactivescheme 2>&1
    $reportPath=Join-Path (Get-ApexLogDirectory) 'Apex-System-Report.txt'
    @(
        'Apex System Report',
        "Generated: $(Get-Date -Format o)",
        "Device type: $type",
        "Model: $($computer.Manufacturer) $($computer.Model)",
        "Motherboard`n$($board|Format-Table -AutoSize|Out-String)",
        "RAM bytes: $($computer.TotalPhysicalMemory)",
        "Available RAM bytes: $([int64]$os.FreePhysicalMemory * 1KB)",
        "OS architecture: $env:PROCESSOR_ARCHITECTURE",
        "Windows: $($os.Caption) $($os.Version) $($build.DisplayVersion) build $($os.BuildNumber)",
        "System health summary: OS status=$($os.Status), last boot=$($os.LastBootUpTime); inventory only, no repair scan was run.",
        "Active power plan: $plan",
        "CPU`n$($cpu|Format-Table -AutoSize|Out-String)",
        "GPU`n$($gpu|Format-Table -AutoSize|Out-String)",
        "Storage`n$($storage|Format-Table -AutoSize|Out-String)",
        "Network adapters`n$($network|Format-Table -AutoSize|Out-String)",
        "Audio devices`n$($audio|Format-Table -AutoSize|Out-String)",
        "USB controllers`n$($usb|Format-Table -AutoSize|Out-String)",
        "Bluetooth devices`n$($bluetooth|Format-Table -AutoSize|Out-String)",
        "Devices with errors`n$($problems|Format-Table -AutoSize|Out-String)",
        "Startup applications`n$($startup|Format-Table -Wrap|Out-String)",
        "Running services`n$($services|Format-Table -AutoSize|Out-String)",
        "Recent System error events (last 24h)`n$($recentErrors|Format-Table -Wrap -AutoSize|Out-String)",
        "Signed drivers`n$($drivers|Format-Table -Wrap|Out-String)"
    )|Set-Content -LiteralPath $reportPath -Encoding UTF8
    $log=Write-ApexLog -Action 'System Report' -Result 'Success' -Message $reportPath
    "Report: $reportPath`nLog: $log"
}catch{
    $log=Write-ApexLog -Action 'System Report' -Result 'Failed' -Message $_.Exception.Message
    [Console]::Error.WriteLine("$($_.Exception.Message) Log: $log")
    exit 1
}