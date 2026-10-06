param([ValidateSet('Status','Select','Restore')][string]$Mode='Status',[string]$Name='Apex Performance')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\Modules\Apex.Common.psm1') -Force
$names=@('Apex Ultimate Performance','Apex Performance','Apex Balanced','Apex Power Saver','Apex Laptop Performance')
function Get-ActivePlan {
    $line=powercfg.exe /getactivescheme 2>&1 | Select-Object -First 1
    if($line -match '([0-9a-fA-F-]{36})\s*\((.*?)\)'){return [pscustomobject]@{Guid=$matches[1];Name=$matches[2]}}
    throw "Could not read active power plan: $line"
}
function Invoke-PowerCfg {
    param([string[]]$Arguments)
    $output=& powercfg.exe @Arguments 2>&1
    if($LASTEXITCODE -ne 0){throw "powercfg $($Arguments -join ' ') failed ($LASTEXITCODE): $output"}
    $output
}
try {
    if($Mode -eq 'Status'){$active=Get-ActivePlan;$type=Get-ApexDeviceType;"$($active.Name) [$($active.Guid)] | $type";exit 0}
    $dataPath=Get-ApexSnapshotPath 'power-plans'
    $state=if(Test-Path $dataPath){Get-Content $dataPath -Raw|ConvertFrom-Json}else{$null}
    if($Mode -eq 'Restore'){
        if(-not $state -or -not $state.PreviousGuid){throw 'No Apex power-plan selection snapshot exists.'}
        $previousGuid=[string]$state.PreviousGuid
        Invoke-PowerCfg @('/setactive',$previousGuid)|Out-Null
        $restored=Get-ActivePlan
        if($restored.Guid -ne $previousGuid){throw "Previous power plan was not activated; active plan is $($restored.Name)."}
        $state.PreviousGuid = $null
        $state | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $dataPath -Encoding UTF8
        $log=Write-ApexLog 'Power Plan Restore' 'Success' $previousGuid
        "Restored prior plan. Log: $log"
        exit 0
    }
    if($Name -notin $names){throw "Unsupported Apex power plan: $Name"}
    $available=(powercfg.exe /list 2>&1) -join "`n"
    $schemes=@{}
    if($state){foreach($property in $state.Schemes.PSObject.Properties){if($available -match [regex]::Escape([string]$property.Value)){$schemes[$property.Name]=[string]$property.Value}}}
    foreach($planName in $names){
        if(-not $schemes.ContainsKey($planName)){
            $copy=Invoke-PowerCfg @('/duplicatescheme','SCHEME_BALANCED');$text=$copy -join ' '
            if($text -notmatch '([0-9a-fA-F-]{36})'){throw "Could not parse duplicated scheme GUID: $text"}
            $guid=$matches[1]
            Invoke-PowerCfg @('/changename',$guid,$planName,"Apex OS $planName")|Out-Null
            $schemes[$planName]=$guid
        }
    }
    $ultimate=$schemes['Apex Ultimate Performance'];$performance=$schemes['Apex Performance'];$saver=$schemes['Apex Power Saver'];$laptop=$schemes['Apex Laptop Performance']
    Invoke-PowerCfg @('/setacvalueindex',$ultimate,'SUB_PROCESSOR','PROCTHROTTLEMAX','100')|Out-Null
    Invoke-PowerCfg @('/setacvalueindex',$ultimate,'SUB_PROCESSOR','PROCTHROTTLEMIN','100')|Out-Null
    Invoke-PowerCfg @('/setacvalueindex',$ultimate,'SUB_PROCESSOR','PERFBOOSTMODE','2')|Out-Null
    Invoke-PowerCfg @('/setacvalueindex',$performance,'SUB_PROCESSOR','PROCTHROTTLEMAX','100')|Out-Null
    Invoke-PowerCfg @('/setacvalueindex',$performance,'SUB_PROCESSOR','PERFBOOSTMODE','3')|Out-Null
    Invoke-PowerCfg @('/setacvalueindex',$saver,'SUB_PROCESSOR','PROCTHROTTLEMAX','70')|Out-Null
    Invoke-PowerCfg @('/setdcvalueindex',$saver,'SUB_PROCESSOR','PROCTHROTTLEMAX','60')|Out-Null
    Invoke-PowerCfg @('/setacvalueindex',$laptop,'SUB_PROCESSOR','PROCTHROTTLEMAX','100')|Out-Null
    Invoke-PowerCfg @('/setdcvalueindex',$laptop,'SUB_PROCESSOR','PROCTHROTTLEMAX','80')|Out-Null
    $prior=if($state -and $state.PreviousGuid){[string]$state.PreviousGuid}else{(Get-ActivePlan).Guid}
    [pscustomobject]@{PreviousGuid=$prior;Schemes=$schemes}|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $dataPath -Encoding UTF8
    Invoke-PowerCfg @('/setactive',[string]$schemes[$Name])|Out-Null
    $active=Get-ActivePlan
    if($active.Guid -ne $schemes[$Name]){throw "Requested plan did not become active; active plan is $($active.Name)."}
    $log=Write-ApexLog 'Power Plan Select' 'Success' $active.Name
    $type=Get-ApexDeviceType
    "Active plan: $($active.Name). Detected device: $type. Apex plans remain installed. Log: $log"
}catch{$log=Write-ApexLog 'Power Plan' 'Failed' $_.Exception.Message;[Console]::Error.WriteLine("$($_.Exception.Message) Log: $log");exit 1}