param([ValidateSet('Status','Set','Restore','OpenLockScreen')][string]$Mode='Status',[ValidateSet('Apex-Dark.png','Apex-Light.png','Apex-Gaming.png','Apex-Desktop.png','Apex-LockScreen.png')][string]$Name='Apex-Dark.png')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\Modules\Apex.Common.psm1') -Force
$wallpaperDirectory=Join-Path (Get-ApexRoot) 'Wallpapers'
$wallpaper=Join-Path $wallpaperDirectory $Name
$wallpaperKey='HKCU:\Control Panel\Desktop'

function Set-DesktopWallpaper {
    param([string]$Path)
    if(-not ('ApexDesktopWallpaper' -as [type])){
        Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public static class ApexDesktopWallpaper {
    [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    public static extern bool SystemParametersInfo(uint action, uint param, string path, uint flags);
}
'@
    }
    if(-not [ApexDesktopWallpaper]::SystemParametersInfo(0x0014,0,$Path,0x0001 -bor 0x0002)){
        $code=[Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw "Windows rejected the wallpaper update (Win32 error $code)."
    }
}

try {
    if($Mode -eq 'Status'){
        if(-not(Test-Path -LiteralPath $wallpaper)){"Missing: $wallpaper";exit 0}
        $current=(Get-ItemProperty -LiteralPath $wallpaperKey -Name WallPaper -ErrorAction SilentlyContinue).WallPaper
        if($current -and [IO.Path]::GetFullPath($current) -eq [IO.Path]::GetFullPath($wallpaper)){"Applied: $Name"}else{"Available: $Name"}
        exit 0
    }
    if($Mode -eq 'Restore'){
        $snapshotPath=Get-ApexSnapshotPath 'wallpaper'
        if(-not(Test-Path -LiteralPath $snapshotPath)){throw 'No Apex desktop wallpaper snapshot exists.'}
        $snapshot=Get-Content -LiteralPath $snapshotPath -Raw|ConvertFrom-Json|Select-Object -First 1
        if(-not $snapshot.Exists -or -not $snapshot.Value){throw 'The original wallpaper was not a file path Apex can reliably re-apply. The snapshot was retained.'}
        Set-DesktopWallpaper -Path ([string]$snapshot.Value)
        if(-not(Restore-ApexRegistrySnapshot -Name 'wallpaper')){throw 'Could not restore the saved wallpaper registry state.'}
        $log=Write-ApexLog -Action 'Desktop Wallpaper Restore' -Result 'Success' -Message ([string]$snapshot.Value)
        "Previous desktop wallpaper restored. Log: $log"
        exit 0
    }
    if(-not(Test-Path -LiteralPath $wallpaper)){throw "Wallpaper file is missing: $wallpaper"}
    if($Name -eq 'Apex-LockScreen.png'){
        if($Mode -ne 'OpenLockScreen'){throw 'The lock-screen image must be selected through Windows Personalization settings.'}
        Start-Process 'ms-settings:lockscreen'
        $log=Write-ApexLog -Action 'Lock Screen Wallpaper' -Result 'Success' -Message "Opened settings for $wallpaper"
        "Opened Windows Lock screen settings. Select $wallpaper manually; Apex does not claim it was applied.`nLog: $log"
        exit 0
    }
    Save-ApexRegistrySnapshot -Name 'wallpaper' -Values @(@{Path=$wallpaperKey;Name='WallPaper'})
    Set-DesktopWallpaper -Path $wallpaper
    $actual=(Get-ItemProperty -LiteralPath $wallpaperKey -Name WallPaper).WallPaper
    if([IO.Path]::GetFullPath($actual) -ne [IO.Path]::GetFullPath($wallpaper)){throw 'Windows did not retain the requested desktop wallpaper path.'}
    $log=Write-ApexLog -Action 'Desktop Wallpaper' -Result 'Success' -Message $wallpaper
    "Desktop wallpaper set to $Name. Log: $log"
}catch{$log=Write-ApexLog -Action 'Wallpaper' -Result 'Failed' -Message $_.Exception.Message;[Console]::Error.WriteLine("$($_.Exception.Message) Log: $log");exit 1}