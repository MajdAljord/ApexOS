param([ValidateSet('Status','Apply','Restore')][string]$Mode='Status')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\Modules\Apex.Common.psm1') -Force
$key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'; $name='VisualFXSetting'
try {
 if($Mode -eq 'Status') { $v=(Get-ItemProperty -LiteralPath $key -Name $name -ErrorAction SilentlyContinue).$name; if($v -eq 2){'Performance'}elseif($null -eq $v -or $v -eq 0){'Windows managed'}else{'Custom'}; exit 0 }
 if($Mode -eq 'Apply'){Save-ApexRegistrySnapshot -Name 'visual-effects' -Values @(@{Path=$key;Name=$name}); New-Item -Path $key -Force|Out-Null; Set-ItemProperty -LiteralPath $key -Name $name -Value 2 -Type DWord;if((Get-ItemProperty -LiteralPath $key -Name $name).$name -ne 2){throw 'Windows did not retain the visual-effects setting.'}}
 elseif(-not (Restore-ApexRegistrySnapshot -Name 'visual-effects')){throw 'No Apex visual-effects snapshot exists.'}
 $log=Write-ApexLog 'Visual Effects' 'Success' $Mode; "Completed. Log: $log"
} catch { $log=Write-ApexLog 'Visual Effects' 'Failed' $_.Exception.Message; [Console]::Error.WriteLine("$($_.Exception.Message) Log: $log"); exit 1 }