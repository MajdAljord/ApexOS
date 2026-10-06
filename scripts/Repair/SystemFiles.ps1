param([ValidateSet('Status','Repair')][string]$Mode='Status')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\Modules\Apex.Common.psm1') -Force

function Invoke-ApexRepairCommand {
    param([string]$Action,[string]$Executable,[string[]]$Arguments,[int[]]$AllowedExitCodes=@(0))
    $output=& $Executable @Arguments 2>&1
    $code=$LASTEXITCODE
    $text=($output|Out-String).Trim()
    $result=if($code -in $AllowedExitCodes){'Success'}else{'Failed'}
    $log=Write-ApexLog -Action $Action -Result $result -Message "ExitCode=$code; $text"
    if($code -notin $AllowedExitCodes){throw "$Action failed (exit $code). Log: $log`n$text"}
    [pscustomobject]@{Action=$Action;ExitCode=$code;Output=$text;Log=$log}
}

try {
    if($Mode -eq 'Status'){'Ready';exit 0}
    if(-not(Test-ApexAdministrator)){throw 'Run system-file repair as administrator.'}
    $dism=Invoke-ApexRepairCommand 'DISM RestoreHealth' 'dism.exe' @('/Online','/Cleanup-Image','/RestoreHealth')
    $sfc=Invoke-ApexRepairCommand 'SFC ScanNow' 'sfc.exe' @('/scannow') @(0,1)
    @($dism,$sfc)|ConvertTo-Json -Depth 4
}catch{
    $log=Write-ApexLog -Action 'System File Repair' -Result 'Failed' -Message $_.Exception.Message
    [Console]::Error.WriteLine("$($_.Exception.Message) Log: $log")
    exit 1
}