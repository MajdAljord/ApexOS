param([ValidateSet('Status','Set','Restore')][string]$Mode='Status',[ValidateSet('On','Off')][string]$Setting='Off')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\Modules\Apex.Common.psm1') -Force
$key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize';$name='EnableTransparency'
try {
    if($Mode -eq 'Status'){$value=(Get-ItemProperty -LiteralPath $key -Name $name -ErrorAction SilentlyContinue).$name;if($value -eq 0){'OFF'}elseif($value -eq 1){'ON'}else{'WINDOWS DEFAULT'};exit 0}
    if($Mode -eq 'Set'){Save-ApexRegistrySnapshot -Name 'transparency' -Values @(@{Path=$key;Name=$name});New-Item -Path $key -Force|Out-Null;$target=if($Setting -eq 'On'){1}else{0};Set-ItemProperty -LiteralPath $key -Name $name -Value $target -Type DWord;if((Get-ItemProperty -LiteralPath $key -Name $name).$name -ne $target){throw 'Windows did not retain the transparency preference.'};$result=$Setting.ToUpperInvariant()}
    else{if(-not(Restore-ApexRegistrySnapshot -Name 'transparency')){throw 'No Apex transparency snapshot exists.'};$result='previous setting restored'}
    $log=Write-ApexLog -Action 'Transparency' -Result 'Success' -Message $result;"Transparency: $result. Log: $log"
}catch{$log=Write-ApexLog -Action 'Transparency' -Result 'Failed' -Message $_.Exception.Message;[Console]::Error.WriteLine("$($_.Exception.Message) Log: $log");exit 1}