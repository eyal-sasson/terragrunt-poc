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

- **`terragrunt.stack.hcl`** — a 1-line `locals` that reads the `template` fetch URL from the team's
  `platform.hcl`, then one **minimal** `unit` block per module. A unit is just `source` + `path` (its
  name); the template derives everything else from that name:

  ```hcl
  locals {
    # the platform fetch URL (repo + version), assembled once in platform.hcl
    template = read_terragrunt_config(find_in_parent_folders("platform.hcl")).locals.template
  }

  unit "redis" {
    source = local.template   # the shared generic template — no per-module HCL to write
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

Everything under `platform/` (a separate, git-tagged repo in production; a subdir here):

- **`platform/terragrunt.hcl`** — the self-contained generic template AND the folded-in root config
  (`terraform_binary`, the derivation logic, the commented remote-state design). Fetched whole, by
  git ref, so it and the modules are always the same version.
- **`platform/modules/`** — the module implementations, fetched alongside the template.

Your **team** owns one file: `example/platform.hcl`, which pins `platform_repo` + `platform_version`
and builds the `template` URL every service reads.

> Note: the platform is fetched by git tag (`git::.../platform?ref=<version>`), so editing platform
> code takes effect only after you commit and move the tag. For fast iteration, set
> `platform_version = "local-dev"` in `platform.hcl` — `template` then points at the working tree
> and edits apply on the next run with no commit. (The smoke driver does this toggling for you.)
