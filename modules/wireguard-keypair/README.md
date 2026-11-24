# WireGuard X25519 key-pair module

Generates a private/public X25519 key pair using Python's `cryptography` package.

## Prerequisites

```powershell
python -m pip install cryptography
```

## Behavior

The module is intended to run only when:

- `wireguard.enabled` is `true`
- `wireguard.public_key` is empty

It writes the generated private and public keys to the supplied JSON file:

```text
wireguard-keypair.json
```

The JSON file contains sensitive data and should not be committed to source control.

## Usage

```terraform
module "wireguard_keypair" {
  count       = local.wireguard.enabled && trimspace(coalesce(local.wireguard.public_key, "")) == "" ? 1 : 0
  source      = "./modules/wireguard-keypair"
  output_file = "${path.module}/wireguard-keypair.json"
}

locals {
  wireguard_public_key = trimspace(coalesce(local.wireguard.public_key, "")) != "" ?
    trimspace(local.wireguard.public_key) :
    (local.wireguard.enabled ? module.wireguard_keypair[0].public_key : "")
}
```

## Outputs

- `private_key` — Base64-encoded raw X25519 private key; marked sensitive.
- `public_key` — Base64-encoded raw X25519 public key.
