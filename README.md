# IaC M365 / Entra ID

Parametrização de tenant Microsoft 365 (Entra ID + SharePoint) via Terraform + PowerShell (PnP), reproduzível a partir de código.

## Escopo

- Grupos de segurança do Entra ID
- Sites de comunicação SharePoint (hub + sites satélite) com tema de marca
- Estrutura de pastas de documentos por cliente, com upload externo via link com verificação OTP
- Regras de transporte no Exchange
- Entra Join para os dispositivos

## Stack

- **Terraform** (provider `azuread` / `azurerm`) para grupos do Entra ID e recursos base
- **PowerShell 7 (pwsh) + PnP.PowerShell** para provisionamento do SharePoint (sites, temas, bibliotecas)
- **PowerShell 7 (pwsh) + ExchangeOnlineManagement** para regras de transporte do Exchange

## Estrutura

```
terraform/
  main.tf            # providers, backend
  entra-groups.tf    # grupos de seguranca
  variables.tf
  outputs.tf
scripts/
  provision-sites.ps1     # cria sites de comunicacao + hub
  apply-theme.ps1          # aplica tema de marca
  setup-client-folders.ps1 # estrutura de pastas por cliente
  transport-rules.ps1      # regras de transporte do Exchange
```

## Requisitos

- Terraform 1.x
- PowerShell 7 (**pwsh**, não o PowerShell 5.1 padrão do Windows — o PnP.PowerShell não roda bem na 5.1)
- Módulos `PnP.PowerShell` e `ExchangeOnlineManagement` instalados
- App registration no Entra ID com permissões de Sites.FullControl.All / Group.ReadWrite.All (delegadas ou app-only conforme o fluxo de auth escolhido)

## Variáveis (não versionar valores reais)

| Variável | Onde é usada | Descrição |
|---|---|---|
| `TENANT_ID` | Terraform + PnP | Tenant ID do Entra ID |
| `TENANT_DOMAIN` | Terraform + PnP | domínio `.onmicrosoft.com` |
| `PNP_CLIENT_ID` | PnP.PowerShell | ClientId da app registration usada para conectar |
| `ARM_CLIENT_ID` / `ARM_CLIENT_SECRET` / `ARM_TENANT_ID` / `ARM_SUBSCRIPTION_ID` | Terraform (provider azurerm/azuread) | credenciais do service principal do Terraform |

Um `.tfvars` de exemplo (`terraform.tfvars.example`) e um `.env.example` para os scripts PowerShell ficam no repo — nunca commitar os arquivos reais preenchidos.

## Uso

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

```powershell
pwsh
Connect-PnPOnline -Url https://<tenant>-admin.sharepoint.com -ClientId $env:PNP_CLIENT_ID -Interactive
./scripts/provision-sites.ps1
./scripts/apply-theme.ps1
./scripts/setup-client-folders.ps1 -SiteUrl https://<tenant>.sharepoint.com/sites/<site> -Clients "Cliente A","Cliente B"

Connect-ExchangeOnline -UserPrincipalName admin@<tenant>.onmicrosoft.com
./scripts/transport-rules.ps1
```

Regras de transporte incluídas:

- **Aviso de e-mail externo**: banner no topo de mensagens vindas de fora da organização
- **Bloquear encaminhamento automático externo**: rejeita auto-forward para destinatários externos

## Armadilhas que já custaram tempo

- **PS 5.1 vs PS 7**: é fácil abrir o terminal azul (PowerShell 5.1) por hábito e rodar os scripts do PnP nele — dá erro estranho de módulo. Sempre `pwsh` explicitamente.
- Grupos do Entra ID criados manualmente antes do Terraform existir geram conflito de import — se for aplicar num tenant que já tem grupos, usar `terraform import` neles antes do primeiro `apply`.
- App registration do PnP precisa de admin consent explícito no tenant antes do primeiro `Connect-PnPOnline` funcionar sem prompt de erro.

## Segurança

Este repositório é um template sanitizado — sem Tenant ID, ClientId, Object IDs ou qualquer identificador real de cliente. Preencha suas próprias credenciais localmente via variáveis de ambiente / `.tfvars`, nunca commitadas.

## Licença

MIT
