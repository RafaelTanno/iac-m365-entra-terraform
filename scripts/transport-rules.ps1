#Requires -Version 7
#Requires -Modules ExchangeOnlineManagement
# Cria/atualiza as regras de transporte do Exchange Online.
# Pre-requisito: Connect-ExchangeOnline com uma conta com permissao de admin do Exchange.
# Idempotente: regra que ja existe (mesmo nome) e atualizada com os parametros abaixo.

$ErrorActionPreference = 'Stop'

$banner = @'
<table border="0" cellpadding="8" style="width:100%;background:#fff4ce;border-left:4px solid #c19c00;">
<tr><td style="font-family:Segoe UI,Arial,sans-serif;font-size:12px;color:#323130;">
<b>E-MAIL EXTERNO</b> - Esta mensagem veio de fora da organizacao. Nao clique em links nem abra anexos sem confirmar o remetente.
</td></tr></table>
'@

$rules = [ordered]@{
    'Aviso de e-mail externo' = @{
        FromScope                          = 'NotInOrganization'
        SentToScope                        = 'InOrganization'
        ApplyHtmlDisclaimerLocation        = 'Prepend'
        ApplyHtmlDisclaimerText            = $banner
        ApplyHtmlDisclaimerFallbackAction  = 'Wrap'
        # evita empilhar o aviso em respostas encadeadas
        ExceptIfSubjectOrBodyContainsWords = 'E-MAIL EXTERNO'
    }
    'Bloquear encaminhamento automatico externo' = @{
        SentToScope             = 'NotInOrganization'
        MessageTypeMatches      = 'AutoForward'
        RejectMessageReasonText = 'Encaminhamento automatico para fora da organizacao nao e permitido.'
    }
}

foreach ($name in $rules.Keys) {
    $params = $rules[$name]
    if (Get-TransportRule -Identity $name -ErrorAction SilentlyContinue) {
        Set-TransportRule -Identity $name @params
        Write-Host "atualizada $name"
    } else {
        New-TransportRule -Name $name @params | Out-Null
        Write-Host "criada     $name"
    }
}
