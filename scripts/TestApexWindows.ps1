param()
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
if([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT){throw 'Run this smoke test on Windows 11.'}
$current=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$build=[int]$current.CurrentBuildNumber
if($build -lt 22000 -or $current.ProductName -match 'Server'){throw "Windows 11 client is required. Detected $($current.ProductName), build $build."}

$validator=Join-Path $PSScriptRoot 'ValidateProject.ps1'
if(Test-Path -LiteralPath (Join-Path $root 'src\ApexToolbox\ApexToolbox.csproj')){
    & $validator
    if($LASTEXITCODE -ne 0){throw "Project validation failed with exit code $LASTEXITCODE."}
}
$configPath=Join-Path $root 'config/toolbox.json'
if(-not(Test-Path -LiteralPath $configPath)){$configPath=Join-Path $root 'Toolbox\config\toolbox.json'}
$config=Get-Content -LiteralPath $configPath -Raw|ConvertFrom-Json
$powershell=(Get-Command powershell.exe -ErrorAction Stop).Source
$seen=@{}
$failures=[Collections.Generic.List[string]]::new()
$checks=0
foreach($action in $config.actions){
    $statusArgs=@($action.statusArgs)
    $key="$($action.script)|$(ConvertTo-Json -InputObject $statusArgs -Compress)"
    if($seen.ContainsKey($key)){continue}
    $seen[$key]=$true
    $script=Join-Path $root $action.script
    $arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$script)+$statusArgs
    $output=& $powershell @arguments 2>&1
    $code=$LASTEXITCODE
    $checks++
    if($code -ne 0){
        $failures.Add("$($action.id): exit $code; $($output -join ' ')")
        Write-Host "FAIL $($action.id) (exit $code)" -ForegroundColor Red
    }else{
        Write-Host "PASS $($action.id) status probe" -ForegroundColor Green
    }
}

Write-Host "Read-only status probes: $checks; failures: $($failures.Count)."
Write-Host 'No setting changes were applied. This is not a full Windows feature test.'
if($failures.Count){$failures|ForEach-Object{[Console]::Error.WriteLine($_)};exit 1}
exit 0