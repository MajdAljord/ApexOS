param([ValidateSet('Status','Restart')][string]$Mode='Status')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\Modules\Apex.Common.psm1') -Force
try {if($Mode -eq 'Status'){'Available';exit 0};Get-Process explorer -ErrorAction SilentlyContinue|Stop-Process -Force;Start-Sleep -Milliseconds 700;Start-Process explorer.exe;$log=Write-ApexLog 'Restart Explorer' 'Success';"Explorer restarted. Log: $log"}catch{$log=Write-ApexLog 'Restart Explorer' 'Failed' $_.Exception.Message;[Console]::Error.WriteLine("$($_.Exception.Message) Log: $log");exit 1}