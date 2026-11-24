locals {
  sensitive_output_keys = [
    "password",
    "password_hash",
    "private_key",
    "public_key",
    #"private_key_path",
    #"tenancy_ocid",
    #"compartment_ocid",
    #"user_ocid",
    "fingerprint",
    "setup_key",
    "tunnel_token",
    "site_id",
    "site_secret"
  ]
}


output "packages" {
  value       = local.packages
  description = "Installed package information."
}

output "oci" {
  value = merge(
    { for key, value in local.oci : key => value if !contains(local.sensitive_output_keys, lower(key)) },
    { for key in local.sensitive_output_keys : key => "**REDACTED**" if contains(keys(local.oci), key) }
  )
  description = "OCI settings with credential values redacted."
}

output "stack" {
  value       = local.stack
  description = "Logical stack naming and DNS settings."
}

output "network" {
  value       = local.network
  description = "VCN and subnet network settings."
}

output "ssh" {
  value       = local.ssh
  description = "SSH access and key configuration grouped as one object."
}

output "vm" {
  value = merge(
    { for key, value in local.vm : key => value if !contains(local.sensitive_output_keys, lower(key)) },
    { for key in local.sensitive_output_keys : key => "**REDACTED**" if contains(keys(local.vm), key) }
  )
  description = "VM settings with password credentials redacted."
}

output "storage" {
  value       = local.storage
  description = "Block-volume mount configuration."
}

output "netbird" {
  value = merge(
    { for key, value in local.netbird : key => value if !contains(local.sensitive_output_keys, lower(key)) },
    { for key in local.sensitive_output_keys : key => "**REDACTED**" if contains(keys(local.netbird), key) }
  )
  description = "NetBird settings with setup-key credentials redacted."
}

output "docker" {
  value       = local.docker
  description = "Docker installation settings."
}

output "cloudflared" {
  value = merge(
    { for key, value in local.cloudflared : key => value if !contains(local.sensitive_output_keys, lower(key)) },
    { for key in local.sensitive_output_keys : key => "**REDACTED**" if contains(keys(local.cloudflared), key) }
  )
  description = "Cloudflared settings with tunnel tokens redacted."
}

output "warp" {
  value = merge(
    { for key, value in local.warp : key => value if !contains(local.sensitive_output_keys, lower(key)) },
    { for key in local.sensitive_output_keys : key => "**REDACTED**" if contains(keys(local.warp), key) }
  )
  description = "Warp settings with tunnel tokens redacted."
}

output "pangolin" {
  value = merge(
    { for key, value in local.pangolin : key => value if !contains(local.sensitive_output_keys, lower(key)) },
    { for key in local.sensitive_output_keys : key => "**REDACTED**" if contains(keys(local.pangolin), key) }
  )
  description = "Pangolin settings with site secrets redacted."
}

output "git" {
  value = merge(
    { for key, value in local.git : key => value if !contains(local.sensitive_output_keys, lower(key)) },
    { for key in local.sensitive_output_keys : key => "**REDACTED**" if contains(keys(local.git), key) }
  )
  description = "Git settings with sensitive credentials redacted."
}

output "dns" {
  value       = local.dns
  description = "Derived VCN, subnet, search-domain, and public-name settings."
}

output "resource_names" {
  value       = local.resource_names
  description = "Terraform-managed OCI and network resource names."
}

output "vm_ssh_config_destinations" {
  value       = local.vm_ssh_config_destinations
  description = "Local paths for generated VM SSH configuration."
}

