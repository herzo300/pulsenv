# Clean Windows junk and setup O&O ShutUp10++
$ErrorActionPreference = 'SilentlyContinue'

$toolsDir = 'C:\Tools\OOSU10'
if (-not (Test-Path $toolsDir)) {
    New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
}

$oosuPath = Join-Path $toolsDir 'OOSU10.exe'
Write-Host 'Downloading O&O ShutUp10++...'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile('https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe', $oosuPath)
    Write-Host "O&O ShutUp10++ downloaded successfully to $oosuPath"
} catch {
    Write-Host "Download error: $_"
}

if (Test-Path $oosuPath) {
    Write-Host 'Applying recommended privacy & security settings...'
    Start-Process -FilePath $oosuPath -ArgumentList '/apply-recommended /quiet' -Wait -NoNewWindow
    Write-Host 'O&O ShutUp10++ configuration applied!'
}

Write-Host 'Cleaning Windows Temp and Junk files...'
$pathsToClean = @(
    $env:TEMP,
    'C:\Windows\Temp',
    "$env:LOCALAPPDATA\Temp",
    'C:\Windows\SoftwareDistribution\Download'
)

$freedCount = 0
foreach ($dir in $pathsToClean) {
    if (Test-Path $dir) {
        $items = Get-ChildItem -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
        foreach ($item in $items) {
            try {
                Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                $freedCount++
            } catch {}
        }
    }
}

Write-Host "Windows junk cleanup finished! Deleted $freedCount temporary files and caches."
