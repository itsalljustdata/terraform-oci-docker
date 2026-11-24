terraform {
  required_providers {
    external = {
      source  = "hashicorp/external"
      version = ">= 2.4.2"
    }
  }
}

variable "output_file" {
  type = string
}

data "external" "wireguard_keypair" {
  program = [
                "python",
                "${path.module}/wireguard_keypair.py",  
                "--output_file", var.output_file,
                "--print"
            ]

}

output "private_key" {
  value     = data.external.wireguard_keypair.result.private_key
  sensitive = true
}

output "public_key" {
  value = data.external.wireguard_keypair.result.public_key
}
