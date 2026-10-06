param([ValidateSet('Status','Report','OpenDefaultApps')][string]$Mode='Status')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\Modules\Apex.Common.psm1') -Force
$extensions=@('.zip','.7z','.rar','.tar','.gz','.bz2','.xz')
try {
    $package=Get-AppxPackage -Name 'MouriNaruto.NanaZip' -ErrorAction SilentlyContinue|Select-Object -First 1
    if($Mode -eq 'Status'){
        if($package){"NanaZip: installed ($($package.Version))"}else{'NanaZip: not installed'}
        exit 0
    }
    if(-not $package){throw 'NanaZip is not installed for the current user. Install it from a trusted source before configuring associations.'}
    if($Mode -eq 'OpenDefaultApps'){
        Start-Process 'ms-settings:defaultapps?registeredAppUser=MouriNaruto.NanaZip'
        $output='Opened Windows Default apps. Choose NanaZip for supported archive formats; Windows controls these associations.'
    }else{
        $rows=foreach($extension in $extensions){
            $choice=Get-ItemProperty -LiteralPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$extension\UserChoice" -Name ProgId -ErrorAction SilentlyContinue
            [pscustomobject]@{Extension=$extension;Program=$choice.ProgId;NanaZip=([string]$choice.ProgId -match 'NanaZip')}
        }
        $output=$rows|Format-Table -AutoSize|Out-String
    }
    $log=Write-ApexLog -Action 'NanaZip Configuration' -Result 'Success' -Message $Mode
    "$output`nApex does not modify protected UserChoice hashes or remove Windows components.`nLog: $log"
}catch{
    $log=Write-ApexLog -Action 'NanaZip Configuration' -Result 'Failed' -Message $_.Exception.Message
    [Console]::Error.WriteLine("$($_.Exception.Message) Log: $log")
    exit 1
}