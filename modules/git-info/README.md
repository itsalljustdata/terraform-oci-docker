# Git metadata module

Reads Git repository metadata using Python and exposes it to Terraform.

## Prerequisites

- Python available as `python` on the Terraform execution machine
- Git available on `PATH`

## Behavior

The module runs `git_info.py` with a repository directory and returns:

- Current `HEAD` commit
- `origin` remote URL
- Normalized repository source path
- Whether the repository has working-tree changes

If Git metadata cannot be read, the module returns `unknown` values and `is_dirty` returns `false`.

## Usage

```terraform
module "git_info" {
  source   = "./modules/git-info"
  repo_dir = path.module
}

locals {
  git = {
    commit     = module.git_info.commit
    remote_url = module.git_info.remote_url
    source     = module.git_info.source
    is_dirty   = module.git_info.is_dirty
  }
}
```

## Inputs

| Name | Type | Description |
|---|---|---|
| `repo_dir` | `string` | Directory inside the Git repository to inspect. |

## Outputs

| Name | Type | Description |
|---|---|---|
| `commit` | `string` | Full current `HEAD` commit hash. |
| `remote_url` | `string` | URL of the `origin` remote. |
| `source` | `string` | Repository source normalized from the remote URL. |
| `is_dirty` | `string` | `true` or `false`, based on Git working-tree status. |
