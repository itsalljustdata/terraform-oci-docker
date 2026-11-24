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
  program = ["python", "-c", <<-PY
import json
import subprocess
import sys

payload = json.loads(sys.stdin.read())
repo_dir = payload["repo_dir"]

script = r"${path.module}/git_info.py"
result = subprocess.run(
    ["python", script, repo_dir],
    capture_output=True,
    text=True,
    check=True,
)
print(result.stdout.strip())
PY
  ]

  query = {
    repo_dir = var.repo_dir
  }
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
