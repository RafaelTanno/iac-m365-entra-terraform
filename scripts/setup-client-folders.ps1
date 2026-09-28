#Requires -Version 7
#Requires -Modules PnP.PowerShell
# Cria a estrutura de pastas por cliente numa biblioteca de documentos e, opcionalmente,
# gera um link de upload externo (pessoas especificas + codigo de verificacao por e-mail/OTP)
# so para a pasta de recebidos de cada cliente.
# Conecta sozinho no site alvo usando PNP_CLIENT_ID. Idempotente.
# O site precisa permitir compartilhamento externo: rode antes o external-sharing.ps1.

param(
    [Parameter(Mandatory)][string]$SiteUrl,
    [Parameter(Mandatory)][string[]]$Clients,
    # URL interna da biblioteca (continua "Shared Documents" mesmo com o nome exibido em portugues)
    [string]$Library = 'Shared Documents',
    [string[]]$Subfolders = @('Contratos', 'Fiscal', 'Recebidos'),
    # cliente => e-mail(s) externos que recebem o link de upload. Cliente fora da lista nao recebe link.
    [hashtable]$ClientEmails = @{},
    [string]$UploadFolder = 'Recebidos'
)

$ErrorActionPreference = 'Stop'
if (-not $env:PNP_CLIENT_ID) { throw 'Defina PNP_CLIENT_ID.' }

Connect-PnPOnline -Url $SiteUrl -ClientId $env:PNP_CLIENT_ID -Interactive

foreach ($client in $Clients) {
    foreach ($sub in $Subfolders) {
        Resolve-PnPFolder -SiteRelativePath "$Library/$client/$sub" | Out-Null
    }
    Write-Host "ok     $client"

    if ($ClientEmails[$client]) {
        # Edicao e o minimo que permite upload; o link vale so para esta subpasta.
        $folder = Resolve-PnPFolder -SiteRelativePath "$Library/$client/$UploadFolder"
        $link = Add-PnPFolderUserSharingLink -Folder $folder -ShareType Edit -Users @($ClientEmails[$client])
        Write-Host "link   $client -> $($link.Link.WebUrl)"
    }
}
