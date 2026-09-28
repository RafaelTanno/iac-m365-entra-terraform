terraform {
  required_version = ">= 1.5"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }

  # Backend local por padrao. Para estado compartilhado, trocar por backend "azurerm".
}

# Credenciais via ARM_TENANT_ID / ARM_CLIENT_ID / ARM_CLIENT_SECRET (ver .env.example)
provider "azuread" {}
