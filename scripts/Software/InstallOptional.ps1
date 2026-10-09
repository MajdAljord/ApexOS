param(
    [ValidateSet('Status','Install')][string]$Mode='Status',
    [ValidateSet('Chrome','Firefox','Brave','Steam','Epic','OBS','NanaZip','SevenZip','Minecraft')][string]$Name='Chrome'
)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\Modules\Apex.Common.psm1') -Force

$packages=@{
    Chrome=[pscustomobject]@{Id='Google.Chrome';Label='Google Chrome'}
    Firefox=[pscustomobject]@{Id='Mozilla.Firefox';Label='Mozilla Firefox'}
    Brave=[pscustomobject]@{Id='Brave.Brave';Label='Brave'}
    Steam=[pscustomobject]@{Id='Valve.Steam';Label='Steam'}
    Epic=[pscustomobject]@{Id='EpicGames.EpicGamesLauncher';Label='Epic Games Launcher'}
    OBS=[pscustomobject]@{Id='OBSProject.OBSStudio';Label='OBS Studio'}
    NanaZip=[pscustomobject]@{Id='MouriNaruto.NanaZip';Label='NanaZip'}
    SevenZip=[pscustomobject]@{Id='7zip.7zip';Label='7-Zip'}
    Minecraft=[pscustomobject]@{Id='Mojang.MinecraftLauncher';Label='Minecraft Launcher'}
}

function Test-OptionalSoftwareInstalled {
    param([Parameter(Mandatory)][string]$Software)
    $programFiles=${env:ProgramFiles}
    $programFilesX86=${env:ProgramFiles(x86)}
    $paths=switch($Software){
        'Chrome' { @((Join-Path $programFiles 'Google\Chrome\Application\chrome.exe'),(Join-Path $programFilesX86 'Google\Chrome\Application\chrome.exe')) }
        'Firefox' { @((Join-Path $programFiles 'Mozilla Firefox\firefox.exe'),(Join-Path $programFilesX86 'Mozilla Firefox\firefox.exe')) }
        'Brave' { @((Join-Path $programFiles 'BraveSoftware\Brave-Browser\Application\brave.exe'),(Join-Path $programFilesX86 'BraveSoftware\Brave-Browser\Application\brave.exe')) }
        'Steam' { @((Join-Path $programFiles 'Steam\Steam.exe'),(Join-Path $programFilesX86 'Steam\Steam.exe')) }
        'Epic' { @((Join-Path $programFiles 'Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe'),(Join-Path $programFilesX86 'Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe')) }
        'OBS' { @((Join-Path $programFiles 'obs-studio\bin\64bit\obs64.exe'),(Join-Path $programFilesX86 'obs-studio\bin\64bit\obs64.exe')) }
        'SevenZip' { @((Join-Path $programFiles '7-Zip\7z.exe'),(Join-Path $programFilesX86 '7-Zip\7z.exe')) }
        default { @() }
    }
    if($paths|Where-Object {Test-Path -LiteralPath $_ -PathType Leaf}){return $true}
    if($Software -eq 'NanaZip'){
        return [bool](Get-AppxPackage -Name 'MouriNaruto.NanaZip' -ErrorAction SilentlyContinue|Select-Object -First 1)
    }
    if($Software -eq 'Minecraft'){
        return [bool](Get-AppxPackage -Name 'Microsoft.4297127D64EC6' -ErrorAction SilentlyContinue|Select-Object -First 1)
    }
    return $false
}

try {
    $package=$packages[$Name]
    if($Mode -eq 'Status'){
        if(Test-OptionalSoftwareInstalled -Software $Name){"$($package.Label): installed"}else{"$($package.Label): not installed"}
        exit 0
    }

    $winget=Get-Command winget.exe -ErrorAction SilentlyContinue
    if(-not $winget){$winget=Get-Command winget -ErrorAction SilentlyContinue}
    if(-not $winget){throw 'WinGet is unavailable. Install or update Microsoft App Installer before using optional software installation.'}

    if(Test-OptionalSoftwareInstalled -Software $Name){
        "Information: $($package.Label) is already installed; no installer was run."
        exit 0
    }
    $output=& $winget.Source install --id $package.Id --exact --source winget --silent --accept-source-agreements --accept-package-agreements --disable-interactivity 2>&1
    $code=$LASTEXITCODE
    if($code -ne 0){throw "WinGet install failed for '$($package.Label)' (exit $code): $($output -join ' ')"}
    if(-not(Test-OptionalSoftwareInstalled -Software $Name)){
        throw "WinGet returned success but '$($package.Label)' was not found during post-install verification."
    }
    $log=Write-ApexLog -Action 'Optional Software Install' -Result 'Success' -Message "Name=$($package.Label); PackageId=$($package.Id); Source=winget; Verified=installed"
    "$($package.Label) installed and verified. Log: $log"
}catch{
    $log=Write-ApexLog -Action 'Optional Software Install' -Result 'Failed' -Message $_.Exception.Message
    [Console]::Error.WriteLine("$($_.Exception.Message) Log: $log")
    exit 1
}