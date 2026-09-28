# IaC M365 / Entra ID

Parametrização de tenant Microsoft 365 (Entra ID + SharePoint + Exchange) via Terraform + PowerShell, reproduzível a partir de código.

## Escopo

- Grupos de segurança do Entra ID
- Sites de comunicação SharePoint (hub + sites satélite) com tema de marca
- Estrutura de pastas de documentos por cliente, com upload externo via link com verificação OTP
- Regras de transporte no Exchange
- Entra Join para os dispositivos

## Stack

- **Terraform** (provider `azuread`) para os grupos de segurança do Entra ID
- **PowerShell 7 (pwsh) + PnP.PowerShell** para o SharePoint (sites, tema, pastas, compartilhamento externo)
- **PowerShell 7 (pwsh) + ExchangeOnlineManagement** para as regras de transporte do Exchange
- **PowerShell 7 (pwsh) + Microsoft.Graph** para a política de Entra Join

## Estrutura

```
terraform/
  main.tf                  # provider, backend
  entra-groups.tf          # grupos de seguranca
  variables.tf
  outputs.tf               # object IDs dos grupos
  terraform.tfvars.example
scripts/
  provision-sites.ps1      # cria sites de comunicacao + hub
  apply-theme.ps1          # aplica tema de marca
  external-sharing.ps1     # compartilhamento externo com OTP (tenant + sites)
  setup-client-folders.ps1 # estrutura de pastas por cliente + link de upload externo
  transport-rules.ps1      # regras de transporte do Exchange
  entra-join-policy.ps1    # politica de Entra Join dos dispositivos
.env.example
```

## Requisitos

- Terraform 1.5+
- PowerShell 7 (**pwsh**, não o PowerShell 5.1 padrão do Windows — os módulos abaixo não rodam bem na 5.1)
- Módulos instalados no pwsh:

  ```powershell
  Install-Module PnP.PowerShell, ExchangeOnlineManagement, Microsoft.Graph.Authentication -Scope CurrentUser
  ```

### Permissões

| Quem | Precisa de | Para |
|---|---|---|
| Service principal do Terraform | Microsoft Graph `Group.ReadWrite.All` (**aplicativo**, com admin consent) | criar os grupos |
| App registration do PnP | SharePoint `AllSites.FullControl` (**delegada**, com admin consent) + redirect URI `http://localhost` (plataforma *Mobile and desktop*) | `Connect-PnPOnline -Interactive` |
| Conta que roda os scripts do SharePoint | papel **SharePoint Administrator** | sites, hub, tema, compartilhamento externo |
| Conta que roda `transport-rules.ps1` | papel **Exchange Administrator** | regras de transporte |
| Conta que roda `entra-join-policy.ps1` | papel **Global Administrator** ou **Cloud Device Administrator** + consentir `Policy.ReadWrite.DeviceConfiguration` no `Connect-MgGraph` | política de Entra Join |

## Variáveis (não versionar valores reais)

| Variável | Onde é usada | Descrição |
|---|---|---|
| `TENANT_DOMAIN` | scripts PnP | domínio `.onmicrosoft.com`; o prefixo vira o nome do tenant nas URLs do SharePoint |
| `PNP_CLIENT_ID` | scripts PnP | ClientId da app registration do PnP |
| `ARM_TENANT_ID` / `ARM_CLIENT_ID` / `ARM_CLIENT_SECRET` | Terraform (provider `azuread`) | credenciais do service principal do Terraform |

Copie `.env.example` para `.env` e preencha. Nenhuma ferramenta lê o `.env` sozinha, então carregue no shell antes de rodar qualquer coisa. O Terraform também pega as variáveis dessa mesma sessão:

```powershell
Get-Content .env | Where-Object { $_ -match '^\s*[^#].*=' } | ForEach-Object {
    $k, $v = $_ -split '=', 2
    Set-Item "env:$($k.Trim())" $v.Trim()
}
```

```bash
set -a; source .env; set +a
```

## Uso

Rode nesta ordem, na raiz do repo, numa sessão `pwsh` com o `.env` carregado.

### 1. Grupos (Terraform)

```powershell
Copy-Item terraform/terraform.tfvars.example terraform/terraform.tfvars   # ajuste os grupos
terraform -chdir=terraform init
terraform -chdir=terraform plan
terraform -chdir=terraform apply
```

### 2. SharePoint

```powershell
Connect-PnPOnline -Url https://<tenant>-admin.sharepoint.com -ClientId $env:PNP_CLIENT_ID -Interactive
./scripts/provision-sites.ps1
./scripts/apply-theme.ps1
./scripts/external-sharing.ps1 -SiteSlugs <site>
./scripts/setup-client-folders.ps1 -SiteUrl https://<tenant>.sharepoint.com/sites/<site> -Clients "Cliente A","Cliente B"
```

O `external-sharing.ps1` precisa rodar antes de gerar links de upload externo (ver abaixo). O `setup-client-folders.ps1` conecta sozinho no site informado.

### 3. Exchange

```powershell
Connect-ExchangeOnline -UserPrincipalName admin@<tenant>.onmicrosoft.com
./scripts/transport-rules.ps1
```

Regras incluídas:

- **Aviso de e-mail externo**: banner no topo de mensagens vindas de fora da organização
- **Bloquear encaminhamento automático externo**: rejeita auto-forward para destinatários externos

### 4. Entra Join

Depende do grupo `SG-Entra-Join` criado no passo 1:

```powershell
Connect-MgGraph -Scopes Policy.ReadWrite.DeviceConfiguration
$groups = terraform -chdir=terraform output -json security_group_ids | ConvertFrom-Json
./scripts/entra-join-policy.ps1 -JoinGroupIds $groups.'SG-Entra-Join'
```

Padrões: MFA obrigatório para ingressar, até 20 dispositivos por usuário, quem ingressa **não** vira admin local, LAPS habilitado. Se o MFA para ingresso já é exigido por Acesso Condicional, use `-RequireMfa:$false`. O ingresso em si é feito em cada dispositivo: *Configurações > Contas > Acessar trabalho ou escola > Conectar > Ingressar este dispositivo no Microsoft Entra ID*.

## Upload externo com OTP

O `external-sharing.ps1` libera compartilhamento externo só para pessoas específicas, com código de verificação por e-mail. Links "qualquer pessoa" continuam bloqueados, o acesso do convidado expira em 60 dias e o código é pedido de novo a cada 30 (`-GuestExpireDays` / `-ReAuthDays`).

> **Atenção:** ele muda o teto de compartilhamento do tenant inteiro. Sites que hoje usam links "qualquer pessoa" deixam de poder usá-los.

Para gerar o link de upload de cada cliente, passe os e-mails no `setup-client-folders.ps1`. O link vale só para a pasta `Recebidos` daquele cliente:

```powershell
./scripts/setup-client-folders.ps1 -SiteUrl https://<tenant>.sharepoint.com/sites/<site> `
  -Clients "Cliente A" -ClientEmails @{ "Cliente A" = "contato@clientea.com.br" }
```

O script imprime o link. O cliente abre, recebe o código no e-mail e consegue enviar arquivos. O SharePoint não tem permissão "só upload" para pessoas específicas, então o link dá edição, mas apenas nessa pasta. O código por e-mail para convidados depende do provedor *Email one-time passcode* estar ativo no Entra ID (*External Identities > Todos os provedores de identidade*), que já vem ativo por padrão.

## O que personalizar

Os valores abaixo vêm como exemplo. Troque por parâmetro na chamada ou editando o padrão no script:

| O quê | Onde |
|---|---|
| Grupos de segurança | `terraform/terraform.tfvars` |
| Hub e sites satélite (`intranet`, `financeiro`, `juridico`) | `provision-sites.ps1`: `-HubSlug`, `-HubTitle`, `-Sites` |
| Cores do tema (hoje o azul padrão da Microsoft) | `apply-theme.ps1`: `$palette` (gere no Fluent UI Theme Designer) |
| Sites que recebem o tema | `apply-theme.ps1`: `-SiteSlugs` |
| Subpastas por cliente (`Contratos`, `Fiscal`, `Recebidos`) | `setup-client-folders.ps1`: `-Subfolders`, `-UploadFolder` |
| Regras de transporte e texto do banner | `transport-rules.ps1`: `$rules`, `$banner` |
| Política de Entra Join | `entra-join-policy.ps1`: parâmetros do script |

## Armadilhas que já custaram tempo

- **PS 5.1 vs PS 7**: é fácil abrir o terminal azul (PowerShell 5.1) por hábito e rodar os scripts nele — dá erro estranho de módulo. Sempre `pwsh` explicitamente. Os scripts têm `#Requires -Version 7` e param logo de cara na 5.1.
- Grupos do Entra ID criados manualmente antes do Terraform existir geram conflito — se for aplicar num tenant que já tem grupos com os mesmos nomes, usar `terraform import` neles antes do primeiro `apply`.
- App registration do PnP precisa de admin consent explícito no tenant e do redirect URI `http://localhost`; sem isso o `Connect-PnPOnline -Interactive` falha.
- Os scripts do SharePoint que mexem no tenant (hub, tema, compartilhamento) exigem conexão no **admin center** (`<tenant>-admin.sharepoint.com`), não no site raiz.

## Segurança

Este repositório é um template sanitizado — sem Tenant ID, ClientId, Object IDs ou qualquer identificador real de cliente. Preencha suas próprias credenciais localmente via `.env` / `terraform.tfvars`, que estão no `.gitignore` e nunca devem ser commitados.

## Licença

MIT
