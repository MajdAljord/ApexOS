param([ValidateSet('Status','Check')][string]$Mode='Status')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\Modules\Apex.Common.psm1') -Force

try {
    $defender=[pscustomobject]@{Available=$false;RealTimeProtection=$null;AntivirusEnabled=$null;AntispywareEnabled=$null;SignatureAgeDays=$null;Reason='Microsoft Defender status cmdlet is unavailable.'}
    if(Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue){
        try {
            $status=Get-MpComputerStatus -ErrorAction Stop
            $defender=[pscustomobject]@{
                Available=$true
                RealTimeProtection=[bool]$status.RealTimeProtectionEnabled
                AntivirusEnabled=[bool]$status.AntivirusEnabled
                AntispywareEnabled=[bool]$status.AntispywareEnabled
                SignatureAgeDays=[int]$status.AntivirusSignatureAge
                Reason=$null
            }
        }catch{$defender.Reason=$_.Exception.Message}
    }

    $firewall=@()
    $firewallReason=$null
    try {
        $firewall=@(Get-NetFirewallProfile -ErrorAction Stop|Select-Object Name,Enabled)
        if(-not $firewall.Count){$firewallReason='Windows returned no firewall profiles.'}
    }catch{$firewallReason=$_.Exception.Message}

    $report=[pscustomobject]@{
        CheckedAt=(Get-Date -Format o)
        Defender=$defender
        Firewall=[pscustomobject]@{Available=($firewall.Count -gt 0);Profiles=$firewall;Reason=$firewallReason}
    }
    $result=$report|ConvertTo-Json -Depth 5 -Compress
    $log=Write-ApexLog -Action 'Security Status' -Result 'Complete' -Message "DefenderAvailable=$($defender.Available); FirewallProfiles=$($firewall.Count)"
    if($Mode -eq 'Status'){$result}else{"$result`nLog: $log"}
}catch{
    $log=Write-ApexLog -Action 'Security Status' -Result 'Failed' -Message $_.Exception.Message
    [Console]::Error.WriteLine("Security status could not be read. $($_.Exception.Message) Log: $log")
    exit 1
}