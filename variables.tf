variable "encode_files_in_cloud_init" {
  type        = bool
  description = "Enable or disable writing b64 encoded files within cloud-init."
  default     = false
}

variable "oci" {
  type = object({
    tenancy_ocid     = optional(string)
    compartment_ocid = optional(string)
    region           = optional(string)
    user_ocid        = optional(string)
    fingerprint      = optional(string)
    private_key_path = optional(string)
  })
  description = "OCI authentication and region settings grouped into one object."
}

variable "packages" {
  type        = list(string)
  description = "List of packages to install on the VM."
}

variable "stack" {
  type = object({
    prefix            = optional(string)
    name              = optional(string)
    domain_suffix     = optional(string)
    vcn_dns_prefix    = optional(string)
    dns_prefix_subnet = optional(string)
  })
  description = "Logical grouping for stack naming and DNS metadata."
}

variable "network" {
  type = object({
    vcn_cidr_blocks   = optional(list(string))
    subnet_cidr_block = optional(string)
    ipv6_enabled      = optional(bool)
  })
  description = "Logical grouping for the VCN and subnet CIDR values."
}

variable "ssh" {
  type = object({
    public_key_files       = optional(list(string))
    public_port            = optional(number)
    ssh_allowed_ipv4_cidrs = optional(list(string))
    ssh_allowed_ipv6_cidrs = optional(list(string))
    ssh_log_level          = optional(string)
    ssh_aliases            = optional(list(string))
    firewall_command       = optional(string)
  })
  description = "Logical grouping for SSH access and key configuration. Public SSH access is controlled by ssh_allowed_ipv4_cidrs."

  validation {
    condition     = coalesce(var.ssh.public_port, 22) >= 1 && coalesce(var.ssh.public_port, 22) <= 65535 && floor(coalesce(var.ssh.public_port, 22)) == coalesce(var.ssh.public_port, 22)
    error_message = "ssh.public_port must be a valid TCP/UDP port integer between 1 and 65535."
  }

  validation {
    condition     = contains(["ufw", "firewalld"], coalesce(var.ssh.firewall_command, "ufw"))
    error_message = "ssh.firewall_command must be either \"ufw\" or \"firewalld\"."
  }
}

variable "vm" {
  type = object({
    user          = optional(string)
    password      = optional(string)
    password_hash = optional(string)
    timezone      = optional(string)
    image_ocid    = optional(string)
    shape         = optional(string)
    shape_config = optional(object({
      ocpus         = number
      memory_in_gbs = number
    }))
    create_reserved_ip = optional(bool)
  })
  description = "Logical grouping for the VM login, OS timezone, OCI image, shape, and flexible-shape sizing."

  validation {
    condition = (
      can(regex("^VM\\.Standard\\.[A-Za-z0-9.]+$", coalesce(var.vm.shape, "VM.Standard.E2.1.Micro"))) &&
      (
        (!strcontains(coalesce(var.vm.shape, "VM.Standard.E2.1.Micro"), ".Flex") &&
        (var.vm.shape_config == null || (var.vm.shape_config.ocpus == null && var.vm.shape_config.memory_in_gbs == null))) ||
        (strcontains(coalesce(var.vm.shape, "VM.Standard.E2.1.Micro"), ".Flex") &&
          var.vm.shape_config != null &&
          var.vm.shape_config.ocpus > 0 &&
        var.vm.shape_config.memory_in_gbs > 0)
      )
    )
    error_message = "For non-flex shapes, leave shape_config unset. For .Flex shapes, include a positive shape_config with ocpus and memory_in_gbs values."
  }

  validation {
    condition = (
      (try(trimspace(var.vm.password), "") != "") !=
      (try(trimspace(var.vm.password_hash), "") != "")
    )
    error_message = "Set exactly one of vm.password or vm.password_hash, but not both."
  }

  validation {
    condition     = try(trimspace(var.vm.password_hash), "") == "" || can(regex("^\\$6\\$", try(trimspace(var.vm.password_hash), "")))
    error_message = "vm.password_hash must be a SHA-512 crypt hash beginning with $6$."
  }
}

variable "mount_block_vols_playbook" {
  type = string
  description = "The Ansible playbook to mount block volumes."
}

variable "storage" {
  type = object({
    block_vol_mounts = optional(list(object({
      ocid          = string
      device        = string
      path          = string
      fs_type       = string
      mount_options = list(string)
      format        = bool
    })))
  })
  description = "Logical grouping for OCI block volume attachments and mount configuration. Each entry must include the attached device path that the instance will mount."
}

variable "netbird" {
  type = object({
    enabled        = optional(bool)
    setup_key      = optional(string)
    management_url = optional(string)
    extra_flags    = optional(list(string))
  })
  description = "Optional NetBird bootstrap settings. When enabled, a bootstrap environment file is written for the VM to use during startup."

  validation {
    condition     = !(coalesce(var.netbird.enabled, false)) || trimspace(coalesce(var.netbird.setup_key, "")) != ""
    error_message = "netbird.setup_key is required when netbird.enabled is true."
  }
}


variable "docker" {
  type = object({
    enabled = optional(bool)
  })
  description = "Optional Docker installation settings for the VM."
}

variable "cloudflared" {
  type = object({
    enabled      = optional(bool)
    tunnel_token = optional(string)
  })
  description = "Optional Cloudflared settings for the VM."

  validation {
    condition     = !(coalesce(var.cloudflared.enabled, false)) || trimspace(coalesce(var.cloudflared.tunnel_token, "")) != ""
    error_message = "cloudflared.tunnel_token is required when cloudflared.enabled is true."
  }
}

variable "ansible" {
  type = object({
    enabled           = optional(bool)
    deploy_key_path = optional(string)
    repository        = optional(string)
    playbooks    = optional(list(object({
      name = string
      vars = optional(list(object({
        key   = string
        value = any
      })))
    })))
    deploy_key = optional(string)
  })
  description = "Optional Ansible settings for the VM."

  validation {
    condition = (
      (trimspace(coalesce(var.ansible.repository, "")) != "") ==
      (length(coalesce(var.ansible.playbooks, [])) > 0) &&
      (length(coalesce(var.ansible.playbooks, [])) == 0 || alltrue([for pb in coalesce(var.ansible.playbooks, []) : trimspace(pb.name) != ""]))
    )
    error_message = "When ansible.repository is set, ansible.playbooks must contain at least one entry; when repository is unset, playbooks must be empty or null."
  }

  validation {
    condition = (
      length([
        for pb in coalesce(var.ansible.playbooks, []) :
        pb.name
        if trimspace(pb.name) != ""
      ]) == length(coalesce(var.ansible.playbooks, []))
    )
    error_message = "ansible.playbooks cannot contain blank or whitespace-only entries."
  }
}
variable "warp" {
  type = object({
    enabled      = optional(bool)
    tunnel_token = optional(string)
  })
  description = "Optional Warp settings for the VM."

  validation {
    condition     = !(coalesce(var.warp.enabled, false)) || trimspace(coalesce(var.warp.tunnel_token, "")) != ""
    error_message = "warp.tunnel_token is required when warp.enabled is true."
  }
}

variable "wireguard" {
  type = object({
    enabled = optional(bool)
    # public_key = optional(string)
  })
  description = "Optional WireGuard settings for the VM."
}

variable "pangolin" {
  type = object({
    enabled     = optional(bool)
    site_id     = optional(string)
    site_secret = optional(string)
    endpoint    = optional(string)
  })
  description = "Optional Pangolin settings for the VM."

  validation {
    condition     = !(coalesce(var.pangolin.enabled, false)) || (trimspace(coalesce(var.pangolin.site_id, "")) != "" && trimspace(coalesce(var.pangolin.site_secret, "")) != "")
    error_message = "pangolin.site_id and pangolin.site_secret are required when pangolin.enabled is true."
  }
}

locals {
  git = {
    commit     = try(module.git_info.commit, "unknown")
    remote_url = try(module.git_info.remote_url, "unknown")
    source     = try(module.git_info.source, "unknown")
    is_dirty   = try(module.git_info.is_dirty, "false")
  }

  oci_defaults = {
    tenancy_ocid     = ""
    compartment_ocid = ""
    region           = ""
    user_ocid        = ""
    fingerprint      = ""
    private_key_path = "~/.ssh/id_ed25519"
  }

  stack_defaults = {
    prefix            = "darter"
    name              = ""
    domain_suffix     = "oraclevcn.com"
    vcn_dns_prefix    = "vcn"
    dns_prefix_subnet = "subnet"
  }

  network_defaults = {
    vcn_cidr_blocks   = ["10.0.0.0/16"]
    subnet_cidr_block = "10.0.80.0/24"
    ipv6_enabled      = true
  }

  ssh_defaults = {
    public_key_files       = ["~/.ssh/id_ed25519.pub"]
    public_port            = 22
    ssh_allowed_ipv4_cidrs = ["0.0.0.0/0"]
    ssh_allowed_ipv6_cidrs = ["::/0"]
    ssh_log_level          = "INFO"
    ssh_aliases            = []
    firewall_command       = "ufw"
  }

  storage_defaults = {
    block_vol_mounts = []
  }

  netbird_defaults = {
    enabled        = false
    setup_key      = ""
    management_url = "" # https://api.netbird.io
    extra_flags    = []
  }

  pangolin_defaults = {
    enabled     = false
    site_id     = ""
    site_secret = ""
    endpoint    = "https://app.pangolin.net"
  }

  docker_defaults = {
    enabled = true
  }

  wireguard_defaults = {
    enabled = false
    # public_key = ""
  }

  cloudflared_defaults = {
    enabled      = false
    tunnel_token = ""
  }
  warp_defaults = {
    enabled      = false
    tunnel_token = ""
  }
  ansible_defaults = {
    enabled          = false
    deploy_key_path = null
    repository       = null
    playbooks   = null
    deploy_key      = null
  }

  packages_wg = local.wireguard.enabled ? ["wireguard-tools", "iptables"] : []

  packages_defaults = [
    "curl",
    "bind9-dnsutils",
    "fastfetch",
    "git",
    "htop",
    "iotop",
    "jq",
    "nano",
    "python3-pip",
    "ufw",
    "wget"
  ]


  vm_defaults = {
    user          = "ubuntu"
    password      = ""
    password_hash = ""
    timezone      = "Australia/Sydney"
    image_ocid    = ""
    shape         = "VM.Standard.A1.Flex"
    shape_config = {
      ocpus         = 2
      memory_in_gbs = 12
    }
    create_reserved_ip = false
  }


  ansible_block_vol_playbook = (
    local.ansible_tmp.repository != null && length(local.storage.block_vol_mounts) > 0 && var.mount_block_vols_playbook != ""
    ? {
        name = "{{ var.mount_block_vols_playbook }}"
        vars = [{
          key   = "mountpoints"
          value = [for mount in local.storage.block_vol_mounts : mount.path]
        }]
      }
    : null
  )

  oci         = merge(local.oci_defaults, { for k, v in try(var.oci, {}) : k => v if v != null })
  stack       = merge(local.stack_defaults, { for k, v in try(var.stack, {}) : k => v if v != null })
  network     = merge(local.network_defaults, { for k, v in try(var.network, {}) : k => v if v != null })
  ssh         = merge(local.ssh_defaults, { for k, v in try(var.ssh, {}) : k => v if v != null })
  storage     = merge(local.storage_defaults, { for k, v in try(var.storage, {}) : k => v if v != null })
  netbird     = merge(local.netbird_defaults, { for k, v in try(var.netbird, {}) : k => v if v != null })
  docker      = merge(local.docker_defaults, { for k, v in try(var.docker, {}) : k => v if v != null })
  cloudflared = merge(local.cloudflared_defaults, { for k, v in try(var.cloudflared, {}) : k => v if v != null })
  warp        = merge(local.warp_defaults, { for k, v in try(var.warp, {}) : k => v if v != null })
  wireguard   = merge(local.wireguard_defaults, { for k, v in try(var.wireguard, {}) : k => v if v != null })
  ansible_tmp = merge(local.ansible_defaults, { for k, v in try(var.ansible, {}) : k => v if v != null })
  do_read_key = local.ansible_tmp.deploy_key_path != null && trimspace(local.ansible_tmp.deploy_key_path) != ""

  ansible_playbooks =  concat(
      local.ansible_block_vol_playbook != null ? [local.ansible_block_vol_playbook] : [],
      local.ansible_tmp.playbooks != null ? local.ansible_tmp.playbooks : []
  )

  ansible = merge(local.ansible_tmp, {
    repository = local.ansible_tmp.repository != null ? trimspace(local.ansible_tmp.repository) : null
    playbooks = [
      for pb in local.ansible_playbooks : {
        name = trimspace(coalesce(pb.name, ""))
        vars = pb.vars != null ? [
          for v in pb.vars : {
            key   = trimspace(coalesce(v.key, ""))
            value = v.value
          }
        ] : []
      }
    ]
    deploy_key = local.do_read_key ? trimspace(file(pathexpand(local.ansible_tmp.deploy_key_path))) : null
  })
  
  ansible_repo_hostname = (
        local.ansible.repository != null &&
        startswith(local.ansible.repository, "git@")
        ? try(regex("^git@([^:]+):", local.ansible.repository)[0], null)
        : null
      )

  vm_tmp = merge(local.vm_defaults, { for k, v in try(var.vm, {}) : k => v if v != null })

  imageKeys = [
    "id", "display_name",
    "operating_system", "operating_system_version",
    "time_created"
  ]

  images_all = [
      for source_image in data.oci_core_images.all.images : {
        for key in local.imageKeys : key => source_image[key]
        if can(source_image[key])
      }
    ]

  versions_all = flatten([
    for operating_system in sort(distinct([
      for image in local.images_all : image.operating_system
      ])) : [
      for operating_system_version in reverse(sort(distinct([
        for image in local.images_all : image.operating_system_version
        if image.operating_system == operating_system
        ]))) : {
        operating_system         = operating_system
        operating_system_version = operating_system_version
      }
    ]
  ])

  ubuntu_images_all = [
    for image in local.images_all : image
    if image.operating_system == "Canonical Ubuntu"
  ]
  # version
  versions_ubuntu_all = reverse(sort(distinct([
    for image in local.ubuntu_images_all :
    tonumber(split(" ", image.operating_system_version)[0])
  ])))

  ubuntu_images_minimal_all = [
    for image in local.ubuntu_images_all : image
    if strcontains(image.operating_system_version, "Minimal")
  ]
  versions_ubuntu_minimal = reverse(sort(distinct([
    for image in local.ubuntu_images_minimal_all :
    tonumber(split(" ", image.operating_system_version)[0])
  ])))

  latest_version_ubuntu = local.versions_ubuntu_minimal[0]

  # the most recent version of each Ubuntu operating system version
  ubuntu_images_minimal_by_version = flatten([
    for version in local.versions_ubuntu_minimal : slice([
      for image in local.ubuntu_images_minimal_all : image
      if startswith(image.operating_system_version, tostring(version))
    ], 0, 1)
  ])

  oracle_images = [
    for image in local.images_all : image
    if image.operating_system == "Oracle Linux" &&
    image.operating_system_version == "10"
  ]

  image_default = [
    for image in local.ubuntu_images_minimal_by_version : image
    if startswith(image.operating_system_version, tostring(local.latest_version_ubuntu))
  ][0]

  vm = merge(local.vm_tmp, {
    image_ocid = trimspace(local.vm_tmp.image_ocid) != "" ? local.vm_tmp.image_ocid : try(
      local.image_default.id,
      ""
    )
  })

  pangolin = merge(local.pangolin_defaults, { for k, v in try(var.pangolin, {}) : k => v if v != null })

  packages = sort(distinct(concat(local.packages_defaults, local.packages_wg, try(var.packages, []))))

  stack_name = local.stack.name != "" ? local.stack.name : "${local.stack.prefix}"

  this_vm_name  = "vm-${local.stack_name}"
  this_lb_name  = "net-lb-${local.stack_name}"
  this_vcn_name = "net-vcn-${local.stack_name}"

  dns = {
    vcn_label     = "${local.stack.vcn_dns_prefix}${local.stack.prefix}"
    subnet_label  = "${local.stack.dns_prefix_subnet}${local.stack.prefix}"
    search_domain = "${local.stack.vcn_dns_prefix}${local.stack.prefix}.${local.stack.domain_suffix}"
    public_name   = "${local.stack.prefix}.${local.stack.domain_suffix}"
  }

  ssh_public_keys_content = [
    for public_key_file in local.ssh.public_key_files :
    trimspace(file(pathexpand(public_key_file)))
  ]

  public_IPv4 = local.vm.create_reserved_ip ? try(oci_core_public_ip.vm_reserved_ip[0].ip_address, oci_core_instance.compute_instance.public_ip) : oci_core_instance.compute_instance.public_ip
  public_IPv6 = local.network.ipv6_enabled ? try(
    oci_core_instance.compute_instance.create_vnic_details[0].ipv6address_ipv6subnet_cidr_pair_details[0].ipv6address,
    ""
  ) : ""
  public_IP        = local.public_IPv6 != "" ? local.public_IPv6 : local.public_IPv4
  ssh_aliases      = concat([local.this_vm_name], coalesce(local.ssh.ssh_aliases, []))
  ssh_aliases_ipv6 = [for alias in local.ssh_aliases : "${alias}6"]

  resource_names = {
    compartment      = "cmp-${local.stack.prefix}"
    vm_instance      = local.this_vm_name
    hostname_label   = local.this_vm_name
    primary_vnic     = "${local.this_vm_name}-vnic"
    vm_ip            = "${local.this_vm_name}-public-ip"
    internet_gateway = "net-gw-${local.stack_name}"
    nat_gateway      = "net-nat-${local.stack_name}"
    nat_gateway_ip   = "${local.this_vcn_name}-nat-public-ip"
    nlb              = local.this_lb_name
    nlb_ip           = "${local.this_lb_name}-public-ip"
    listener         = "${local.this_lb_name}-listener-ssh"
    backend_set      = "${local.this_lb_name}-backend-set-ssh"
    vcn              = local.this_vcn_name
    subnet           = "${local.this_vcn_name}-subnet"
    dhcp_options     = "${local.this_vcn_name}-dhcp"
    route_table      = "${local.this_vcn_name}-route"
    security_list    = "${local.this_vcn_name}-sec"
  }

  stack_compartment_found = length(data.oci_identity_compartments.stack_compartment_lookup.compartments) > 0
  stack_compartment_id    = local.stack_compartment_found ? data.oci_identity_compartments.stack_compartment_lookup.compartments[0].id : ""
  explicit_compartment_id = local.oci.compartment_ocid != null && local.oci.compartment_ocid != "" ? local.oci.compartment_ocid : ""

  compartment_id = length(oci_identity_compartment.stack_compartment) > 0 ? oci_identity_compartment.stack_compartment[0].id : (
    local.stack_compartment_id != "" ? local.stack_compartment_id : (
      local.explicit_compartment_id != "" ? local.explicit_compartment_id : local.oci.tenancy_ocid
    )
  )


  image = try(
    one([
      for source_image in local.images_all : source_image
      if source_image.id == local.vm.image_ocid
    ]),
    null
  )

  # block_vol_fields = ["display_name","size_in_gbs","size_in_mbs"]

  block_mount_volumes = {
    for ocid, volume in data.oci_core_volume.block_mount_volumes :
    ocid => volume
  }

  block_mounts = [
    for mount in local.storage.block_vol_mounts :
    merge(mount, local.block_mount_volumes[mount.ocid])
  ]
  # block_mount_volume_names = {
  #   for ocid, volume in local.block_mount_volumes :
  #   ocid => volume.display_name
  # }

  # block_mounts = []

}
