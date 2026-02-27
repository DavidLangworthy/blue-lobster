# Post-provision hook: build and push the OpenClaw image.
[CmdletBinding()]
param(
    [string]$ContainerRegistryName = $env:CONTAINER_REGISTRY_NAME,
    [string]$OpenClawVersion = $env:OPENCLAW_VERSION
)

$ErrorActionPreference = "Stop"

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
