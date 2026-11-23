# SHA-512 password module

Generates a Linux SHA-512 crypt password hash using Python and Passlib.

Prerequisites:

```powershell
python -m pip install passlib
```

This module is only instantiated when `vm.password` is set. Use exactly one of:

- `vm.password`: a plaintext password that Terraform converts to a hash.
- `vm.password_hash`: an existing SHA-512 crypt hash beginning with `$6$`.

The password remains sensitive Terraform input. The generated hash is also treated as sensitive and is written to cloud-config as `hashed_passwd`.

Usage:

```terraform
module "sha512_password" {
  count    = try(trimspace(local.vm.password), "") != "" ? 1 : 0
  source   = "./modules/sha512-password"
  password = local.vm.password
  rounds   = 4096
}

locals {
  vm_password_hash = try(trimspace(local.vm.password_hash), "") != "" ?
    trimspace(local.vm.password_hash) :
    module.sha512_password[0].hash
}
```
