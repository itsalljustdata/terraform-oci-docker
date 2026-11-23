terraform {
  required_providers {
    external = {
      source = "hashicorp/external"
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
  program = ["python", "-c", <<-PY
import json
import secrets
import string
import sys

payload = json.loads(sys.stdin.read())
password = payload["password"]
rounds = int(payload["rounds"])

try:
    from passlib.hash import sha512_crypt
except ImportError:
    print(json.dumps({"error": "Python package passlib is not installed"}), file=sys.stderr)
    raise SystemExit(1)

salt = "".join(secrets.choice(string.ascii_letters + string.digits + "./") for _ in range(16))
password_hash = sha512_crypt.using(rounds=rounds, salt=salt).hash(password)
print(json.dumps({"hash": password_hash}))
PY
  ]

  query = {
    password = var.password
    rounds   = tostring(var.rounds)
  }
}

output "hash" {
  value     = data.external.sha512_crypt.result.hash
  sensitive = true
}
