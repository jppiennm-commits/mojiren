param(
    [string]$OutputFile = "upload-keystore.jks",
    [string]$Alias = "upload",
    [string]$Validity = "10000",
    [string]$StorePassword,
    [string]$KeyPassword
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$keystorePath = Join-Path $projectRoot $OutputFile

if (Test-Path $keystorePath) {
    throw "A keystore already exists at: $keystorePath"
}

if (-not (Get-Command "keytool" -ErrorAction SilentlyContinue)) {
    throw "keytool was not found. Install a JDK and add it to PATH."
}

$arguments = @(
    "-genkeypair",
    "-v",
    "-keystore", $keystorePath,
    "-alias", $Alias,
    "-keyalg", "RSA",
    "-keysize", "2048",
    "-validity", $Validity
)

if ($StorePassword) {
    $arguments += @("-storepass", $StorePassword)
}

if ($KeyPassword) {
    $arguments += @("-keypass", $KeyPassword)
}

Write-Host "Creating Android upload keystore..."
Write-Host "Output : $keystorePath"
Write-Host "Alias  : $Alias"
Write-Host ""

& keytool @arguments

if (-not (Test-Path $keystorePath)) {
    throw "Keystore was not created."
}

Write-Host ""
Write-Host "Keystore created."
Write-Host "Next: copy android\\key.properties.example to android\\key.properties and fill in the values."
