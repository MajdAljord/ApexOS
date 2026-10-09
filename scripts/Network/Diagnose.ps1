param([ValidateSet('Status','Diagnose','Repair','RepairWinsock','RepairTcpIp')][string]$Mode='Status')
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
    if($Mode -in @('RepairWinsock','RepairTcpIp')){
        $backupDirectory=Get-ApexBackupDirectory
        $backupPath=Join-Path $backupDirectory ("Network-Before-{0}.json" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
        $backup=[pscustomobject]@{
            CapturedAt=(Get-Date -Format o)
            Adapters=@(Get-NetAdapter -IncludeHidden|Select-Object Name,InterfaceDescription,Status,MacAddress)
            IpConfiguration=@(Get-NetIPConfiguration|Select-Object InterfaceAlias,InterfaceIndex,IPv4Address,IPv4DefaultGateway,DNSServer)
            DnsClient=@(Get-DnsClientServerAddress|Select-Object InterfaceAlias,AddressFamily,ServerAddresses)
            Routes=@(Get-NetRoute -ErrorAction SilentlyContinue|Where-Object DestinationPrefix -eq '0.0.0.0/0'|Select-Object InterfaceAlias,DestinationPrefix,NextHop,RouteMetric)
        }
        $backup|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $backupPath -Encoding UTF8
        if($Mode -eq 'RepairWinsock'){
            $output=& netsh.exe winsock reset 2>&1
        }else{
            $resetLog=Join-Path (Get-ApexLogDirectory) 'Apex-TcpIpReset.log'
            $output=& netsh.exe int ip reset $resetLog 2>&1
        }
        $code=$LASTEXITCODE
        if($code -ne 0){throw "$Mode failed with exit code ${code}: $($output -join ' ')"}
        $log=Write-ApexLog -Action "Network $Mode" -Result 'Reset accepted; restart required' -Message "Before=$($before.Category); Backup=$backupPath; Output=$($output -join ' ')"
        [pscustomobject]@{
            Change=if($Mode -eq 'RepairWinsock'){'Windows accepted a Winsock catalog reset request.'}else{'Windows accepted a TCP/IP stack reset request.'}
            RestartRequired=$true
            Before=$before
            Backup=$backupPath
            Log=$log
            Output=($output -join "`n")
        }|ConvertTo-Json -Depth 8
        exit 0
    }
    $after=$null
    $change='No repair applied; evidence did not identify a safe automatic change.'
    if($Mode -eq 'Repair' -and $before.Category -eq 'DNS' -and $before.GatewayReachable -and $before.InternetTcpReachable){
        $flush=ipconfig.exe /flushdns 2>&1
        if($LASTEXITCODE -ne 0){throw "DNS cache flush failed ($LASTEXITCODE): $flush"}
        $after=Get-NetworkState
        $change='Flushed the DNS resolver cache because gateway and TCP reachability passed while DNS failed.'
    }
    $logMessage="$change Before=$($before.Category); After=$(if($after){$after.Category}else{'not re-tested'})"
    $resolved=$null -ne $after -and $after.Category -eq 'No fault detected'
    $resultCode=if($Mode -eq 'Repair' -and $after -and -not $resolved){1}else{0}
    $logResult=if($resultCode -eq 0){'Complete'}else{'Failed - connectivity remains impaired'}
    $log=Write-ApexLog -Action 'Network Recovery' -Result $logResult -Message $logMessage
    $result=[pscustomobject]@{Change=$change;Before=$before;After=$after;Log=$log}|ConvertTo-Json -Depth 7
    if($Mode -eq 'Repair' -and -not $after){'No safe automatic repair was indicated. No adapter, driver, or network-stack reset was attempted.'}
    $result
    if($resultCode -ne 0){[Console]::Error.WriteLine("The safe DNS repair did not restore connectivity. Before: $($before.Category). After: $($after.Category). Log: $log");exit $resultCode}
}catch{
    $log=Write-ApexLog -Action 'Network Recovery' -Result 'Failed' -Message $_.Exception.Message
    [Console]::Error.WriteLine("$($_.Exception.Message) Log: $log")
    exit 1
}