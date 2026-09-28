variable "security_groups" {
  description = "Grupos de seguranca do Entra ID, indexados pelo nome de exibicao."
  type = map(object({
    description = string
  }))
}
