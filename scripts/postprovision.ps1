# Post-provision hook: build and push the OpenClaw image.
[CmdletBinding()]
param(
    [string]$ContainerRegistryName = $env:CONTAINER_REGISTRY_NAME,
    [string]$OpenClawVersion = $env:OPENCLAW_VERSION
)

$ErrorActionPreference = "Stop"

if ($env:SKIP_IMAGE_BUILD -and $env:SKIP_IMAGE_BUILD.ToLowerInvariant() -eq "true") {
    Write-Host "Post-provision: SKIP_IMAGE_BUILD=true; skipping application image build" -ForegroundColor Yellow
    exit 0
}

Write-Host "Post-provision: building application image" -ForegroundColor Cyan

if (-not $ContainerRegistryName) {
    Write-Error "CONTAINER_REGISTRY_NAME is not set"
    exit 1
}

if (-not $OpenClawVersion) {
    $OpenClawVersion = "main"
}

$scriptPath = Join-Path $PSScriptRoot "build-image.ps1"
& $scriptPath -AcrName $ContainerRegistryName -ImageTag "latest" -OpenClawVersion $OpenClawVersion

Write-Host "Post-provision complete" -ForegroundColor Green
