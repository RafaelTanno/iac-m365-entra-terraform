resource "azuread_group" "security" {
  for_each = var.security_groups

  display_name            = each.key
  description             = each.value.description
  security_enabled        = true
  prevent_duplicate_names = true
}
