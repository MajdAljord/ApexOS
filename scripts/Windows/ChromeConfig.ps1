param([ValidateSet('Status','OpenDefaultApps','OpenBackgroundSettings')][string]$Mode='Status')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\Modules\Apex.Common.psm1') -Force

function Get-ChromePath {
    $paths=@("$env:ProgramFiles\Google\Chrome\Application\chrome.exe","${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe","$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe")
    foreach($hive in @('HKCU:','HKLM:')){
        foreach($view in @('SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe','SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe')){
            $registered=(Get-ItemProperty -LiteralPath (Join-Path $hive $view) -Name '(default)' -ErrorAction SilentlyContinue).'(default)'
            if($registered){$paths+=([string]$registered)}
        }
    }
    $paths|Where-Object { Test-Path -LiteralPath $_ }|Select-Object -First 1
}

try {
    $chrome=Get-ChromePath
    $http=(Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice' -Name ProgId -ErrorAction SilentlyContinue).ProgId
    $https=(Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice' -Name ProgId -ErrorAction SilentlyContinue).ProgId
    if($Mode -eq 'Status'){
        if(-not $chrome){'Chrome: not installed'}
        elseif($http -match 'Chrome' -and $https -match 'Chrome'){"Chrome: installed; default for HTTP/HTTPS ($chrome)"}
        else{"Chrome: installed; not default for both HTTP/HTTPS ($chrome)"}
        exit 0
    }
    if(-not $chrome){throw 'Google Chrome is not installed. Install Chrome from Google before configuring it.'}
    if($Mode -eq 'OpenDefaultApps'){
        Start-Process 'ms-settings:defaultapps?registeredAppUser=Google.Chrome'
        $message='Opened Windows Default apps. Select Google Chrome and approve each association in Windows; Apex does not bypass the Windows default-app protection.'
    }else{
        Start-Process -FilePath $chrome -ArgumentList 'chrome://settings/system'
        $message='Opened Chrome system settings. The user can turn off background apps there; Apex did not change Chrome policy.'
    }
    $log=Write-ApexLog -Action 'Chrome Configuration' -Result 'Success' -Message $Mode
    "$message`nLog: $log"
}catch{
    $log=Write-ApexLog -Action 'Chrome Configuration' -Result 'Failed' -Message $_.Exception.Message
    [Console]::Error.WriteLine("$($_.Exception.Message) Log: $log")
    exit 1
}