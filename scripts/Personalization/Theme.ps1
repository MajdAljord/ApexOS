param([ValidateSet('Status','Set','Restore')][string]$Mode='Status',[ValidateSet('Dark','Light')][string]$Theme='Dark')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\Modules\Apex.Common.psm1') -Force
$key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
$values=@(@{Path=$key;Name='AppsUseLightTheme'},@{Path=$key;Name='SystemUsesLightTheme'})
try {
    if($Mode -eq 'Status'){
        $apps=(Get-ItemProperty -LiteralPath $key -Name AppsUseLightTheme -ErrorAction SilentlyContinue).AppsUseLightTheme
        $system=(Get-ItemProperty -LiteralPath $key -Name SystemUsesLightTheme -ErrorAction SilentlyContinue).SystemUsesLightTheme
        if($apps -eq 0 -and $system -eq 0){'DARK'}elseif($apps -eq 1 -and $system -eq 1){'LIGHT'}else{'WINDOWS DEFAULT/MIXED'}
        exit 0
    }
    if($Mode -eq 'Set'){
        Save-ApexRegistrySnapshot -Name 'theme' -Values $values
        New-Item -Path $key -Force|Out-Null
        $setting=if($Theme -eq 'Dark'){0}else{1}
        foreach($item in $values){Set-ItemProperty -LiteralPath $key -Name $item.Name -Value $setting -Type DWord}
        $apps=(Get-ItemProperty -LiteralPath $key -Name AppsUseLightTheme).AppsUseLightTheme
        $system=(Get-ItemProperty -LiteralPath $key -Name SystemUsesLightTheme).SystemUsesLightTheme
        if($apps -ne $setting -or $system -ne $setting){throw 'Windows did not retain both theme settings.'}
        $result=$Theme.ToUpperInvariant()
    }else{
        if(-not(Restore-ApexRegistrySnapshot -Name 'theme')){throw 'No Apex theme snapshot exists.'}
        $result='previous theme restored'
    }
    $log=Write-ApexLog -Action 'Theme' -Result 'Success' -Message $result
    "Theme: $result. Log: $log"
}catch{$log=Write-ApexLog -Action 'Theme' -Result 'Failed' -Message $_.Exception.Message;[Console]::Error.WriteLine("$($_.Exception.Message) Log: $log");exit 1}