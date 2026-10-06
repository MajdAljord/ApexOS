param(
    [ValidateSet('Status','Report','PackageStatus','ListOptional','RemoveOptional','RestoreOptional','StoreStatus','StoreRemove','StoreRestore','EdgeStatus','WebView2Status','OpenStoreSettings')]
    [string]$Mode='Status',
    [string]$Name=''
)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\Modules\Apex.Common.psm1') -Force
$optionalApps=@(
    'Clipchamp.Clipchamp','Microsoft.BingNews','Microsoft.GetHelp','Microsoft.Getstarted',
    'Microsoft.MicrosoftSolitaireCollection','Microsoft.WindowsFeedbackHub','Microsoft.WindowsMaps',
    'Microsoft.ZuneVideo','Microsoft.People','Microsoft.Copilot','Microsoft.549981C3F5F10',
    'Microsoft.WindowsCommunicationsApps','MSTeams'
)

function Get-ComponentSnapshotPath {
    param([string]$PackageName)
    $safeName=$PackageName -replace '[^A-Za-z0-9.-]','-'
    Get-ApexSnapshotPath "package-$safeName"
}

function Get-AppPackage {
    param([string]$PackageName)
    Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue|Select-Object -First 1
}

function Save-PackageSnapshot {
    param($Package)
    $path=Get-ComponentSnapshotPath $Package.Name
    if(-not(Test-Path -LiteralPath $path)){
        [pscustomobject]@{Name=$Package.Name;PackageFullName=$Package.PackageFullName;InstallLocation=$Package.InstallLocation;Version=[string]$Package.Version}|ConvertTo-Json|Set-Content -LiteralPath $path -Encoding UTF8
    }
    $path
}

function Remove-CurrentUserPackage {
    param([string]$PackageName)
    $package=Get-AppPackage $PackageName
    if(-not $package){throw "$PackageName is not installed for the current user; no change was made."}
    $snapshot=Save-PackageSnapshot $package
    Remove-AppxPackage -Package $package.PackageFullName
    if(Get-AppPackage $PackageName){throw "Windows still reports $PackageName installed. Check the Apex log before retrying."}
    $log=Write-ApexLog -Action 'Optional App Removal' -Result 'Success' -Message "Name=$PackageName; Snapshot=$snapshot; scope=current user"
    "Removed $PackageName for the current user. Restore may require the original manifest to remain staged. Log: $log"
}

function Restore-CurrentUserPackage {
    param([string]$PackageName)
    $snapshotPath=Get-ComponentSnapshotPath $PackageName
    if(-not(Test-Path -LiteralPath $snapshotPath)){throw "No Apex package snapshot exists for $PackageName."}
    $snapshot=Get-Content -LiteralPath $snapshotPath -Raw|ConvertFrom-Json
    if(Get-AppPackage $PackageName){'Package is already installed for the current user.';return}
    $manifest=Join-Path $snapshot.InstallLocation 'AppxManifest.xml'
    if(-not(Test-Path -LiteralPath $manifest)){throw "Original package manifest is unavailable at $manifest. Reinstall through a trusted Microsoft source instead."}
    Add-AppxPackage -DisableDevelopmentMode -Register $manifest
    if(-not(Get-AppPackage $PackageName)){throw "Windows did not restore $PackageName."}
    $log=Write-ApexLog -Action 'Optional App Restore' -Result 'Success' -Message "Name=$PackageName; Package=$($snapshot.PackageFullName)"
    "Restored $PackageName for the current user. Log: $log"
}

function Get-WebViewRuntime {
    $roots=@($env:ProgramFiles,${env:ProgramFiles(x86)},$env:LOCALAPPDATA)|Where-Object { $_ }
    foreach($root in $roots){
        $application=Join-Path $root 'Microsoft\EdgeWebView\Application'
        if(Test-Path -LiteralPath $application){
            $binary=Get-ChildItem -LiteralPath $application -Filter msedgewebview2.exe -Recurse -File -ErrorAction SilentlyContinue|Select-Object -First 1
            if($binary){return [pscustomobject]@{Path=$binary.FullName;Version=$binary.Directory.Name}}
        }
    }
    return $null
}

try {
    switch($Mode){
        'Status' {'Ready';exit 0}
        'PackageStatus' {
            if($Name -notin $optionalApps -and $Name -ne 'Microsoft.WindowsStore'){throw 'Package name is not on Apex optional-package allowlist.'}
            $package=Get-AppPackage $Name
            if($package){"Installed: $($package.Name) $($package.Version)"}else{"Not installed for current user: $Name"}
            exit 0
        }
        'ListOptional' {
            $packages=foreach($app in $optionalApps){Get-AppPackage $app|Select-Object Name,Version,PackageFullName,InstallLocation}
            if(-not @($packages).Count){'No allowlisted optional consumer packages were found.'}else{$packages|Format-Table -Wrap -AutoSize|Out-String|Write-Output}
            $log=Write-ApexLog -Action 'Optional App Inventory' -Result 'Complete' -Message "Installed=$(@($packages).Count)"
            "Only current-user package identities are listed; protected runtime components are not on the removal allowlist.`nLog: $log"
            exit 0
        }
        'RemoveOptional' {
            if($Name -notin $optionalApps){throw 'Package name is not on Apex optional-package allowlist.'}
            Remove-CurrentUserPackage $Name
            exit 0
        }
        'RestoreOptional' {
            if($Name -notin $optionalApps){throw 'Package name is not on Apex optional-package allowlist.'}
            Restore-CurrentUserPackage $Name
            exit 0
        }
        'StoreStatus' {
            $store=Get-AppPackage 'Microsoft.WindowsStore'
            if($store){"Microsoft Store: Installed for current user ($($store.Version))"}else{'Microsoft Store: Not installed for current user'}
            exit 0
        }
        'StoreRemove' { Remove-CurrentUserPackage 'Microsoft.WindowsStore';exit 0 }
        'StoreRestore' { Restore-CurrentUserPackage 'Microsoft.WindowsStore';exit 0 }
        'EdgeStatus' {
            $paths=@("$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe", "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe")
            $edge=$paths|Where-Object { Test-Path -LiteralPath $_ }|Select-Object -First 1
            if($edge){"Edge Browser: installed at $edge"}else{'Edge Browser: not found'}
            exit 0
        }
        'WebView2Status' {
            $runtime=Get-WebViewRuntime
            if($runtime){"WebView2 Runtime: installed ($($runtime.Version)) at $($runtime.Path)"}else{'WebView2 Runtime: not detected; Edge Browser status is separate.'}
            exit 0
        }
        'OpenStoreSettings' {
            Start-Process 'ms-settings:appsfeatures'
            $log=Write-ApexLog -Action 'Microsoft Store Settings' -Result 'Success' -Message 'Opened Windows Installed apps settings; no package was removed.'
            "Opened Windows Installed apps. Apex did not remove Store or shared components. Log: $log"
            exit 0
        }
        'Report' {
            $store=Get-AppPackage 'Microsoft.WindowsStore'
            $edge=(Test-Path "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") -or (Test-Path "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe")
            $webview=Get-WebViewRuntime
            $summary=[pscustomobject]@{MicrosoftStoreCurrentUser=[bool]$store;EdgeBrowser=[bool]$edge;EdgeBrowserPath=if($edge){'Installed'}else{'Not detected'};WebView2Runtime=[bool]$webview;WebView2Version=if($webview){$webview.Version}else{$null};ProtectedComponentsManifest=Join-Path (Get-ApexRoot) 'Toolbox\config\protected-components.json'}
            $log=Write-ApexLog -Action 'Windows Component Inventory' -Result 'Complete' -Message "Store=$([bool]$store); Edge=$edge; WebView2=$([bool]$webview)"
            "$($summary|ConvertTo-Json -Depth 4)`nLog: $log"
        }
    }
}catch{
    $log=Write-ApexLog -Action "Windows Components $Mode" -Result 'Failed' -Message $_.Exception.Message
    [Console]::Error.WriteLine("$($_.Exception.Message) Log: $log")
    exit 1
}