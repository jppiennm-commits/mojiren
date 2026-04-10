param(
    [string]$BuildName,
    [int]$BuildNumber,
    [switch]$RunChecks
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$pubspecPath = Join-Path $projectRoot "pubspec.yaml"
$keyPropertiesPath = Join-Path $projectRoot "android\key.properties"
$bundleOutput = Join-Path $projectRoot "build\app\outputs\bundle\release\app-release.aab"

function Get-PubspecVersion {
    param([string]$Path)

    $versionLine = Select-String -Path $Path -Pattern '^version:\s*(.+)$' | Select-Object -First 1
    if (-not $versionLine) {
        throw "Could not find a version entry in pubspec.yaml."
    }

    if ($versionLine.Matches.Groups.Count -lt 2) {
        throw "Could not parse the version entry in pubspec.yaml."
    }

    $rawVersion = $versionLine.Matches.Groups[1].Value.Trim()
    $parts = $rawVersion.Split("+")
    if ($parts.Count -ne 2) {
        throw "The version must use the form 1.0.0+1."
    }

    return @{
        BuildName = $parts[0]
        BuildNumber = [int]$parts[1]
    }
}

function Assert-Command {
    param(
        [string]$Name,
        [string]$HelpText
    )

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "$Name was not found. $HelpText"
    }
}

$versionInfo = Get-PubspecVersion -Path $pubspecPath
if (-not $BuildName) {
    $BuildName = $versionInfo.BuildName
}
if (-not $BuildNumber) {
    $BuildNumber = $versionInfo.BuildNumber
}

Assert-Command -Name "flutter" -HelpText "Install the Flutter SDK and add it to PATH."

if (-not (Test-Path $keyPropertiesPath)) {
    throw "android\\key.properties was not found. Copy android\\key.properties.example and fill in the real values."
}

Push-Location $projectRoot
try {
    Write-Host "Using version $BuildName+$BuildNumber"
    flutter pub get

    if ($RunChecks) {
        flutter analyze
        flutter test
    }

    flutter build appbundle --release --build-name=$BuildName --build-number=$BuildNumber

    if (-not (Test-Path $bundleOutput)) {
        throw "AAB was not generated: $bundleOutput"
    }

    Write-Host ""
    Write-Host "AAB generated:"
    Write-Host $bundleOutput
}
finally {
    Pop-Location
}
