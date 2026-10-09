param(
    [ValidateSet('List','Status','Set','Restore','OpenLockScreen','SetLockScreen')][string]$Mode='Status',
    [string]$Name='Apex-Default-Dark.jpg'
)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\Modules\Apex.Common.psm1') -Force
$wallpaperDirectory=Join-Path (Get-ApexRoot) 'Wallpapers'
$wallpaperKey='HKCU:\Control Panel\Desktop'
$supportedExtensions=@('.jpg','.jpeg','.png','.bmp','.webp')

function Get-WallpaperPath {
    param([string]$FileName)
    if([string]::IsNullOrWhiteSpace($FileName) -or [IO.Path]::GetFileName($FileName) -ne $FileName){
        throw 'Select a wallpaper file from the Apex Wallpapers folder.'
    }
    if([IO.Path]::GetExtension($FileName).ToLowerInvariant() -notin $supportedExtensions){
        throw "Unsupported wallpaper format: $FileName"
    }
    return Join-Path $wallpaperDirectory $FileName
}

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

function Set-ApexLockScreenWallpaper {
    param([Parameter(Mandatory)][string]$Path)
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    [Windows.System.UserProfile.LockScreen, Windows.System.UserProfile, ContentType = WindowsRuntime] | Out-Null
    [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null

    if(-not [Windows.System.UserProfile.LockScreen]::IsSupported()){
        throw 'Windows reports that programmatic lock-screen images are unsupported for this user or device.'
    }

    $asTaskGeneric=([System.WindowsRuntimeSystemExtensions].GetMethods()|Where-Object {
        $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
    }|Select-Object -First 1)
    $asTaskAction=([System.WindowsRuntimeSystemExtensions].GetMethods()|Where-Object {
        $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and -not $_.IsGenericMethod
    }|Select-Object -First 1)
    if(-not $asTaskGeneric -or -not $asTaskAction){throw 'Windows Runtime async bridges are unavailable in this PowerShell host.'}

    $storageFileTask=$asTaskGeneric.MakeGenericMethod([Windows.Storage.StorageFile]).Invoke($null,@([Windows.Storage.StorageFile]::GetFileFromPathAsync($Path)))
    $storageFileTask.Wait()
    $imageFile=$storageFileTask.Result
    $setTask=$asTaskAction.Invoke($null,@([Windows.System.UserProfile.LockScreen]::SetImageFileAsync($imageFile)))
    $setTask.Wait()

    $streamTask=$asTaskGeneric.MakeGenericMethod([Windows.Storage.Streams.IRandomAccessStream]).Invoke($null,@([Windows.System.UserProfile.LockScreen]::GetImageStream()))
    $streamTask.Wait()
    $stream=$streamTask.Result
    if(-not $stream -or $stream.Size -le 0){throw 'Windows accepted the lock-screen request but did not return an active lock-screen image stream.'}
}

try {
    if($Mode -eq 'List'){
        if(Test-Path -LiteralPath $wallpaperDirectory -PathType Container){
            Get-ChildItem -LiteralPath $wallpaperDirectory -File |
                Where-Object { $_.Extension.ToLowerInvariant() -in $supportedExtensions } |
                Sort-Object Name |
                ForEach-Object { $_.Name }
        }
        exit 0
    }
    if($Mode -eq 'Status'){
        $wallpaper=Get-WallpaperPath -FileName $Name
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
    $wallpaper=Get-WallpaperPath -FileName $Name
    if(-not(Test-Path -LiteralPath $wallpaper)){throw "Wallpaper file is missing: $wallpaper"}
    if($Mode -eq 'OpenLockScreen'){
        Start-Process 'ms-settings:lockscreen'
        $log=Write-ApexLog -Action 'Lock Screen Wallpaper' -Result 'Success' -Message "Opened settings for $wallpaper"
        "Opened Windows Lock screen settings. Select $wallpaper manually; Apex does not claim it was applied.`nLog: $log"
        exit 0
    }
    if($Mode -eq 'SetLockScreen'){
        Set-ApexLockScreenWallpaper -Path $wallpaper
        $log=Write-ApexLog -Action 'Lock Screen Wallpaper' -Result 'Windows accepted assignment; active stream available' -Message "Requested=$wallpaper; exact active source path is not exposed by the Windows API."
        "Windows accepted the lock-screen assignment and returned an active image stream. The exact active source path is not exposed for file-identity verification. Requested: $Name. Log: $log"
        exit 0
    }
    Save-ApexRegistrySnapshot -Name 'wallpaper' -Values @(@{Path=$wallpaperKey;Name='WallPaper'})
    Set-DesktopWallpaper -Path $wallpaper
    $actual=(Get-ItemProperty -LiteralPath $wallpaperKey -Name WallPaper).WallPaper
    if([IO.Path]::GetFullPath($actual) -ne [IO.Path]::GetFullPath($wallpaper)){throw 'Windows did not retain the requested desktop wallpaper path.'}
    $log=Write-ApexLog -Action 'Desktop Wallpaper' -Result 'Success' -Message $wallpaper
    "Desktop wallpaper set to $Name. Log: $log"
}catch{
    try { $log=Write-ApexLog -Action 'Wallpaper' -Result 'Failed' -Message $_.Exception.Message }
    catch { $log='Failure could not be written to the Apex log.' }
    [Console]::Error.WriteLine("$($_.Exception.Message) Log: $log")
    exit 1
}