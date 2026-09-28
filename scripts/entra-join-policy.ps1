#Requires -Version 7
#Requires -Modules Microsoft.Graph.Authentication
# Configura a politica de Entra Join do tenant (quem pode ingressar dispositivos, MFA, admin local, LAPS).
# Pre-requisito: Connect-MgGraph -Scopes Policy.ReadWrite.DeviceConfiguration
# O ingresso em si e feito no dispositivo (Configuracoes > Contas > Acessar trabalho ou escola).

param(
    # Object IDs dos grupos autorizados a ingressar dispositivos (ex.: output do Terraform).
    # Vazio = todos os usuarios.
    [string[]]$JoinGroupIds = @(),
    [int]$UserDeviceQuota = 20,
    # Se o MFA para ingresso ja e exigido por Acesso Condicional, use -RequireMfa:$false
    [bool]$RequireMfa = $true,
    # true = quem ingressa vira admin local do dispositivo
    [bool]$JoiningUserIsLocalAdmin = $false,
    [bool]$EnableLaps = $true
)

$ErrorActionPreference = 'Stop'

# Endpoint so existe em beta. GET + PUT para preservar os campos que nao mexemos.
$uri = 'https://graph.microsoft.com/beta/policies/deviceRegistrationPolicy'
$policy = Invoke-MgGraphRequest -Method GET -Uri $uri
$policy.Remove('@odata.context')

$policy.userDeviceQuota = $UserDeviceQuota
$policy.multiFactorAuthConfiguration = if ($RequireMfa) { 'required' } else { 'notRequired' }

$policy.azureADJoin.allowedToJoin = if ($JoinGroupIds) {
    @{ '@odata.type' = '#microsoft.graph.enumeratedDeviceRegistrationMembership'; users = @(); groups = @($JoinGroupIds) }
} else {
    @{ '@odata.type' = '#microsoft.graph.allDeviceRegistrationMembership' }
}

$policy.azureADJoin.localAdmins.registeringUsers = if ($JoiningUserIsLocalAdmin) {
    @{ '@odata.type' = '#microsoft.graph.allDeviceRegistrationMembership' }
} else {
    @{ '@odata.type' = '#microsoft.graph.noDeviceRegistrationMembership' }
}

$policy.localAdminPassword = @{ isEnabled = $EnableLaps }

Invoke-MgGraphRequest -Method PUT -Uri $uri -Body ($policy | ConvertTo-Json -Depth 10) -ContentType 'application/json' | Out-Null
Write-Host "politica de Entra Join atualizada (grupos: $(if ($JoinGroupIds) { $JoinGroupIds -join ', ' } else { 'todos' }))"
