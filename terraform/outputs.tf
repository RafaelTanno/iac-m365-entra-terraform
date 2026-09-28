output "security_group_ids" {
  description = "Object IDs dos grupos criados, por nome."
  value       = { for name, g in azuread_group.security : name => g.object_id }
}
