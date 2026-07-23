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
2. **`example/platform.hcl`** — **team-owned**, set ONCE per team. Holds `platform_repo` +
   `platform_version` and assembles the `template` fetch URL from them. `platform_version` is a git
   tag of the platform repo (special value `local-dev` sources the working tree — see gotchas).
   Every service under it reads `template` via `find_in_parent_folders("platform.hcl")` — the
   version is **never** repeated in an `infra.yaml` or stack file. Upgrading a team = bump this one
   line. (Also the natural home for future per-team facts: gcp project, deployer SA.)
3. **`example/<service>/terragrunt.stack.hcl`** — a 1-line `locals` reading `template` from
   `platform.hcl`, then one **minimal** `unit` block per module: just `source = local.template` +
   `path` (the unit name, which must equal the `infra.yaml` key). No `values` — the template derives
   which module to pull, this unit's vars, and the output dir from the unit name. Terragrunt
   generates an isolated unit (its own state) per block under `.terragrunt-stack/`.
4. **`platform/terragrunt.hcl`** — the single **self-contained** generic unit every module reuses.
   It IS the template AND the (folded-in) platform root config: `terraform_binary`, the derivation
   logic, and the commented `remote_state`. Fetched WHOLE by a service's `unit.source` at the pinned
   git ref (`git::file://<repo-root>//platform?ref=<tag>`), which pulls this file **and** `modules/`
   together so they're always the same version. Derives from its own unit name: `module_name`
   (defaults to the unit name; overridable via a reserved `module:` key in the `infra.yaml` block),
   this unit's `developer_vars` (its `infra.yaml` slice), and `output_dir`. There is **no per-module
   terragrunt.hcl** and **no separate root.hcl** — an `include` can't take a git ref and a fetched
   sub-dir strands a sibling root.hcl, so root config lives here and the module source is a same-repo
   relative path (`${get_terragrunt_dir()}/modules/${module_name}`).
5. **`platform/modules/<name>/`** — the module implementations (`cloudsql`, `redis`). Module dir
   names **match the `infra.yaml` aliases** so `module_name` defaults to the unit name. Each
   simulates a resource via a `local_file`.

Ownership split: **platform** owns everything under `platform/` (`terragrunt.hcl` + `modules/`);
**team** owns `example/platform.hcl` (the repo + version pin); **developer** owns their
`example/<service>/` (`infra.yaml` + stack file).

## Remote state (production design)

`platform/terragrunt.hcl` documents the production `remote_state` (commented — no GCP in this PoC):
**one platform-owned GCS bucket**, bootstrapped once out-of-band; developers never define or create
a bucket. Every unit inherits the backend (it's in the fetched template), so developers write
**no** backend config. State isolation comes from the key `<project_id>/<unit-path>`, where
`project_id` is sourced from the **runtime deploy target** (never from `infra.yaml` or a hand-typed
field) — so the state key and the real resources always share one project, and no team can write
another team's state. `path_relative_to_include()` makes the unit path unique per module.

## Critical gotchas

- **The platform is fetched by git ref** (`git::file://<repo-root>//platform?ref=<tag>`). The git
  getter reads the **committed tag**, not the working tree — so editing `platform/` is invisible
  until you commit AND move the tag (`git tag -f <tag>`). To iterate WITHOUT committing, set
  `platform_version = "local-dev"` in `platform.hcl`: `template` then points at the working-tree
  path (no `?ref`) and edits apply on the next run. The smoke driver auto-toggles to `local-dev` for
  its applies, then does one pass at the real tag to prove the fetch path.
- **The git source syntax is `<repo-root>//<subdir>?ref=<tag>`.** The git repo is the PROJECT root;
  `platform/` is a subdir. Pointing `git::file://` straight at `platform/` fails ("not a git
  repository") — the `//platform` part selects the subdir within the repo.
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
   With `platform_version = "local-dev"` it takes effect immediately; to release it, commit and move
   the tag.

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

Always run the smoke test after changing a module, the `platform/terragrunt.hcl` template, a stack
file, or `platform.hcl`.

## Conventions

- Requires Terragrunt with `stack` support (tested on 1.1.0). `platform/terragrunt.hcl` pins
  `terraform_binary = "terraform"` (no OpenTofu here).
- Commits use the repo's global git identity; there is intentionally no local user override.
