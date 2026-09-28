#Requires -Version 7
#Requires -Modules PnP.PowerShell
# Libera compartilhamento externo com verificacao por codigo (OTP) no tenant e nos sites informados.
# "Anyone links" (sem verificacao) continuam bloqueados: convidado so entra com codigo enviado ao e-mail.
# Pre-requisito: Connect-PnPOnline no admin center (https://<tenant>-admin.sharepoint.com).

param(
    [string]$Tenant = ($env:TENANT_DOMAIN -split '\.')[0],
    # sites que recebem upload externo de clientes
    [Parameter(Mandatory)][string[]]$SiteSlugs,
    # acesso do convidado expira apos N dias
    [int]$GuestExpireDays = 60,
    # convidado reverifica o codigo a cada N dias
    [int]$ReAuthDays = 30
)

$ErrorActionPreference = 'Stop'
if (-not $Tenant) { throw 'Informe -Tenant ou defina TENANT_DOMAIN.' }

# Teto do tenant: convidados novos e existentes, sem links anonimos.
# Nao altera o nivel dos outros sites alem desse teto.
Set-PnPTenant -SharingCapability ExternalUserSharingOnly `
    -EmailAttestationRequired $true -EmailAttestationReAuthDays $ReAuthDays `
    -ExternalUserExpirationRequired $true -ExternalUserExpireInDays $GuestExpireDays
Write-Host "tenant compartilhamento externo com OTP (expira em $GuestExpireDays dias)"

foreach ($slug in $SiteSlugs) {
    $url = "https://$Tenant.sharepoint.com/sites/$slug"
    Set-PnPTenantSite -Identity $url -SharingCapability ExternalUserSharingOnly
    Write-Host "site   $url"
}
