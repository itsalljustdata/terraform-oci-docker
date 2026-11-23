output "ssh" {
  value       = local.ssh
  description = "SSH access and key configuration grouped as one object."
}

output "vm" {
  value = {
    for key, value in local.vm : key => value
    if !contains(["password_hash"], key)
  }
  description = "VM settings grouped as an object."
}
