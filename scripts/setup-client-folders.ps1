#Requires -Version 7
#Requires -Modules PnP.PowerShell
# Cria a estrutura de pastas por cliente numa biblioteca de documentos.
# Conecta sozinho no site alvo usando PNP_CLIENT_ID. Idempotente.

param(
    [Parameter(Mandatory)][string]$SiteUrl,
    [Parameter(Mandatory)][string[]]$Clients,
    # URL interna da biblioteca (continua "Shared Documents" mesmo com o nome exibido em portugues)
    [string]$Library = 'Shared Documents',
    [string[]]$Subfolders = @('Contratos', 'Fiscal', 'Recebidos')
)

$ErrorActionPreference = 'Stop'
if (-not $env:PNP_CLIENT_ID) { throw 'Defina PNP_CLIENT_ID.' }

Connect-PnPOnline -Url $SiteUrl -ClientId $env:PNP_CLIENT_ID -Interactive

foreach ($client in $Clients) {
    foreach ($sub in $Subfolders) {
        Resolve-PnPFolder -SiteRelativePath "$Library/$client/$sub" | Out-Null
    }
    Write-Host "ok     $client"
}
