param([ValidateSet('Status','Classic','Windows11','Restore')][string]$Mode='Status')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\Modules\Apex.Common.psm1') -Force
$key='HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'
$registryPath='Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'
$statePath=Get-ApexSnapshotPath 'explorer-context'
$exportPath="$statePath.reg"
try {
    if($Mode -eq 'Status'){if(Test-Path (Join-Path $key 'InprocServer32')){'Classic'}else{'Windows 11'};exit 0}
    if($Mode -ne 'Restore' -and -not(Test-Path $statePath)){
        $existing=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($registryPath)
        $hadKey=$null -ne $existing
        if($existing){$existing.Close()}
        if($hadKey){$export=& reg.exe export "HKCU\$registryPath" $exportPath /y 2>&1;if($LASTEXITCODE -ne 0){throw "Could not back up Explorer registry settings: $export"}}
        [pscustomobject]@{HadKey=$hadKey}|ConvertTo-Json|Set-Content -LiteralPath $statePath -Encoding UTF8
    }
    if($Mode -eq 'Classic'){
        $inproc=Join-Path $key 'InprocServer32';New-Item -Path $inproc -Force|Out-Null;Set-Item -LiteralPath $inproc -Value ''
    }elseif($Mode -eq 'Windows11'){
        Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction SilentlyContinue
    }else{
        if(-not(Test-Path $statePath)){throw 'No Apex Explorer settings snapshot exists.'}
        $state=Get-Content -LiteralPath $statePath -Raw|ConvertFrom-Json
        if($state.HadKey){if(-not(Test-Path $exportPath)){throw 'The Explorer registry backup is missing.'};Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction SilentlyContinue;$restore=& reg.exe import $exportPath 2>&1;if($LASTEXITCODE -ne 0){throw "Could not restore Explorer registry settings: $restore"}}
        else{Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction SilentlyContinue}
        Remove-Item -LiteralPath $statePath,$exportPath -Force -ErrorAction SilentlyContinue
    }
    Get-Process explorer -ErrorAction SilentlyContinue|Stop-Process -Force;Start-Sleep -Milliseconds 700;Start-Process explorer.exe
    $log=Write-ApexLog 'Explorer Context Menu' 'Success' $Mode;"Explorer restarted. Log: $log"
}catch{$log=Write-ApexLog 'Explorer Context Menu' 'Failed' $_.Exception.Message;[Console]::Error.WriteLine("$($_.Exception.Message) Log: $log");exit 1}