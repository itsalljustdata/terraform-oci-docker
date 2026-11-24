terraform {
  required_providers {
    external = {
      source  = "hashicorp/external"
      version = ">= 2.4.2"
    }
  }
}

variable "repo_dir" {
  type = string
}

data "external" "git_info" {
  program = [
                "python",
                "${path.module}/git_info.py",
                "--repo-dir", var.repo_dir,
                "--print"
            ]
}

output "commit" {
  value = data.external.git_info.result.commit
}

output "remote_url" {
  value = data.external.git_info.result.remote_url
}

output "source" {
  value = data.external.git_info.result.source
}

output "is_dirty" {
  value = data.external.git_info.result.is_dirty
}
