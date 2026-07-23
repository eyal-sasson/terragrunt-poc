# ============================================================================
# PLATFORM-OWNED, SELF-CONTAINED SERVICE-MODULE TEMPLATE
# ============================================================================
# This ONE file is the generic unit every module reuses AND the platform root
# config (what used to be a separate root.hcl, now folded in). It lives at the
# root of the PLATFORM repo so it can be fetched, WHOLE and VERSIONED, by a
# developer's `unit.source` at a pinned git ref:
#
#     source = "git::https://github.com/acme/platform.git//.?ref=v1.1.0"
#
# Fetching `//.` pulls this file AND the sibling modules/ into the unit, so the
# template and the modules are always the same version — one tag, one fetch.
# (An `include "root"` can't be used here: include.path can't take a git ref,
# and a fetched sub-dir strands its sibling root.hcl. So root config is folded
# in and modules are referenced by a same-repo RELATIVE path below.)
#
# Developer unit blocks stay MINIMAL — just `source` + `path` (the unit name) —
# because this template DERIVES everything else from its own unit name and the
# service's infra.yaml:
#   - unit name (the block's `path`) == the infra.yaml key for this module, and
#     ALSO the default module to pull (module dir names match the aliases).
#   - a module block may set a reserved `module:` key in infra.yaml to override
#     which module it pulls — needed when two units share one module
#     (e.g. cache_primary + cache_replica both -> module "redis").
# ----------------------------------------------------------------------------

# No OpenTofu ("tofu") binary in this PoC environment, so pin to terraform.
terraform_binary = "terraform"

locals {
  # This unit's identity, derived from where it was generated:
  #   .../example/<service>/.terragrunt-stack/<unit_name>/
  unit_name = basename(get_terragrunt_dir())
  svc_dir   = dirname(dirname(get_terragrunt_dir()))

  # The developer's whole infra.yaml, and this unit's slice of it (by unit name).
  app_vars       = yamldecode(file("${local.svc_dir}/infra.yaml"))
  developer_vars = local.app_vars[local.unit_name]

  # Which platform module to pull: the reserved `module:` override if present,
  # else default to the unit name (module dirs are named to match aliases).
  module_name = lookup(local.developer_vars, "module", local.unit_name)

  # Strip the reserved `module` key so it never leaks in as a module variable.
  module_inputs = { for k, v in local.developer_vars : k => v if k != "module" }

  # Platform-owned output location (the simulated "cloud"): example/deployed_resources.
  output_dir = "${dirname(local.svc_dir)}/deployed_resources"
}

# Module source is RELATIVE within the fetched platform repo, so modules are
# pinned to the SAME git ref as this template — no separate module version.
# `//.` fetch lands this file + modules/ together inside the unit dir.
terraform {
  source = "${get_terragrunt_dir()}/modules/${local.module_name}"
}

# Developer's YAML slice (minus the reserved `module` key), plus platform inputs.
inputs = merge(
  local.module_inputs,
  {
    output_dir = local.output_dir
  }
)

# ============================================================================
# REMOTE STATE  (production design — commented; no GCP in this PoC)
# ============================================================================
# ONE bucket for the whole platform, owned & bootstrapped by the platform team
# (created once, out-of-band; developers never define or create a bucket).
# Every unit inherits this block (it's in the fetched template), so developers
# write NO backend config. State isolation comes from the key:
#
#     <project_id> / <unit-path>
#
#   - <project_id> : the GCP project the apply authenticates/deploys INTO.
#       Sourced from the runtime deploy target (NOT from infra.yaml or a
#       hand-typed field), so the state key and the real resources always share
#       one project. A team cannot write another team's state, because writing
#       that key requires deploying into that project — which their identity
#       can't do.
#   - <unit-path>  : path_relative_to_include(), unique per module within a
#       service (cloudsql, redis, ...).
#
# remote_state {
#   backend = "gcs"
#   generate = {
#     path      = "backend.tf"
#     if_exists = "overwrite_terragrunt"
#   }
#   config = {
#     bucket   = "acme-platform-tfstate"   # platform-owned, ONE bucket
#     project  = "acme-platform"
#     location = "us-central1"
#     # project_id comes from the authenticated deploy target, never dev input:
#     prefix   = "${run_cmd("--terragrunt-quiet", "gcloud", "config", "get-value", "project")}/${path_relative_to_include()}"
#   }
# }
