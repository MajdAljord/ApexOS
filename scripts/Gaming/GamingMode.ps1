param([ValidateSet('Status','Enable','Restore')][string]$Mode='Status')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\Modules\Apex.Common.psm1') -Force
$values=@(@{Path='HKCU:\Software\Microsoft\GameBar';Name='AutoGameModeEnabled';Target=1},@{Path='HKCU:\Software\Microsoft\GameBar';Name='AllowAutoGameMode';Target=1},@{Path='HKCU:\System\GameConfigStore';Name='GameDVR_Enabled';Target=0})
try {
 if($Mode -eq 'Status'){$g=(Get-ItemProperty -LiteralPath $values[0].Path -Name $values[0].Name -ErrorAction SilentlyContinue).AutoGameModeEnabled;$allow=(Get-ItemProperty -LiteralPath $values[1].Path -Name $values[1].Name -ErrorAction SilentlyContinue).AllowAutoGameMode;$d=(Get-ItemProperty -LiteralPath $values[2].Path -Name $values[2].Name -ErrorAction SilentlyContinue).GameDVR_Enabled;if($g -eq 1 -and $allow -eq 1 -and $d -eq 0){'ON'}else{'OFF'};exit 0}
 if($Mode -eq 'Enable'){Save-ApexRegistrySnapshot 'gaming-mode' $values;foreach($item in $values){New-Item -Path $item.Path -Force|Out-Null;Set-ItemProperty -LiteralPath $item.Path -Name $item.Name -Value $item.Target -Type DWord;if((Get-ItemProperty -LiteralPath $item.Path -Name $item.Name).$($item.Name) -ne $item.Target){throw "Windows did not retain $($item.Name)."}}}else{if(-not(Restore-ApexRegistrySnapshot 'gaming-mode')){throw 'No Apex Gaming Mode snapshot exists.'}}
 $log=Write-ApexLog 'Gaming Mode' 'Success' $Mode; "Completed. Log: $log"
} catch {$log=Write-ApexLog 'Gaming Mode' 'Failed' $_.Exception.Message;[Console]::Error.WriteLine("$($_.Exception.Message) Log: $log");exit 1}