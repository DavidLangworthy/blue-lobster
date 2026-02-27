# Build OpenClaw Docker image and push to Azure Container Registry using ACR Tasks.
param(
    [Parameter(Mandatory = $false)]
    [string]$AcrName,

    [Parameter(Mandatory = $false)]
    [string]$ImageTag = "latest",

    [Parameter(Mandatory = $false)]
    [string]$OpenClawVersion = "main"
)

$ErrorActionPreference = "Stop"

if (-not $AcrName) {
    $AcrName = (azd env get-values | Select-String -Pattern "^CONTAINER_REGISTRY_NAME=(.+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }).Trim('"')
}

if (-not $AcrName) {
    Write-Error "Container registry name not found. Run 'azd provision' first."
    exit 1
}

$DockerfilePath = Join-Path $PSScriptRoot "..\src\moltbot\Dockerfile"
$BuildContext = Join-Path $PSScriptRoot "..\src\moltbot"

Write-Host "Building image 'clawdbot:$ImageTag' in ACR '$AcrName'" -ForegroundColor Cyan
az acr build `
  --registry $AcrName `
  --image "clawdbot:$ImageTag" `
  --file $DockerfilePath `
  --build-arg "OPENCLAW_VERSION=$OpenClawVersion" `
  $BuildContext

if ($LASTEXITCODE -ne 0) {
    Write-Error "Image build failed"
    exit 1
}

Write-Host "Image build complete" -ForegroundColor Green
