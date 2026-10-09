$ErrorActionPreference = 'Stop'

$payloadRoot = Join-Path $PSScriptRoot 'ApexDesktop'
if (-not (Test-Path -LiteralPath $payloadRoot -PathType Container)) {
    throw "The packaged ApexDesktop payload is missing: $payloadRoot"
}

$installRoot = Join-Path $env:WINDIR 'ApexDesktop'
$logDirectory = Join-Path $installRoot 'Logs'
New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
$installLog = Join-Path $logDirectory ("Apex-install-{0}.log" -f (Get-Date -Format 'yyyy-MM-dd'))

function Write-ApexInstallLog {
    param(
        [Parameter(Mandatory)][string]$Action,
        [Parameter(Mandatory)][string]$Result,
        [Nullable[int]]$ExitCode,
        [string]$Details = ''
    )
    $code = if ($null -eq $ExitCode) { 'N/A' } else { $ExitCode.ToString() }
    $entry = "{0} | category=Install | action={1} | {2} | exit code {3} | {4}" -f (Get-Date -Format o), $Action, $Result, $code, ($Details -replace '[\r\n]+', ' ')
    try { Add-Content -LiteralPath $installLog -Value $entry -Encoding UTF8 }
    catch { Write-Warning "Could not append to the Apex installation log: $($_.Exception.Message)" }
}

$separatorCharacters = [char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
$payloadPrefix = [IO.Path]::GetFullPath($payloadRoot).TrimEnd($separatorCharacters) + [IO.Path]::DirectorySeparatorChar
New-Item -Path $installRoot -ItemType Directory -Force | Out-Null

Get-ChildItem -LiteralPath $payloadRoot -Directory -Recurse | ForEach-Object {
    $relativePath = $_.FullName.Substring($payloadPrefix.Length)
    New-Item -Path (Join-Path $installRoot $relativePath) -ItemType Directory -Force | Out-Null
}

$copiedFiles = 0
$preservedWallpapers = 0
Get-ChildItem -LiteralPath $payloadRoot -File -Recurse | ForEach-Object {
    $relativePath = $_.FullName.Substring($payloadPrefix.Length)
    $destination = Join-Path $installRoot $relativePath
    $isWallpaper = $relativePath.StartsWith("Wallpapers$([IO.Path]::DirectorySeparatorChar)", [StringComparison]::OrdinalIgnoreCase)

    if ($isWallpaper -and (Test-Path -LiteralPath $destination -PathType Leaf)) {
        $preservedWallpapers++
        return
    }

    Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
    $copiedFiles++
}

$desktopWallpaper = Join-Path $installRoot 'Wallpapers\Apex-Default-Dark.jpg'
$lockScreenWallpaper = Join-Path $installRoot 'Wallpapers\Apex-LockScreen-Dark.jpg'
$wallpaperScript = Join-Path $installRoot 'scripts\Personalization\Wallpaper.ps1'
if ((Test-Path -LiteralPath $desktopWallpaper -PathType Leaf) -and
    (Test-Path -LiteralPath $wallpaperScript -PathType Leaf)) {
    try {
        $powerShell = Join-Path $PSHOME 'powershell.exe'
        $wallpaperOutput = (& $powerShell -NoProfile -ExecutionPolicy Bypass -File $wallpaperScript -Mode Set -Name 'Apex-Default-Dark.jpg' 2>&1 | Out-String).Trim()
        $wallpaperExitCode = $LASTEXITCODE
        if ($wallpaperExitCode -ne 0) {
            Write-ApexInstallLog -Action 'Default desktop wallpaper' -Result 'Failed' -ExitCode $wallpaperExitCode -Details $wallpaperOutput
            Write-Warning "Apex could not apply the default desktop wallpaper. Installation will continue. See $installLog"
        } else {
            Write-ApexInstallLog -Action 'Default desktop wallpaper' -Result 'Applied and verified' -ExitCode 0 -Details $wallpaperOutput
        }
    } catch {
        Write-ApexInstallLog -Action 'Default desktop wallpaper' -Result 'Failed' -ExitCode 1 -Details $_.Exception.Message
        Write-Warning "Apex could not apply the default desktop wallpaper. Installation will continue. See $installLog"
    }
} else {
    $missing = if (-not (Test-Path -LiteralPath $desktopWallpaper -PathType Leaf)) { 'Default wallpaper asset is missing.' } else { 'Wallpaper script is missing.' }
    Write-ApexInstallLog -Action 'Default desktop wallpaper' -Result 'Unavailable' -ExitCode $null -Details $missing
    Write-Warning "$missing Installation will continue. See $installLog"
}

Write-Output "Apex OS installed to $installRoot. Copied $copiedFiles files; preserved $preservedWallpapers existing wallpaper files."
if (Test-Path -LiteralPath $lockScreenWallpaper -PathType Leaf) {
    if (Test-Path -LiteralPath $wallpaperScript -PathType Leaf) {
        try {
            $powerShell = Join-Path $PSHOME 'powershell.exe'
            $lockScreenOutput = (& $powerShell -NoProfile -ExecutionPolicy Bypass -File $wallpaperScript -Mode SetLockScreen -Name 'Apex-LockScreen-Dark.jpg' 2>&1 | Out-String).Trim()
            $lockScreenExitCode = $LASTEXITCODE
            if ($lockScreenExitCode -ne 0) {
                Write-ApexInstallLog -Action 'Default lock-screen wallpaper' -Result 'Unavailable or rejected by Windows' -ExitCode $lockScreenExitCode -Details $lockScreenOutput
                Write-Warning "Windows did not apply the Apex lock-screen image. Installation will continue. Details: $lockScreenOutput"
            } else {
                Write-ApexInstallLog -Action 'Default lock-screen wallpaper' -Result 'Windows accepted assignment; active stream available; exact source identity not exposed' -ExitCode 0 -Details $lockScreenOutput
                Write-Output $lockScreenOutput
            }
        } catch {
            Write-ApexInstallLog -Action 'Default lock-screen wallpaper' -Result 'Failed' -ExitCode 1 -Details $_.Exception.Message
            Write-Warning "Apex could not apply the lock-screen image. Installation will continue. Reason: $($_.Exception.Message)"
        }
    } else {
        Write-ApexInstallLog -Action 'Default lock-screen wallpaper' -Result 'Unavailable' -ExitCode $null -Details 'Wallpaper script is missing.'
        Write-Warning 'Apex wallpaper script is missing; lock-screen image was not applied.'
    }
} else {
    Write-ApexInstallLog -Action 'Default lock-screen wallpaper' -Result 'Unavailable' -ExitCode $null -Details 'Apex-LockScreen-Dark.jpg is not present.'
    Write-Output 'Apex-LockScreen-Dark.jpg is not present; no lock-screen image was installed.'
}
Write-ApexInstallLog -Action 'Apex installation' -Result 'Completed' -ExitCode 0 -Details "Copied $copiedFiles files; preserved $preservedWallpapers existing wallpaper files."
