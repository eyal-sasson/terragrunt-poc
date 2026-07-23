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

- **`terragrunt.stack.hcl`** — declares one **minimal** `unit` block per module, all pointing at the
  shared template in `platform/_templates/service-module/`. A unit is just `source` + `path` (its
  name); the template derives everything else from that name:

  ```hcl
  unit "redis" {
    source = local.template   # the shared generic unit — no per-module HCL to write
    path   = "redis"          # MUST match the infra.yaml key; the template keys off this name
  }
  ```

  The unit name (`redis`) is both the `infra.yaml` key whose values it gets **and** the module it
  pulls (module dirs are named to match). Need two units on one module? Name them differently and
  add `module: redis` to each one's `infra.yaml` block.

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

1. Add a block to the service's `infra.yaml` (the top-level key = the unit name).
2. Add a matching **2-line** `unit` block to its `terragrunt.stack.hcl` (`source = local.template`,
   `path` = the same name). No `values` — the template derives the module, vars, and output dir.
3. `terragrunt stack run apply`.

## What the platform owns (don't edit as a developer)

Everything under `platform/` (a separate, versioned repo in production; a sibling dir here):

- **`platform/root.hcl`** — included by every service; pins the module version (`module_version`)
  for the whole environment and carries the production remote-state design. One place to upgrade.
- **`platform/_templates/service-module/terragrunt.hcl`** — the single generic unit that every
  module reuses.
- **`platform/modules/`** — the module implementations.

> Note: modules are sourced from a local path within `platform/`, so editing one takes effect on the
> next apply — no git tag to move. In production the `include` of `root.hcl` is pinned to a version,
> and that version pins the modules alongside it.
