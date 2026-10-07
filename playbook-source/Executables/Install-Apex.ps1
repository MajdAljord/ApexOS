$ErrorActionPreference = 'Stop'

$payloadRoot = Join-Path $PSScriptRoot 'ApexDesktop'
if (-not (Test-Path -LiteralPath $payloadRoot -PathType Container)) {
    throw "The packaged ApexDesktop payload is missing: $payloadRoot"
}

$installRoot = Join-Path $env:WINDIR 'ApexDesktop'
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

$desktopWallpaper = Join-Path $installRoot 'Wallpapers\Apex-Dark.jpg'
$lockScreenWallpaper = Join-Path $installRoot 'Wallpapers\Apex-LockScreen-Dark.jpg'
$wallpaperScript = Join-Path $installRoot 'scripts\Personalization\Wallpaper.ps1'
if ((Test-Path -LiteralPath $desktopWallpaper -PathType Leaf) -and
    (Test-Path -LiteralPath $wallpaperScript -PathType Leaf)) {
    & $wallpaperScript -Mode Set -Name 'Apex-Dark.jpg'
    if (-not $?) {
        throw 'Apex desktop wallpaper setup failed.'
    }
} else {
    Write-Warning 'Apex-Dark.jpg or the Apex wallpaper script is not present; the desktop wallpaper was not changed.'
}

Write-Output "Apex OS installed to $installRoot. Copied $copiedFiles files; preserved $preservedWallpapers existing wallpaper files."
if (Test-Path -LiteralPath $lockScreenWallpaper -PathType Leaf) {
    Write-Output "Lock-screen image included: $lockScreenWallpaper. Choose it in Windows or Apex Toolbox where permitted."
} else {
    Write-Output 'Apex-LockScreen-Dark.jpg is not present; no lock-screen image was installed.'
}
