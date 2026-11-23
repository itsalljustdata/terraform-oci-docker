terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 9.13.0"
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.4.2"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.9.1"
    }
  }
}

provider "oci" {
  tenancy_ocid     = local.oci.tenancy_ocid
  user_ocid        = local.oci.user_ocid
  fingerprint      = local.oci.fingerprint
  private_key_path = pathexpand(local.oci.private_key_path)
  region           = local.oci.region
}

data "oci_identity_compartments" "stack_compartment_lookup" {
  compartment_id = local.oci.tenancy_ocid

  filter {
    name   = "name"
    values = [local.resource_names.compartment]
  }
}

resource "oci_identity_compartment" "stack_compartment" {
  count = length(data.oci_identity_compartments.stack_compartment_lookup.compartments) == 0 ? 1 : 0

  compartment_id = local.oci.tenancy_ocid
  name           = local.resource_names.compartment
  description    = "Terraform-managed compartment for ${local.resource_names.compartment}"
  enable_delete  = false
}

locals {
  vm_ssh_config_rendered = templatefile("${path.module}/templates/config_ssh.tftpl", {
    ssh_aliases      = local.ssh_aliases
    ssh_aliases_ipv6 = local.ssh_aliases_ipv6
    ssh_user         = local.vm.user
    ssh_log_level    = local.ssh.ssh_log_level
    public_IPv4      = local.public_IPv4
    public_IPv6      = local.public_IPv6
    ssh_port         = local.ssh.public_port
    git              = local.git
  })

  vm_ssh_config_destinations = {
    user_config = pathexpand("~/.ssh/config.d/${local.resource_names.hostname_label}")
    output_file = "${path.module}/output/${local.this_vm_name}/ssh-config"
  }

  cloud_init_files = {
    "mount-block-volumes.sh" = {
      content          = templatefile("${path.module}/templates/mount-block-volumes.sh.tftpl", {
        mount_entries = local.storage.block_vol_mounts
        vm_name       = local.this_vm_name
      })
    }
    "configure-ssh.sh" = {
      content          = templatefile("${path.module}/templates/configure-ssh.sh.tftpl", {
        ssh_public_port = local.ssh.public_port
        vm_user         = local.vm.user
        ssh_public_keys = local.ssh_public_keys_content
      })
      runcmd_order   = 10
    }
    "configure-firewall.sh" = {
      content          = templatefile("${path.module}/templates/configure-firewall.sh.tftpl", {
        ssh_public_port = local.ssh.public_port
      })
      runcmd_order   = 20
    }
    "wait-for-block-volume.sh" = {
      content          = templatefile("${path.module}/templates/wait-for-block-volume.sh.tftpl", {})
      name  = "wait-for-block-volume.sh"
    }
    "block-volume-mount.service" = {
      path             = "/etc/systemd/system"
      permissions      = "0644"
      content          = templatefile("${path.module}/templates/block-volume-mount.service.tftpl", {})
    }
    "enable-block-volume-service.sh" = {
      content          = templatefile("${path.module}/templates/enable-block-volume-service.sh.tftpl", {})
      runcmd_order   = 30
    }
    "netbird-setup.sh" = {
      content          = templatefile("${path.module}/templates/netbird-setup.sh.tftpl", {
        enabled     = local.netbird.enabled
        extra_flags = join(" ", concat(local.netbird.setup_key != "" ? ["--setup-key", local.netbird.setup_key] : [], coalesce(local.netbird.extra_flags, []), local.netbird.management_url != "" ? ["--management-url", local.netbird.management_url] : []))
      })
      runcmd_order   = 40
    }
    "pangolin-setup.sh" = {
      content          = templatefile("${path.module}/templates/pangolin-setup.sh.tftpl", {
        enabled     = local.pangolin.enabled
        site_id     = local.pangolin.site_id
        site_secret = local.pangolin.site_secret
        endpoint    = local.pangolin.endpoint
      })
      runcmd_order   = 50
    }
    "configure-cloudflared.sh" = {
      content          = templatefile("${path.module}/templates/cloudflared-setup.sh.tftpl", {
        enabled      = local.cloudflared.enabled
        tunnel_token = local.cloudflared.tunnel_token
      })
      runcmd_order   = 60
      name  = "cloudflared-setup.sh"
    }
    "cloudflare-warp-setup.sh" = {
      content          = templatefile("${path.module}/templates/cloudflare-warp-setup.sh.tftpl", {
        enabled      = local.warp.enabled
        tunnel_token = local.warp.tunnel_token
      })
      runcmd_order   = 70
    }
    "docker-install.sh" = {
      content          = templatefile("${path.module}/templates/docker-install.sh.tftpl", {
        enabled = local.docker.enabled
        vm_user = local.vm.user
      })
      runcmd_order   = 80
    }
  }

  runcmd_files = sort([
    for name, file in local.cloud_init_files :
    format("%010d:%s", file.runcmd_order, name)
    if try(file.runcmd_order, null) != null
  ])

  runcmd_files_sorted = [
    for item in local.runcmd_files :
    split(":", item)[1]
  ]

  cloud_init_rendered = templatefile("${path.module}/templates/cloud-config.yaml.tftpl", {
    packages          = local.packages
    cloud_init_files  = local.cloud_init_files
    runcmd_files      = local.runcmd_files_sorted
    theUsers          = [local.vm.user, "root"]
    vm_timezone       = local.vm.timezone
    vm_password_hash  = module.sha512_password.hash
    vm_ssh_authorized_keys = local.ssh_public_keys_content
    git               = local.git
  })

  vm_output_files = merge(
    {
      for name, file in local.cloud_init_files :
      name => {
        content         = file.content
        filename        = "${path.module}/output/${local.this_vm_name}/${coalesce(try(file.name, null), name)}"
        file_permission = coalesce(try(file.permissions, null), "0755")
      }
    },
    {
      "cloud-config.yaml" = {
        content         = local.cloud_init_rendered
        filename        = "${path.module}/output/${local.this_vm_name}/cloud-config.yaml"
        file_permission = "0644"
      }
      "TestConnect.ps1" = {
        content = templatefile("${path.module}/templates/TestConnect.ps1.tftpl", {
          vm_name  = local.this_vm_name
          publicIP = [local.public_IPv4, local.public_IPv6]
          ssh_port = local.ssh.public_port
        })
        filename        = "${path.module}/output/${local.this_vm_name}/TestConnect.ps1"
        file_permission = "0644"
      }
    },
    {
      for destination_name, destination_filename in local.vm_ssh_config_destinations :
      "ssh-config-${destination_name}" => {
        content         = local.vm_ssh_config_rendered
        filename        = destination_filename
        file_permission = "0644"
      }
    }
  )

  query = {
    yaml = local.cloud_init_rendered
  }



}

## ==========================================
## 1. CORE NETWORKING LAYER
## ==========================================

resource "oci_core_vcn" "stack_vcn" {
  cidr_blocks    = local.network.vcn_cidr_blocks
  compartment_id = local.compartment_id
  display_name   = local.resource_names.vcn
  dns_label      = local.dns.vcn_label
  is_ipv6enabled = local.network.ipv6_enabled
  defined_tags = {
    "git.commit"     = local.git.commit
    "git.remote_url" = local.git.remote_url
    "git.source"     = local.git.source
    "git.is_dirty"   = local.git.is_dirty
  }
}

resource "oci_core_internet_gateway" "internet_gateway" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.stack_vcn.id
  display_name   = local.resource_names.internet_gateway
  enabled        = true
  defined_tags = {
    "git.commit"     = local.git.commit
    "git.remote_url" = local.git.remote_url
    "git.source"     = local.git.source
    "git.is_dirty"   = local.git.is_dirty
  }
}

resource "oci_core_default_route_table" "default_route_table" {
  compartment_id             = local.compartment_id
  manage_default_resource_id = oci_core_vcn.stack_vcn.default_route_table_id
  display_name               = local.resource_names.route_table

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.internet_gateway.id
    route_type        = "STATIC"
  }

  dynamic "route_rules" {
    for_each = local.network.ipv6_enabled ? [1] : []
    content {
      destination       = "::/0"
      destination_type  = "CIDR_BLOCK"
      network_entity_id = oci_core_internet_gateway.internet_gateway.id
      route_type        = "STATIC"
    }
  }
}

resource "oci_core_default_dhcp_options" "default_dhcp" {
  compartment_id             = local.compartment_id
  manage_default_resource_id = oci_core_vcn.stack_vcn.default_dhcp_options_id
  display_name               = local.resource_names.dhcp_options
  domain_name_type           = "CUSTOM_DOMAIN"

  options {
    server_type = "VcnLocalPlusInternet"
    type        = "DomainNameServer"
  }

  options {
    search_domain_names = [local.dns.search_domain]
    type                = "SearchDomain"
  }
}

## ==========================================
## 2. SECURITY LIST RULES
## ==========================================

resource "oci_core_default_security_list" "security_list" {
  compartment_id             = local.compartment_id
  manage_default_resource_id = oci_core_vcn.stack_vcn.default_security_list_id
  display_name               = local.resource_names.security_list

  egress_security_rules {
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
    stateless        = false
  }

  dynamic "egress_security_rules" {
    for_each = local.network.ipv6_enabled ? [1] : []
    content {
      destination      = "::/0"
      destination_type = "CIDR_BLOCK"
      protocol         = "all"
      stateless        = false
    }
  }

  dynamic "ingress_security_rules" {
    for_each = length(local.network.vcn_cidr_blocks) > 0 ? local.network.vcn_cidr_blocks : []
    content {
      description = "Allow SSH from inside the VCN on the standard port"
      protocol    = "6"
      source      = ingress_security_rules.value
      source_type = "CIDR_BLOCK"
      stateless   = false
      tcp_options {
        max = 22
        min = 22
      }
    }
  }

  dynamic "ingress_security_rules" {
    for_each = length(local.ssh.ssh_allowed_ipv4_cidrs) > 0 ? local.ssh.ssh_allowed_ipv4_cidrs : []
    content {
      description = "Allow SSH from the configured external CIDR range on the public SSH port only"
      protocol    = "6"
      source      = ingress_security_rules.value
      source_type = "CIDR_BLOCK"
      stateless   = false
      tcp_options {
        max = local.ssh.public_port
        min = local.ssh.public_port
      }
    }
  }

  dynamic "ingress_security_rules" {
    for_each = local.network.ipv6_enabled ? local.ssh.ssh_allowed_ipv6_cidrs : []
    content {
      description = "Allow IPv6 SSH from the configured external CIDR range on the public SSH port"
      protocol    = "6"
      source      = ingress_security_rules.value
      source_type = "CIDR_BLOCK"
      stateless   = false
      tcp_options {
        max = local.ssh.public_port
        min = local.ssh.public_port
      }
    }
  }

  dynamic "ingress_security_rules" {
    for_each = local.network.ipv6_enabled ? [1] : []
    content {
      description = "Allow ICMPv6"
      protocol    = "58"
      source      = "::/0"
      source_type = "CIDR_BLOCK"
      stateless   = false
    }
  }

  ingress_security_rules {
    protocol    = "1"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = false
    icmp_options {
      type = 3
      code = 4
    }
  }
}

resource "oci_core_subnet" "public_subnet" {
  cidr_block        = local.network.subnet_cidr_block
  compartment_id    = local.compartment_id
  vcn_id            = oci_core_vcn.stack_vcn.id
  display_name      = local.resource_names.subnet
  dns_label         = local.dns.subnet_label
  route_table_id    = oci_core_default_route_table.default_route_table.id
  security_list_ids = [oci_core_default_security_list.security_list.id]
  ipv6cidr_block = local.network.ipv6_enabled ? cidrsubnet(
    oci_core_vcn.stack_vcn.ipv6cidr_blocks[0],
    8,
    0
  ) : null
  defined_tags = {
    "git.commit"     = local.git.commit
    "git.remote_url" = local.git.remote_url
    "git.source"     = local.git.source
    "git.is_dirty"   = local.git.is_dirty
  }
}

resource "oci_core_volume_attachment" "block_volume_attachments" {
  for_each = { for mount in local.storage.block_vol_mounts : mount.path => mount }

  attachment_type                   = "iscsi"
  instance_id                       = oci_core_instance.compute_instance.id
  volume_id                         = each.value.ocid
  is_agent_auto_iscsi_login_enabled = true
}

data "oci_core_vnic_attachments" "vm_vnic_attachments" {
  count          = 1
  compartment_id = local.compartment_id
  instance_id    = oci_core_instance.compute_instance.id
}

data "oci_core_private_ips" "vm_private_ip" {
  count   = 1
  vnic_id = data.oci_core_vnic_attachments.vm_vnic_attachments[0].vnic_attachments[0].vnic_id
}

resource "oci_core_public_ip" "vm_reserved_ip" {
  count          = local.vm.create_reserved_ip ? 1 : 0
  compartment_id = local.compartment_id
  display_name   = local.resource_names.vm_ip
  lifetime       = "RESERVED"
  private_ip_id  = data.oci_core_private_ips.vm_private_ip[0].private_ips[0].id

  defined_tags = {
    "git.commit"     = local.git.commit
    "git.remote_url" = local.git.remote_url
    "git.source"     = local.git.source
    "git.is_dirty"   = local.git.is_dirty
  }
}

## ==========================================
## 4. COMPUTE INSTANCE DEFINITION
## ==========================================

resource "oci_core_instance" "compute_instance" {
  compartment_id      = local.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = local.resource_names.vm_instance
  shape               = local.vm.shape
  defined_tags = {
    "git.commit"     = local.git.commit
    "git.remote_url" = local.git.remote_url
    "git.source"     = local.git.source
    "git.is_dirty"   = local.git.is_dirty
  }

  create_vnic_details {
    # OCI does not allow a single private IP to have both an auto-assigned public IP
    # and a separate reserved public IP. When using oci_core_public_ip.vm_reserved_ip,
    # leave the VNIC without an ephemeral public IP to avoid 409 conflicts.
    assign_ipv6ip          = local.network.ipv6_enabled
    assign_public_ip       = !local.vm.create_reserved_ip
    display_name           = local.resource_names.primary_vnic
    hostname_label         = local.resource_names.hostname_label
    subnet_id              = oci_core_subnet.public_subnet.id
    skip_source_dest_check = true
  }

  dynamic "shape_config" {
    for_each = strcontains(local.vm.shape, ".Flex") ? [1] : []

    content {
      ocpus         = local.vm.shape_config.ocpus
      memory_in_gbs = local.vm.shape_config.memory_in_gbs
    }
  }

  source_details {
    source_type             = "image"
    source_id               = local.vm.image_ocid
    boot_volume_vpus_per_gb = 10
  }

  metadata = {
    git_commit          = local.git.commit
    git_remote          = local.git.remote_url
    git_source          = local.git.source
    git_dirty           = local.git.is_dirty
  }

  agent_config {
    are_all_plugins_disabled = false
    is_management_disabled   = false
    is_monitoring_disabled   = false

    plugins_config {
      name          = "Block Volume Management"
      desired_state = "ENABLED"
    }
    plugins_config {
      name          = "Custom Logs Monitoring"
      desired_state = "ENABLED"
    }
    plugins_config {
      name          = "Management Agent"
      desired_state = "ENABLED"
    }
    plugins_config {
      name          = "Vulnerability Scanning"
      desired_state = "ENABLED"
    }
  }

  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }

  availability_config {
    recovery_action = "RESTORE_INSTANCE"
  }
}

resource "local_file" "vm_output_files" {
  for_each = local.vm_output_files

  content         = each.value.content
  filename        = each.value.filename
  file_permission = each.value.file_permission
}

data "oci_core_images" "oracle_linux" {
  compartment_id           = local.compartment_id
  operating_system         = "Oracle Linux"
  operating_system_version = "9"
  shape                    = local.vm_tmp.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}


data "oci_core_images" "ubuntu" {
  compartment_id           = local.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "26.04 Minimal aarch64"
  shape                    = local.vm_tmp.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = local.compartment_id
}

module "sha512_password" {
  source   = "./modules/sha512-password"
  password = local.vm.password
  rounds   = 4096
}
