# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

A local, credential-free **proof-of-concept** of a platform-engineering pattern: platform teams
publish reusable Terragrunt/Terraform modules; app developers consume them by editing a single
`infra.yaml`. The "cloud" is simulated — modules write text files to `example/deployed_resources/`
instead of calling a real provider. Everything runs locally with just `terragrunt` + `terraform`.

## Architecture (how a change flows)

1. **`example/<service>/infra.yaml`** — developer-owned. Each top-level key is one module; its
   sub-keys are that module's inputs. Example: `payment-service/infra.yaml` has a `cloudsql:` block
   and a `redis:` block.
2. **`example/platform.hcl`** — **team-owned**, set ONCE per team. Holds `platform_version` (a git
   tag of the platform repo) and later per-team facts (gcp project, deployer SA). Every service
   under it inherits the pin via `find_in_parent_folders("platform.hcl")` — the version is **never**
   repeated in an `infra.yaml` or stack file. Upgrading a team = bump this one line.
3. **`example/<service>/terragrunt.stack.hcl`** — one **minimal** `unit` block per module: just
   `source` (the shared template) + `path` (the unit name, which must equal the `infra.yaml` key).
   No `values` — the template derives which module to pull, this unit's vars, and the output dir
   from the unit name. Terragrunt generates an isolated unit (its own state) per block under
   `.terragrunt-stack/`.
4. **`platform/_templates/service-module/terragrunt.hcl`** — the single generic unit every module
   reuses. Discovers the team's `platform.hcl` pin via `find_in_parent_folders`, `include`s the
   managed `platform/root.hcl` (in production: the platform repo at that git tag), then **derives**
   from its own unit name: `module_name` (defaults to the unit name; overridable via a reserved
   `module:` key in the `infra.yaml` block), this unit's `developer_vars` (its `infra.yaml` slice),
   and `output_dir`. There is **no per-module terragrunt.hcl** — this template is it.
5. **`platform/root.hcl`** — platform-owned & managed. Included by the template (in production: a
   **versioned remote include** at the tag from `platform.hcl`; in this PoC: `${get_repo_root()}/
   platform/root.hcl`). `module_base` + `module_version` pin which module version every service
   gets. Also carries the commented **production `remote_state`** design (see below).
6. **`platform/modules/<name>/`** — the module implementations (`cloudsql`, `redis`). Module dir
   names **match the `infra.yaml` aliases** so `module_name` defaults to the unit name. Each
   simulates a resource via a `local_file`.

Ownership split: **platform** owns everything under `platform/` (`root.hcl`, `_templates/`,
`modules/`); **team** owns `example/platform.hcl` (the version pin); **developer** owns their
`example/<service>/` (`infra.yaml` + stack file).

## Remote state (production design)

`platform/root.hcl` documents the production `remote_state` (commented — no GCP in this PoC):
**one platform-owned GCS bucket**, bootstrapped once out-of-band; developers never define or create
a bucket. Every unit inherits the backend through the template's `include "root"`, so developers
write **no** backend config. State isolation comes from the key `<project_id>/<unit-path>`, where
`project_id` is sourced from the **runtime deploy target** (never from `infra.yaml` or a hand-typed
field) — so the state key and the real resources always share one project, and no team can write
another team's state. `path_relative_to_include()` makes the unit path unique per module.

## Critical gotchas

- **Modules are now fetched by LOCAL path**, not git tag. `root.hcl` sets
  `module_base = "${get_repo_root()}/platform/modules"` and the template source is
  `${module_base}/${module_name}` (no `?ref=`). Since `root.hcl` and `modules/` live in the same
  `platform/` tree, **editing a module takes effect immediately — no `git tag -f` dance.** In
  production the include's version pin versions the modules alongside `root.hcl`.
- **`version` is a reserved Terraform variable name.** `redis` uses `redis_version`, and
  `cloudsql` uses `pg_version` — never a bare `version` variable.
- **Unit name must equal the `infra.yaml` key.** The template keys off `basename` of the unit dir
  to find its vars and default module. Two units on one module: give each a distinct name and set
  `module: <module-dir>` in its `infra.yaml` block (the reserved key is stripped before inputs).
- `.terragrunt-stack/` and `.terragrunt-cache/` are generated and git-ignored; never commit them.
- `example/deployed_resources/*.txt` ARE committed — they're the example's rendered output.

## Adding a module to a service

No directory to create by hand:
1. Add a block to the service's `infra.yaml` (the key = the unit name).
2. Add a 2-line `unit` block to its `terragrunt.stack.hcl` (`source = local.template`, `path` = the
   same name). No `values` — the template derives the rest. Reuse a module for a second instance by
   naming the block differently and adding `module: <module-dir>` to its `infra.yaml` block.
3. If it's a brand-new module, add it under `platform/modules/<name>/` (name it to match the alias).
   It takes effect immediately (local path) — no tag to move.

## Running / verifying

Preferred — the smoke driver applies both services from a clean state and asserts outputs +
idempotency:

```bash
.claude/skills/run-terragrunt-poc/smoke.sh                 # all services
.claude/skills/run-terragrunt-poc/smoke.sh payment-service # one service
.claude/skills/run-terragrunt-poc/smoke.sh --clean-only    # wipe artifacts only
```

Manual, from a service dir (e.g. `example/payment-service/`):

```bash
terragrunt stack run apply   --non-interactive   # apply each module as a separate run
terragrunt stack run plan    --non-interactive   # expect "No changes" after apply
terragrunt stack run destroy --non-interactive   # removes the simulated *_config.txt files
```

`--non-interactive` is required for automation — without it, apply blocks on an approval prompt and
hangs headless. The first apply downloads the `hashicorp/local` provider (needs network once); later
runs are cached under `.terragrunt-cache/`.

Always run the smoke test after changing a module, template, stack file, or `root.hcl`.

## Conventions

- Requires Terragrunt with `stack` support (tested on 1.1.0). `root.hcl` pins
  `terraform_binary = "terraform"` (no OpenTofu here).
- Commits use the repo's global git identity; there is intentionally no local user override.
