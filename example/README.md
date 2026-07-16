# Example environment

This directory is a runnable example of the platform. Each subdirectory (`payment-service/`,
`orders-db/`) is one application. As a developer, the only file you edit is your app's `infra.yaml`.

## How it works

Each service has two files:

- **`infra.yaml`** — you own this. Every top-level key is one piece of infrastructure (a module),
  and its sub-keys are that module's settings. Example (`payment-service/infra.yaml`):

  ```yaml
  cloudsql:
    db_name: payment-service-db
    size: small
    pg_version: "15"
  redis:
    name: payment-service-cache
    node_type: small
    redis_version: "7"
  ```

- **`terragrunt.stack.hcl`** — wires each YAML block to a platform module. One `unit` block per
  module, all pointing at the shared template in `_templates/service-module/`:

  ```hcl
  unit "redis" {
    source = local.template          # the shared generic unit — no per-module HCL to write
    path   = "redis"                 # terragrunt generates this dir for you under .terragrunt-stack/
    values = {
      module_name    = "mock-redis"
      developer_vars = local.app_vars.redis   # this module's slice of infra.yaml
      output_dir     = local.output_dir
    }
  }
  ```

Terragrunt generates one isolated unit per `unit` block under `.terragrunt-stack/`, each with its
**own Terraform state** — so modules plan and apply independently.

## Running it

From a service directory (e.g. `example/payment-service/`):

```bash
terragrunt stack generate        # materialize the units under .terragrunt-stack/ (optional; apply does it too)
terragrunt stack run apply       # apply every module as a separate run
terragrunt stack run plan        # show pending changes across all modules
```

The simulated result is written to `example/deployed_resources/<name>_config.txt`.

## Adding a module to a service

No new directory to create by hand:

1. Add a block to the service's `infra.yaml`.
2. Add a matching ~6-line `unit` block to its `terragrunt.stack.hcl` (source = the shared template,
   `module_name` = the platform module, `developer_vars` = your new YAML slice).
3. `terragrunt stack run apply`.

## What the platform owns (don't edit as a developer)

- **`root.hcl`** — pins the module version (`module_version`) for the whole environment. Bumping it
  here upgrades every service at once.
- **`_templates/service-module/terragrunt.hcl`** — the single generic unit that every module reuses.
- **`../modules/`** — the module implementations.

> Note: modules are fetched by git tag (`?ref=<module_version>`). If you change a module's source
> here, re-point the tag (`git tag -f <version>`) or the change won't be picked up.
