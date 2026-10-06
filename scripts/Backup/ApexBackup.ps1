param([ValidateSet('Status','Create','Restore')][string]$Mode='Status')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\Modules\Apex.Common.psm1') -Force
try {
    $root=Get-ApexRoot
    $directory=Get-ApexBackupDirectory
    if($Mode -eq 'Status'){'Ready';exit 0}
    if($Mode -eq 'Create'){
        $archive=Join-Path $directory ("Apex-Configuration-{0}.zip" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
        $staging=Join-Path $env:TEMP ("Apex-Backup-{0}" -f [guid]::NewGuid().ToString('N'))
        foreach($folder in @('config','scripts','Toolbox\config','Backups\Settings')){New-Item -Path (Join-Path $staging $folder) -ItemType Directory -Force|Out-Null}
        foreach($folder in @('config','scripts','Toolbox\config')){
            $source=Join-Path $root $folder
            if(Test-Path $source){Get-ChildItem -LiteralPath $source -Force|Copy-Item -Destination (Join-Path $staging $folder) -Recurse -Force}
        }
        $snapshotDirectory=Get-ApexSnapshotDirectory
        if(Test-Path $snapshotDirectory){Get-ChildItem -LiteralPath $snapshotDirectory -File|Copy-Item -Destination (Join-Path $staging 'Backups\Settings') -Force}
        Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $archive -CompressionLevel Optimal -Force
        Remove-Item -LiteralPath $staging -Recurse -Force
        $log=Write-ApexLog 'Apex Backup' 'Success' $archive
        "Backup created: $archive`nThis is not a Windows backup. Log: $log"
        exit 0
    }
    $archive=Get-ChildItem -LiteralPath $directory -Filter 'Apex-Configuration-*.zip' -File|Sort-Object LastWriteTime -Descending|Select-Object -First 1
    if(-not $archive){throw 'No Apex configuration archive found.'}
    $staging=Join-Path $env:TEMP ("Apex-Restore-{0}" -f [guid]::NewGuid().ToString('N'))
    Expand-Archive -LiteralPath $archive.FullName -DestinationPath $staging
    foreach($folder in @('config','Toolbox\config')){
        $source=Join-Path $staging $folder
        if(Test-Path $source){$destination=Join-Path $root $folder;New-Item -Path $destination -ItemType Directory -Force|Out-Null;Get-ChildItem -LiteralPath $source -Force|Copy-Item -Destination $destination -Recurse -Force}
    }
    $snapshotSource=Join-Path $staging 'Backups\Settings'
    if(Test-Path $snapshotSource){$snapshotDestination=Get-ApexSnapshotDirectory;Get-ChildItem -LiteralPath $snapshotSource -File|Copy-Item -Destination $snapshotDestination -Force}
    Remove-Item -LiteralPath $staging -Recurse -Force
    $log=Write-ApexLog 'Apex Restore' 'Success' $archive.Name
    "Apex configuration and setting snapshots restored. Windows settings themselves were not changed. Log: $log"
}catch{$log=Write-ApexLog 'Apex Backup' 'Failed' $_.Exception.Message;[Console]::Error.WriteLine("$($_.Exception.Message) Log: $log");exit 1}