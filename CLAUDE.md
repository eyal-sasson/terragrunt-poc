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
2. **`example/<service>/terragrunt.stack.hcl`** — one `unit` block per module. Each unit points at
   the shared template and passes its YAML slice as `values.developer_vars`. Terragrunt generates
   an isolated unit (its own state) per block under `.terragrunt-stack/`.
3. **`example/_templates/service-module/terragrunt.hcl`** — the single generic unit every module
   reuses. Builds the module source from `root.hcl` and merges developer vars + platform inputs.
   There is **no per-module terragrunt.hcl** — this template is it.
4. **`example/root.hcl`** — platform-owned. `module_base` + `module_version` pin which module
   version every service gets. One place to upgrade the whole environment.
5. **`modules/<name>/`** — the module implementations (`mock-db`, `mock-redis`). Each simulates a
   resource via a `local_file`.

Ownership split: **platform** owns `modules/`, `root.hcl`, `_templates/`; **developer** owns only
their `infra.yaml`.

## Critical gotchas

- **Modules are fetched by git tag**, not local path. `root.hcl` sets
  `module_base = "git::file://.../modules"` and the source uses `?ref=<module_version>` (currently
  `v1.1.0`). **Editing a module's files is invisible to Terragrunt until you move the tag:**
  after committing a module change, run `git tag -f v1.1.0` (or bump `module_version` and create a
  new tag). Symptom of forgetting: `stack run apply` fails with "modules/... does not exist" or
  silently uses the old code.
- **`version` is a reserved Terraform variable name.** `mock-redis` uses `redis_version`, and
  `mock-db` uses `pg_version` — never a bare `version` variable.
- `.terragrunt-stack/` and `.terragrunt-cache/` are generated and git-ignored; never commit them.
- `example/deployed_resources/*.txt` ARE committed — they're the example's rendered output.

## Adding a module to a service

No directory to create by hand:
1. Add a block to the service's `infra.yaml`.
2. Add a ~6-line `unit` block to its `terragrunt.stack.hcl` (`source = local.template`,
   `module_name`, `developer_vars = local.app_vars.<key>`).
3. If it's a brand-new module under `modules/`, commit it and move the tag (see gotcha above).

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
