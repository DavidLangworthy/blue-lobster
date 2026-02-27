# Print a tokenized OpenClaw Control UI URL for zero-click browser login.
[CmdletBinding()]
param(
    [string]$ResourceGroup = $env:AZURE_RESOURCE_GROUP,
    [string]$AppName = $(if ($env:OPENCLAW_APP_NAME) { $env:OPENCLAW_APP_NAME } elseif ($env:CLAWDBOT_APP_NAME) { $env:CLAWDBOT_APP_NAME } else { "openclaw" }),
    [switch]$Open
)

$ErrorActionPreference = "Stop"

if (-not $ResourceGroup) {
    Write-Error "Resource group is required (set AZURE_RESOURCE_GROUP or pass -ResourceGroup)."
    exit 1
}

$fqdn = az containerapp show `
    --resource-group $ResourceGroup `
    --name $AppName `
    --query "properties.configuration.ingress.fqdn" `
    --output tsv

if (-not $fqdn) {
    Write-Error "Failed to resolve FQDN for container app '$AppName' in '$ResourceGroup'."
    exit 1
}

$gatewayToken = az containerapp secret list `
    --resource-group $ResourceGroup `
    --name $AppName `
    --show-values `
    --query "[?name=='gateway-token'].value | [0]" `
    --output tsv

if (-not $gatewayToken -or $gatewayToken -eq "not-set") {
    Write-Error "Gateway token is missing. Set OPENCLAW_GATEWAY_TOKEN and redeploy."
    exit 1
}

$url = "https://$fqdn/#token=$gatewayToken"
Write-Output $url

if ($Open) {
    Start-Process $url | Out-Null
}
