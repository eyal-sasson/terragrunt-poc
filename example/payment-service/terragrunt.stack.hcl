# All infrastructure for the payment-service app.
# Each module you declare in infra.yaml gets ONE small unit block here — just
# `source` (the platform template, read from the team's platform.hcl) and `path`
# (the unit name, which must match the infra.yaml key). The template derives
# everything else (which module to pull, this unit's vars, output dir) from that
# name. There is NO per-service assembly — the fetch URL lives in platform.hcl.
#
# Adding a module = add a block to infra.yaml + a 3-line unit here.
# Two units on the SAME module? Give each a distinct name and set `module:` in
# its infra.yaml block to point at the shared module.

locals {
  # The fully-built platform fetch URL (repo + version), assembled once in
  # example/platform.hcl and read directly here.
  template = read_terragrunt_config(find_in_parent_folders("platform.hcl")).locals.template
}

unit "cloudsql" {
  source = local.template
  path   = "cloudsql"
}

unit "redis" {
  source = local.template
  path   = "redis"
}
