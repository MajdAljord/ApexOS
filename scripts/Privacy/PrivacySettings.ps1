param([ValidateSet('Status','Apply','Restore')][string]$Mode='Status')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\Modules\Apex.Common.psm1') -Force

$values=@(
    @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo';Name='Enabled';Target=0},
    @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy';Name='TailoredExperiencesWithDiagnosticDataEnabled';Target=0}
)

try {
    if($Mode -eq 'Status'){
        $states=foreach($item in $values){
            $value=(Get-ItemProperty -LiteralPath $item.Path -Name $item.Name -ErrorAction SilentlyContinue).$($item.Name)
            [pscustomobject]@{Name=$item.Name;State=if($null -eq $value){'Not configured'}elseif([int]$value -eq 0){'Off'}else{'On'}}
        }
        "Advertising ID: $($states[0].State); diagnostic personalization: $($states[1].State)"
        exit 0
    }

    if($Mode -eq 'Apply'){
        Save-ApexRegistrySnapshot -Name 'privacy-personalization' -Values $values
        foreach($item in $values){
            New-Item -Path $item.Path -Force|Out-Null
            Set-ItemProperty -LiteralPath $item.Path -Name $item.Name -Value $item.Target -Type DWord
            $actual=(Get-ItemProperty -LiteralPath $item.Path -Name $item.Name).$($item.Name)
            if($actual -ne $item.Target){throw "Windows did not retain the requested privacy setting '$($item.Name)'."}
        }
    }else{
        if(-not(Restore-ApexRegistrySnapshot -Name 'privacy-personalization')){throw 'No saved Apex privacy snapshot exists to restore.'}
    }
    $log=Write-ApexLog -Action 'Privacy Personalization' -Result 'Success' -Message $Mode
    "Privacy personalization: $Mode completed and verified. Log: $log"
}catch{
    $log=Write-ApexLog -Action 'Privacy Personalization' -Result 'Failed' -Message $_.Exception.Message
    [Console]::Error.WriteLine("$($_.Exception.Message) Log: $log")
    exit 1
}