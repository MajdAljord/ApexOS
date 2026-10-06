param([ValidateSet('Status','Diagnose','Repair')][string]$Mode='Status')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\Modules\Apex.Common.psm1') -Force

function Get-NetworkState {
    $adapters=@(Get-NetAdapter -IncludeHidden|Select-Object Name,InterfaceDescription,Status,LinkSpeed,MacAddress)
    $pnp=@(Get-CimInstance Win32_PnPEntity|Where-Object { $_.PNPClass -eq 'Net' -and $_.ConfigManagerErrorCode -ne 0 }|Select-Object Name,PNPDeviceID,ConfigManagerErrorCode,Status)
    $configs=@(Get-NetIPConfiguration|Where-Object IPv4DefaultGateway)
    $gateway=if($configs.Count){$configs[0].IPv4DefaultGateway.NextHop}else{$null}
    $gatewayReachable=$false
    if($gateway){$gatewayReachable=Test-Connection -ComputerName $gateway -Count 1 -Quiet -ErrorAction SilentlyContinue}
    $internetReachable=Test-NetConnection -ComputerName '1.1.1.1' -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
    $dnsWorks=$false
    try { Resolve-DnsName -Name 'www.microsoft.com' -Type A -ErrorAction Stop|Out-Null;$dnsWorks=$true } catch { }
    $upAdapters=@($adapters|Where-Object Status -eq 'Up')
    $category=if($pnp.Count){'Driver'}elseif(-not $upAdapters.Count){'Adapter'}elseif(-not $gateway){'Windows networking configuration'}elseif(-not $gatewayReachable){'Gateway/router or local link'}elseif(-not $internetReachable){'Router or internet path'}elseif(-not $dnsWorks){'DNS'}else{'No fault detected'}
    [pscustomobject]@{Time=(Get-Date -Format o);Category=$category;Adapters=$adapters;NetworkDeviceErrors=$pnp;DefaultGateway=$gateway;GatewayReachable=[bool]$gatewayReachable;InternetTcpReachable=[bool]$internetReachable;DnsResolution=[bool]$dnsWorks}
}

try {
    if($Mode -eq 'Status'){'Ready';exit 0}
    $before=Get-NetworkState
    $after=$null
    $change='No repair applied; evidence did not identify a safe automatic change.'
    if($Mode -eq 'Repair' -and $before.Category -eq 'DNS' -and $before.GatewayReachable -and $before.InternetTcpReachable){
        $flush=ipconfig.exe /flushdns 2>&1
        if($LASTEXITCODE -ne 0){throw "DNS cache flush failed ($LASTEXITCODE): $flush"}
        $after=Get-NetworkState
        $change='Flushed the DNS resolver cache because gateway and TCP reachability passed while DNS failed.'
    }
    $logMessage="$change Before=$($before.Category); After=$(if($after){$after.Category}else{'not re-tested'})"
    $log=Write-ApexLog -Action 'Network Recovery' -Result 'Complete' -Message $logMessage
    $result=[pscustomobject]@{Change=$change;Before=$before;After=$after;Log=$log}|ConvertTo-Json -Depth 7
    if($Mode -eq 'Repair' -and -not $after){'No safe automatic repair was indicated. No adapter, driver, or network-stack reset was attempted.'}
    $result
}catch{
    $log=Write-ApexLog -Action 'Network Recovery' -Result 'Failed' -Message $_.Exception.Message
    [Console]::Error.WriteLine("$($_.Exception.Message) Log: $log")
    exit 1
}