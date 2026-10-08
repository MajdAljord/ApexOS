param([ValidateSet('Status','Snapshot')][string]$Mode='Status')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\Modules\Apex.Common.psm1') -Force

try {
    if($Mode -eq 'Status'){'Ready';exit 0}
    $os=Get-CimInstance Win32_OperatingSystem
    $computer=Get-CimInstance Win32_ComputerSystem
    $processors=Get-CimInstance Win32_Processor
    $video=Get-CimInstance Win32_VideoController|Select-Object -First 1
    $cpuCounter=Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction SilentlyContinue
    $cpuLoad=if($cpuCounter){[int]$cpuCounter.PercentProcessorTime}else{$null}
    $memoryTotal=[int64]$computer.TotalPhysicalMemory
    $memoryAvailable=[int64]$os.FreePhysicalMemory*1KB
    $memoryUsed=[Math]::Max(0,$memoryTotal-$memoryAvailable)
    $drive=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'" -ErrorAction Stop
    $cpuName=($processors|Select-Object -First 1 -ExpandProperty Name)
    $gpuName=if($video){$video.Name}else{'Not detected'}
    $activeLine=powercfg.exe /getactivescheme 2>&1|Select-Object -First 1
    $activeGuid=$null;$activeName='Unknown'
    if($activeLine -match '(?<guid>[0-9a-fA-F-]{36})\s*\((?<name>.*?)\)'){$activeGuid=$matches.guid;$activeName=$matches.name}
    $planList=powercfg.exe /list 2>&1
    $planGuids=@(foreach($line in $planList){if($line -match '(?<guid>[0-9a-fA-F-]{36})\s*\((?<name>.*?)\)'){[pscustomobject]@{Guid=$matches.guid;Name=$matches.name;Active=($line -match '\*\s*$')}}})
    $gameBar=Get-ItemProperty 'HKCU:\Software\Microsoft\GameBar' -ErrorAction SilentlyContinue
    $gameDvr=Get-ItemProperty 'HKCU:\System\GameConfigStore' -ErrorAction SilentlyContinue
    $ramPolicy=Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' -Name GlobalUserDisabled -ErrorAction SilentlyContinue
    $deviceErrors=@(Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue|Where-Object ConfigManagerErrorCode -ne 0)
    $network=Get-NetAdapter -ErrorAction SilentlyContinue|Where-Object Status -eq 'Up'|Select-Object -First 1
    $update=Get-Service wuauserv -ErrorAction SilentlyContinue
    $defender=Get-Service WinDefend -ErrorAction SilentlyContinue
    $defenderStatus=$null
    try{$defenderStatus=Get-MpComputerStatus -ErrorAction Stop|Select-Object -ExpandProperty RealTimeProtectionEnabled}catch{}
    $startupCount=@(Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue).Count
    $rebootPaths=@(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )
    $restartRequired=($rebootPaths|Where-Object {Test-Path -LiteralPath $_}).Count -gt 0
    $snapshot=[pscustomobject]@{
        CapturedAt=(Get-Date -Format o)
        Windows=[pscustomobject]@{Product=$os.Caption;Version=$os.Version;Build=[int]$os.BuildNumber;DisplayVersion=(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion;Architecture=$env:PROCESSOR_ARCHITECTURE}
        DeviceType=(Get-ApexDeviceType)
        Cpu=[pscustomobject]@{Name=$cpuName;UsagePercent=$cpuLoad}
        Gpu=[pscustomobject]@{Name=$gpuName;UsagePercent=$null}
        Memory=[pscustomobject]@{TotalBytes=$memoryTotal;UsedBytes=$memoryUsed;AvailableBytes=$memoryAvailable;CachedBytes=$null;UsagePercent=if($memoryTotal){[Math]::Round($memoryUsed/$memoryTotal*100,1)}else{$null};Pressure=if($memoryTotal -and $memoryAvailable/$memoryTotal -lt .1){'High'}elseif($memoryTotal -and $memoryAvailable/$memoryTotal -lt .2){'Moderate'}else{'Normal'}}
        Storage=[pscustomobject]@{Drive=$drive.DeviceID;TotalBytes=[int64]$drive.Size;FreeBytes=[int64]$drive.FreeSpace;UsedBytes=([int64]$drive.Size-[int64]$drive.FreeSpace)}
        Power=[pscustomobject]@{ActivePlan=$activeName;ActiveGuid=$activeGuid;AvailablePlans=$planGuids}
        StartupCount=$startupCount
        Status=[pscustomobject]@{
            GameMode=($gameBar.AutoGameModeEnabled -eq 1 -and $gameBar.AllowAutoGameMode -eq 1)
            GameDvr=($gameDvr.GameDVR_Enabled -ne 0)
            RamSaver=if($ramPolicy.GlobalUserDisabled -eq 1){'AGGRESSIVE'}elseif($ramPolicy.GlobalUserDisabled -eq 0){'BALANCED'}else{'OFF'}
            WindowsUpdate=if($update){[string]$update.Status}else{'Not detected'}
            WindowsSecurity=if($null -ne $defenderStatus){if($defenderStatus){'Real-time protection on'}else{'Real-time protection off'}}elseif($defender){[string]$defender.Status}else{'Not detected'}
            Network=if($network){"Connected: $($network.Name)"}else{'Disconnected'}
            DeviceErrors=$deviceErrors.Count
            RestartRequired=$restartRequired
        }
    }
    $snapshot|ConvertTo-Json -Depth 8
}catch{
    $log=Write-ApexLog -Action 'Home Snapshot' -Result 'Failed' -Message $_.Exception.Message
    [Console]::Error.WriteLine("Could not read Apex system snapshot. $($_.Exception.Message) Log: $log")
    exit 1
}