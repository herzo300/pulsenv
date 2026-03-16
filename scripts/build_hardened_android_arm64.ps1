param(
    [Parameter(Mandatory = $true)]
    [string]$BackendBaseUrl,
    [string]$McpFetchUrl = "",
    [string]$McpReportsApiUrl = "",
    [string]$SplitDebugInfoDir = "services/Frontend/build/obfuscation-symbols",
    [switch]$AllowInsecureDebugSigningForRelease
)

$ErrorActionPreference = "Stop"

if (-not $BackendBaseUrl.StartsWith("https://")) {
    throw "BACKEND_BASE_URL must use https:// for hardened release builds."
}

if (-not (Test-Path "services/Frontend")) {
    throw "Run this script from the repository root."
}

if (-not $env:JAVA_HOME -and (Test-Path "C:\Program Files\Android\Android Studio\jbr")) {
    $env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
    $env:Path = "$env:JAVA_HOME\bin;$env:Path"
}

$previousGradleUserHome = $env:GRADLE_USER_HOME
if ([string]::IsNullOrWhiteSpace($env:GRADLE_USER_HOME)) {
    $env:GRADLE_USER_HOME = "C:\gradle-cache"
}
New-Item -ItemType Directory -Force -Path $env:GRADLE_USER_HOME | Out-Null

if (-not $AllowInsecureDebugSigningForRelease) {
    $required = @(
        "ANDROID_KEYSTORE_PATH",
        "ANDROID_KEYSTORE_PASSWORD",
        "ANDROID_KEY_ALIAS",
        "ANDROID_KEY_PASSWORD"
    )
    $missing = $required | Where-Object {
        $name = $_
        [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))
    }
    if ($missing.Count -gt 0 -and -not (Test-Path "services/Frontend/android/keystore.properties")) {
        throw "Release signing is not configured. Missing env vars: $($missing -join ', ')"
    }
}

New-Item -ItemType Directory -Force -Path $SplitDebugInfoDir | Out-Null

Push-Location "services/Frontend"
try {
    $previousFlag = $env:ALLOW_INSECURE_DEBUG_SIGNING_FOR_RELEASE
    if ($AllowInsecureDebugSigningForRelease) {
        $env:ALLOW_INSECURE_DEBUG_SIGNING_FOR_RELEASE = "true"
    }
    $args = @(
        "build", "apk",
        "--release",
        "--target-platform", "android-arm64",
        "--split-per-abi",
        "--obfuscate",
        "--split-debug-info=$SplitDebugInfoDir",
        "--dart-define=BACKEND_BASE_URL=$BackendBaseUrl"
    )
    if ($McpFetchUrl) {
        $args += "--dart-define=MCP_FETCH_URL=$McpFetchUrl"
    }
    if ($McpReportsApiUrl) {
        $args += "--dart-define=MCP_REPORTS_API_URL=$McpReportsApiUrl"
    }
    & flutter @args
    if ($null -eq $previousFlag) {
        Remove-Item Env:ALLOW_INSECURE_DEBUG_SIGNING_FOR_RELEASE -ErrorAction SilentlyContinue
    } else {
        $env:ALLOW_INSECURE_DEBUG_SIGNING_FOR_RELEASE = $previousFlag
    }
} finally {
    if ($null -eq $previousGradleUserHome) {
        Remove-Item Env:GRADLE_USER_HOME -ErrorAction SilentlyContinue
    } else {
        $env:GRADLE_USER_HOME = $previousGradleUserHome
    }
    Pop-Location
}
