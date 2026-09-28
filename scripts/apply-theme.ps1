#Requires -Version 7
#Requires -Modules PnP.PowerShell
# Registra o tema de marca no tenant e aplica nos sites informados.
# Pre-requisito: Connect-PnPOnline no admin center (https://<tenant>-admin.sharepoint.com).

param(
    [string]$Tenant = ($env:TENANT_DOMAIN -split '\.')[0],
    [string]$ThemeName = 'Marca',
    [string[]]$SiteSlugs = @('intranet', 'financeiro', 'juridico')
)

$ErrorActionPreference = 'Stop'
if (-not $Tenant) { throw 'Informe -Tenant ou defina TENANT_DOMAIN.' }

# Paleta padrao (azul Fluent) como placeholder: gere a da marca no Fluent UI Theme Designer e cole aqui.
$palette = @{
    themePrimary         = '#0078d4'
    themeLighterAlt      = '#eff6fc'
    themeLighter         = '#deecf9'
    themeLight           = '#c7e0f4'
    themeTertiary        = '#71afe5'
    themeSecondary       = '#2b88d8'
    themeDarkAlt         = '#106ebe'
    themeDark            = '#005a9e'
    themeDarker          = '#004578'
    neutralLighterAlt    = '#faf9f8'
    neutralLighter       = '#f3f2f1'
    neutralLight         = '#edebe9'
    neutralQuaternaryAlt = '#e1dfdd'
    neutralQuaternary    = '#d0d0d0'
    neutralTertiaryAlt   = '#c8c6c4'
    neutralTertiary      = '#a19f9d'
    neutralSecondary     = '#605e5c'
    neutralPrimaryAlt    = '#3b3a39'
    neutralPrimary       = '#323130'
    neutralDark          = '#201f1e'
    black                = '#000000'
    white                = '#ffffff'
}

Add-PnPTenantTheme -Identity $ThemeName -Palette $palette -IsInverted $false -Overwrite

foreach ($slug in $SiteSlugs) {
    $url = "https://$Tenant.sharepoint.com/sites/$slug"
    Set-PnPWebTheme -Theme $ThemeName -WebUrl $url
    Write-Host "tema   $url"
}
