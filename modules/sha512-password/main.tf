terraform {
  required_providers {
    external = {
      source  = "hashicorp/external"
      version = ">= 2.4.2"
    }
  }
}

variable "password" {
  type      = string
  sensitive = true
}

variable "rounds" {
  type    = number
  default = 4096
}

data "external" "sha512_crypt" {
  program = [
                "python",
                "${path.module}/sha512_password.py",
                "--password", var.password,
                "--rounds", tostring(var.rounds),
                "--print"
            ]
}

output "hash" {
  value     = data.external.sha512_crypt.result.hash
  sensitive = true
}
