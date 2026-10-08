param([ValidateSet('Status','StartupList','OpenStartup','OpenSearchIndex','OpenIndexOptions','OpenBackgroundApps','OpenGraphics','OpenStorage','OpenWindowsUpdate')][string]$Mode='Status')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\Modules\Apex.Common.psm1') -Force
try {
    if($Mode -eq 'Status'){'Ready';exit 0}
    switch($Mode){
        'StartupList' {
            $entries=@(Get-CimInstance Win32_StartupCommand|Select-Object Name,Location,User,Command)
            if(-not $entries.Count){'No startup commands were reported by Windows.'}else{$entries|Format-Table -Wrap -AutoSize|Out-String|Write-Output}
            $log=Write-ApexLog -Action 'Startup Inventory' -Result 'Complete' -Message "Entries=$($entries.Count)"
            "Startup entries: $($entries.Count)`nLog: $log"
        }
        'OpenStartup' {$uri='ms-settings:startupapps';$message='Opened Windows Startup Apps settings. Use Windows controls to review and change individual entries.'}
        'OpenSearchIndex' {$uri='ms-settings:search';$message='Opened Windows Search settings. Indexing options remain under user control.'}
        'OpenIndexOptions' {Start-Process -FilePath 'control.exe' -ArgumentList @('/name','Microsoft.IndexingOptions');$log=Write-ApexLog -Action 'Open Indexing Options' -Result 'Success';'Opened Windows Indexing Options. No service settings were changed.';exit 0}
        'OpenBackgroundApps' {$uri='ms-settings:appsfeatures';$message='Opened Windows Installed apps settings. Review app-specific background permissions there.'}
        'OpenGraphics' {$uri='ms-settings:display-advancedgraphics';$message='Opened Windows Graphics settings. Choose a per-app GPU preference in Windows.'}
        'OpenStorage' {$uri='ms-settings:storagesense';$message='Opened Windows Storage settings. Review proposed cleanup categories before deleting anything.'}
        'OpenWindowsUpdate' {$uri='ms-settings:windowsupdate';$message='Opened Windows Update settings. Apex did not change update policy.'}
    }
    if($uri){Start-Process $uri;$log=Write-ApexLog -Action "Open $Mode" -Result 'Success' -Message $uri;"$message`nLog: $log"}
}catch{$log=Write-ApexLog -Action "Windows User Settings $Mode" -Result 'Failed' -Message $_.Exception.Message;[Console]::Error.WriteLine("$($_.Exception.Message) Log: $log");exit 1}