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
  program = ["python", "-c", <<-PY
import base64
import json
import os
import sys

payload = json.loads(sys.stdin.read())
output_file = payload["output_file"]

try:
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import x25519
except ImportError:
    print(json.dumps({"error": "Python package cryptography is not installed"}), file=sys.stderr)
    raise SystemExit(1)

def decode_key(value):
    if not isinstance(value, str):
        raise ValueError("key is not a string")
    raw = base64.b64decode(value, validate=True)
    if len(raw) != 32:
        raise ValueError("key must decode to exactly 32 bytes")
    return raw

def load_existing():
    if not os.path.isfile(output_file):
        return None

    try:
        with open(output_file, "r", encoding="utf-8") as file:
            result = json.load(file)

        private_raw = decode_key(result["private_key"])
        public_raw = decode_key(result["public_key"])

        private_key = x25519.X25519PrivateKey.from_private_bytes(private_raw)
        derived_public_raw = private_key.public_key().public_bytes(
            encoding=serialization.Encoding.Raw,
            format=serialization.PublicFormat.Raw,
        )

        if derived_public_raw != public_raw:
            raise ValueError("public key does not match private key")

        return {
            "private_key": result["private_key"],
            "public_key": result["public_key"],
        }
    except (OSError, json.JSONDecodeError, KeyError, TypeError, ValueError):
        return None

result = load_existing()

if result is None:
    private_key = x25519.X25519PrivateKey.generate()
    public_key = private_key.public_key()

    result = {
        "private_key": base64.b64encode(private_key.private_bytes(
            encoding=serialization.Encoding.Raw,
            format=serialization.PrivateFormat.Raw,
            encryption_algorithm=serialization.NoEncryption(),
        )).decode("utf-8"),
        "public_key": base64.b64encode(public_key.public_bytes(
            encoding=serialization.Encoding.Raw,
            format=serialization.PublicFormat.Raw,
        )).decode("utf-8"),
    }

    with open(output_file, "w", encoding="utf-8") as file:
        json.dump(result, file, indent=2)

print(json.dumps(result))
PY
  ]

  query = {
    output_file = var.output_file
  }
}

output "private_key" {
  value     = data.external.wireguard_keypair.result.private_key
  sensitive = true
}

output "public_key" {
  value = data.external.wireguard_keypair.result.public_key
}
