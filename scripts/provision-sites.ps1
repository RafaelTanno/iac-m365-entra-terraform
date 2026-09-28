#Requires -Version 7
#Requires -Modules PnP.PowerShell
# Cria o hub e os sites de comunicacao satelite, associando-os ao hub.
# Pre-requisito: Connect-PnPOnline no admin center (https://<tenant>-admin.sharepoint.com).
# Idempotente: sites/hub que ja existem sao mantidos.

param(
    [string]$Tenant = ($env:TENANT_DOMAIN -split '\.')[0],
    [string]$HubSlug = 'intranet',
    [string]$HubTitle = 'Intranet',
    # slug da URL => titulo do site
    [hashtable]$Sites = @{ financeiro = 'Financeiro'; juridico = 'Juridico' }
)

$ErrorActionPreference = 'Stop'
if (-not $Tenant) { throw 'Informe -Tenant ou defina TENANT_DOMAIN.' }

$base = "https://$Tenant.sharepoint.com/sites"

function Confirm-Site([string]$Url, [string]$Title) {
    if (Get-PnPTenantSite -Identity $Url -ErrorAction SilentlyContinue) {
        Write-Host "ok     $Url"
    } else {
        New-PnPSite -Type CommunicationSite -Title $Title -Url $Url -Wait | Out-Null
        Write-Host "criado $Url"
    }
}

$hubUrl = "$base/$HubSlug"
Confirm-Site $hubUrl $HubTitle
if (-not (Get-PnPHubSite -Identity $hubUrl -ErrorAction SilentlyContinue)) {
    Register-PnPHubSite -Site $hubUrl | Out-Null
    Write-Host "hub    $hubUrl"
}

foreach ($slug in $Sites.Keys) {
    $url = "$base/$slug"
    Confirm-Site $url $Sites[$slug]
    Add-PnPHubSiteAssociation -Site $url -HubSite $hubUrl
}
