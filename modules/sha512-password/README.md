# SHA-512 password module

Generates a Linux SHA-512 crypt password hash using Python and Passlib.

Prerequisites:

```powershell
python -m pip install passlib
```

The password remains sensitive Terraform input, while only the generated SHA-512 crypt hash is written to cloud-config.

Usage:

```terraform
module "vm_password" {
  source   = "./modules/sha512-password"
  password = local.vm.password
  rounds   = 4096
}

locals {
  vm_password_hash = module.vm_password.hash
}
```
