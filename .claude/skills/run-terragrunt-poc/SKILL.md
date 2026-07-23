---
name: run-terragrunt-poc
description: Build, run, and drive the Terragrunt Platform PoC. Use when asked to run/apply/plan/destroy the terragrunt example, deploy a service (payment-service, orders-db), provision the mock infra, verify the deployed_resources output, or smoke-test the platform modules.
---

The "app" here is Terragrunt + Terraform applying **simulated** cloud modules:
each module writes a text file to `example/deployed_resources/<name>_config.txt`
instead of calling a real provider — no credentials needed. Drive it with
`.claude/skills/run-terragrunt-poc/smoke.sh`, which cleans, applies every
service stack, and asserts the output files were written.

All paths below are relative to the repo root (`terragrunt-poc/`).

## Prerequisites

Already installed in this container. If starting fresh on Ubuntu, you need
`terragrunt` (1.1.0 — `stack` commands are used) and `terraform` on `PATH`.
There is **no** `tofu` binary here; `platform/root.hcl` pins
`terraform_binary = "terraform"` for that reason.

```bash
terragrunt --version   # → terragrunt version 1.1.0
terraform  --version   # → Terraform v1.15.8
```

Terraform downloads the `hashicorp/local` provider on first `apply`, so the
first run needs network access; later runs are cached under `.terragrunt-cache/`.

## Run (agent path) — smoke driver

One command applies both service stacks from clean and verifies the simulated
resources:

```bash
.claude/skills/run-terragrunt-poc/smoke.sh
# → ==> SMOKE PASSED   (exit 0)
```

Drive a single service, or just clean generated artifacts:

```bash
.claude/skills/run-terragrunt-poc/smoke.sh payment-service
.claude/skills/run-terragrunt-poc/smoke.sh --clean-only
```

The driver asserts `example/deployed_resources/` contains e.g.
`payment-service-db_config.txt` (`Engine: POSTGRES_15`) and
`payment-service-cache_config.txt` (`Engine: REDIS_7`), then re-plans to prove
idempotency (`No changes`).

## Run (manual path) — one service by hand

From a service directory:

```bash
cd example/payment-service
terragrunt stack run apply --non-interactive    # provision every module
terragrunt stack run plan  --non-interactive     # show pending changes
terragrunt stack run destroy --non-interactive   # remove the simulated files
```

Inspect what got "provisioned":

```bash
cat example/deployed_resources/payment-service-db_config.txt
```

`terragrunt stack generate` materializes the units under `.terragrunt-stack/`
without applying (optional — `apply` does it too).

## Add / change a developer's infra

Edit the service's `infra.yaml` (each top-level key = one module) and add a
matching ~6-line `unit` block to its `terragrunt.stack.hcl`, then re-apply.
See `example/README.md` for the developer walkthrough.

## Gotchas

- **Modules are fetched from a local path in the working tree.** The template
  (`platform/_templates/service-module/terragrunt.hcl`) `include`s the managed
  `platform/root.hcl` and sources modules as `${module_base}/<name>` where
  `module_base = <repo_root>/platform/modules`. Editing anything under
  `platform/modules/` takes effect on the next `apply` immediately — **no git
  tag to move.** (In production, `root.hcl` is included by a pinned version, and
  that version pins the modules alongside it.)
- **Non-interactive is required for automation.** Without `--non-interactive`
  (or piping `yes`), `stack run apply` prompts for approval and hangs headless.
- **`terraform_binary = "terraform"` in `root.hcl` is load-bearing.** Terragrunt
  defaults to `tofu`, which isn't installed here; removing that line breaks
  every command with "tofu: executable file not found".
- **Generated dirs are git-ignored and safe to nuke.** `.terragrunt-stack/`,
  `.terragrunt-cache/`, and `*.tfstate` are regenerated on the next apply; the
  driver wipes them each run for a clean start.
- **State is per-unit.** Each `unit` block (cloudsql, redis) gets its own
  isolated Terraform state under `.terragrunt-stack/<unit>/`, so modules plan
  and apply independently — a failure in one doesn't roll back the others.

## Troubleshooting

- **`Error: ... /platform/modules/<name> does not exist`** — the module folder
  is missing or misnamed under `platform/modules/`. The module pulled defaults
  to the unit name (or the `module:` key in the `infra.yaml` block); check both.
- **Apply hangs with no output** — you dropped `--non-interactive`; it's waiting
  on the `Are you sure?` prompt. Ctrl-C and re-run with the flag.
- **`tofu: executable file not found in $PATH`** — `terraform_binary` was
  removed from `platform/root.hcl`; restore it.

## Test

There is no separate unit-test suite — the smoke driver *is* the test. A green
`SMOKE PASSED` (exit 0) means every stack applied and every simulated resource
file was written with the expected content.
