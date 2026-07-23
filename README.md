# Terragrunt Platform PoC

A small, self-contained proof-of-concept showing how a platform team can offer paved-road
infrastructure modules that application developers consume with a **single YAML file** — no
Terragrunt/HCL knowledge required.

The "cloud" here is simulated: each module writes a text file to `example/deployed_resources/`
instead of calling a real provider, so you can run the whole thing locally with no credentials.

## The idea

There are three roles, with a clean split of ownership:

| Role | Owns | Files |
| --- | --- | --- |
| **Platform team** | The reusable modules + the self-contained template/root config, versioned by git tag | `platform/` (`terragrunt.hcl`, `modules/`) |
| **Team** | *Which* platform + *which* version their services use | `example/platform.hcl` |
| **Developer** | *What* infrastructure their app needs | `example/<service>/infra.yaml` |

A developer describes their app's infrastructure in `infra.yaml` (e.g. "I need a small Postgres 15
database and a Redis 7 cache"). Terragrunt turns each block into an isolated, independently-applied
unit using a shared template — so developers never write HCL or manage state layout.

## Repo map

```
.
├── platform/                    # PLATFORM: managed & versioned by git tag
│   ├── terragrunt.hcl          #   self-contained template + root config (fetched whole, by ref)
│   └── modules/                #   reusable "cloud" modules (fetched with the template)
│       ├── cloudsql/          #     simulates a CloudSQL Postgres instance
│       └── redis/             #     simulates a Redis instance
└── example/                    # A ready-to-run example environment
    ├── platform.hcl            #   TEAM: pins which platform repo + version (git tag)
    ├── deployed_resources/     #   simulated rendered output (what got "provisioned")
    ├── payment-service/        #   DEVELOPER: an app needing a DB + a cache
    └── orders-db/              #   DEVELOPER: an app needing just a DB
```

In production `platform/` lives in a separate repo; services fetch it by a pinned git tag via
`unit.source` (`git::.../platform?ref=<tag>`). Here it's a subdir of this repo fetched the same way
(`git::file://<repo-root>//platform?ref=<tag>`). For fast local iteration, `platform.hcl` supports a
`local-dev` version that sources the working tree directly (no commit/tag needed).

## Try it

See **[`example/README.md`](example/README.md)** for the developer walkthrough and run commands.

## Requirements

- Terragrunt (tested with 1.1.0 — `stack` commands are used) and Terraform.
- No cloud credentials: modules only write local files.
