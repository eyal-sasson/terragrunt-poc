# 1. Inherit the root configuration
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# 2. Read platform-wide settings (module base + version) from root.hcl,
#    and read the APP's shared infra.yaml (one level up).
#    Developers NEVER set the module version — it lives in root.hcl.
locals {
  root           = read_terragrunt_config(find_in_parent_folders("root.hcl"))
  module_name    = "mock-redis"                                # which platform module
  app_vars       = yamldecode(file(find_in_parent_folders("infra.yaml")))
  developer_vars = local.app_vars.redis                       # this unit's slice
}

# 3. Build the module source from the shared base + version.
terraform {
  source = "${local.root.locals.module_base}/${local.module_name}?ref=${local.root.locals.module_version}"
}

# 4. Pass this module's YAML block straight through, then add the inputs
#    the PLATFORM owns — not the developer.
inputs = merge(
  local.developer_vars,
  {
    output_dir = "${get_terragrunt_dir()}/../../../../../deployed_resources"
  }
)
