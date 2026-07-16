# Terragrunt Platform PoC

A small, self-contained proof-of-concept showing how a platform team can offer paved-road
infrastructure modules that application developers consume with a **single YAML file** — no
Terragrunt/HCL knowledge required.

The "cloud" here is simulated: each module writes a text file to `example/deployed_resources/`
instead of calling a real provider, so you can run the whole thing locally with no credentials.

## The idea

There are two roles, with a clean split of ownership:

| Role | Owns | Files |
| --- | --- | --- |
| **Platform team** | The reusable modules and the pinned module version | `modules/`, `example/root.hcl`, `example/_templates/` |
| **Developer** | *What* infrastructure their app needs | `example/<service>/infra.yaml` |

A developer describes their app's infrastructure in `infra.yaml` (e.g. "I need a small Postgres 15
database and a Redis 7 cache"). Terragrunt turns each block into an isolated, independently-applied
unit using a shared template — so developers never write HCL or manage state layout.

## Repo map

```
.
├── modules/                    # PLATFORM: reusable "cloud" modules (versioned via git tag)
│   ├── mock-db/                #   simulates a CloudSQL Postgres instance
│   └── mock-redis/             #   simulates a Redis instance
└── example/                    # A ready-to-run example environment
    ├── root.hcl                #   PLATFORM: one place to pin the module version
    ├── _templates/             #   PLATFORM: the generic unit template all modules reuse
    ├── deployed_resources/     #   simulated rendered output (what got "provisioned")
    ├── payment-service/        #   DEVELOPER: an app needing a DB + a cache
    └── orders-db/              #   DEVELOPER: an app needing just a DB
```

## Try it

See **[`example/README.md`](example/README.md)** for the developer walkthrough and run commands.

## Requirements

- Terragrunt (tested with 1.1.0 — `stack` commands are used) and Terraform.
- No cloud credentials: modules only write local files.
