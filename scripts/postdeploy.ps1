# Post-deploy verification for OpenClaw on Azure Container Apps.
[CmdletBinding()]
param(
    [string]$ResourceGroup = $env:AZURE_RESOURCE_GROUP,
    [string]$OpenClawAppName = $(if ($env:OPENCLAW_APP_NAME) { $env:OPENCLAW_APP_NAME } else { $env:CLAWDBOT_APP_NAME }),
    [string]$OpenClawGatewayUrl = $(if ($env:OPENCLAW_GATEWAY_URL) { $env:OPENCLAW_GATEWAY_URL } else { $env:CLAWDBOT_GATEWAY_URL }),
    [string]$AzureOpenAiEndpoint = $env:AZURE_OPENAI_ENDPOINT,
    [string]$AzureOpenAiApiKey = $env:AZURE_OPENAI_API_KEY,
    [string]$AzureOpenAiDeployment = $env:AZURE_OPENAI_DEPLOYMENT,
    [string]$AzureOpenAiAccountName = $env:AZURE_OPENAI_ACCOUNT_NAME
)

$ErrorActionPreference = "Stop"

if (-not $OpenClawGatewayUrl) {
    Write-Error "OPENCLAW_GATEWAY_URL (or CLAWDBOT_GATEWAY_URL) is not set"
    exit 1
}

Write-Host "Post-deploy verification" -ForegroundColor Cyan
Write-Host "Checking gateway health at $OpenClawGatewayUrl/health" -ForegroundColor Gray

$maxRetries = 30
$retryCount = 0
$isHealthy = $false

while ($retryCount -lt $maxRetries -and -not $isHealthy) {
    $retryCount++
    try {
        $response = Invoke-WebRequest -Uri "$OpenClawGatewayUrl/health" -Method GET -TimeoutSec 5 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $isHealthy = $true
        }
    }
    catch {
        Write-Host "  attempt $retryCount/$maxRetries - waiting for gateway" -ForegroundColor DarkGray
        Start-Sleep -Seconds 10
    }
}

if (-not $isHealthy) {
    Write-Warning "Health check timed out"
    if ($ResourceGroup -and $OpenClawAppName) {
        Write-Host "Inspect logs: az containerapp logs show --name $OpenClawAppName --resource-group $ResourceGroup --follow" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Deployment status summary" -ForegroundColor White
Write-Host "Gateway URL: $OpenClawGatewayUrl" -ForegroundColor Gray
Write-Host "Health: $isHealthy" -ForegroundColor Gray

$aoaiLiveness = "skipped"
if (-not $AzureOpenAiApiKey -and $AzureOpenAiAccountName -and $ResourceGroup) {
    try {
        $AzureOpenAiApiKey = az cognitiveservices account keys list -g $ResourceGroup -n $AzureOpenAiAccountName --query key1 -o tsv
    }
    catch {
        $AzureOpenAiApiKey = ""
    }
}

if ($AzureOpenAiEndpoint -and $AzureOpenAiApiKey -and $AzureOpenAiDeployment) {
    try {
        $trimmedEndpoint = $AzureOpenAiEndpoint.TrimEnd("/")
        $headers = @{
            "api-key" = $AzureOpenAiApiKey
            "Content-Type" = "application/json"
        }
        $body = @{
            model = $AzureOpenAiDeployment
            input = "healthcheck: reply with exactly ok"
            max_output_tokens = 16
        } | ConvertTo-Json -Depth 4

        Invoke-RestMethod -Method Post -Uri "$trimmedEndpoint/openai/v1/responses" -Headers $headers -Body $body | Out-Null
        $aoaiLiveness = "ok"
    }
    catch {
        $aoaiLiveness = "failed"
    }
}

Write-Host "AOAI liveness: $aoaiLiveness" -ForegroundColor Gray
Write-Host ""
Write-Host "Next steps" -ForegroundColor White
if ($ResourceGroup -and $OpenClawAppName) {
    Write-Host "1. Print tokenized dashboard URL: ./scripts/dashboard-url.ps1 -ResourceGroup $ResourceGroup -AppName $OpenClawAppName" -ForegroundColor Gray
}
else {
    Write-Host "1. Open the control UI with your gateway token." -ForegroundColor Gray
}
Write-Host "2. Pair WhatsApp in Channels login (QR flow)." -ForegroundColor Gray
Write-Host "3. Test a voice note and verify transcription." -ForegroundColor Gray
if ($ResourceGroup -and $OpenClawAppName) {
    Write-Host "4. Tail logs if needed: az containerapp logs show --name $OpenClawAppName --resource-group $ResourceGroup --follow" -ForegroundColor Gray
}
