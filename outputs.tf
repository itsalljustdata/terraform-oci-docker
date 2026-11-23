output "oci" {
  value       = local.oci
  description = "OCI authentication, compartment, and region settings grouped as one object."
}

output "stack" {
  value       = local.stack
  description = "Stack naming and DNS metadata grouped as one object."
}

output "network" {
  value       = local.network
  description = "Network CIDR settings grouped as one object."
}

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

output "stack_name" {
  value       = local.stack_name
  description = "The resolved stack name built from the stack prefix and optional override."
}

output "resource_display_names" {
  value       = local.resource_names
  description = "The final generated display names for the main OCI resources in this stack."
}

output "dns" {
  value       = local.dns
  description = "The generated DNS values for the VCN, subnet, search domain, and public hostname."
}

output "public_ips" {
  value = {
    vm = local.public_IPv4
  }
  description = "Public IPs exposed by the stack. The VM is the only public endpoint in this model."
}

output "instance_direct_public_ip" {
  value       = local.public_IPv4
  description = "The public IP assigned to the VM. If a reserved IP is enabled, this value reflects it; otherwise it falls back to the instance public IP."
}

output "ssh_connection_string" {
  value       = "ssh ${local.vm.user}@${local.public_IPv4} -p ${local.ssh.public_port}"
  description = "Copy and paste this terminal command to log straight into the VM over the active public IP path."
}

output "powershell_connectivity_checks" {
  value = join("\n", [
    "# to VM",
    "Test-NetConnection -ComputerName ${local.public_IPv4} -Port ${local.ssh.public_port} -InformationLevel Detailed"
  ])
  description = "PowerShell command to test direct VM access over the active public IP path."
}
output "image_ocid" {
  value       = local.vm.image_ocid
  description = "The OCID of the image used for the VM."
}