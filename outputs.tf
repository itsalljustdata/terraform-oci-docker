output "ssh" {
  value       = local.ssh
  description = "SSH access and key configuration grouped as one object."
}

output "vm" {
  value       = local.vm
  description = "VM login and timezone settings grouped as one object."
}

output "storage" {
  value       = local.storage
  description = "Block volume mount settings grouped as one object."
}