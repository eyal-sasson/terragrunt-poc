# 1. Inherit the root configuration
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# 2. Read platform-wide settings (module base + version) from root.hcl,
#    and read the developer's YAML. Developers NEVER set the module
#    version here — it lives in root.hcl.
locals {
  root           = read_terragrunt_config(find_in_parent_folders("root.hcl"))
  module_name    = "mock-db" # the only platform choice this env makes
  developer_vars = yamldecode(file("infra.yaml"))
}

# 3. Build the module source from the shared base + version.
terraform {
  source = "${local.root.locals.module_base}/${local.module_name}?ref=${local.root.locals.module_version}"
}

# 4. Pass the developer's YAML straight through (keys map 1:1 to module
#    variables), then add the inputs the PLATFORM owns — not the developer.
inputs = merge(
  local.developer_vars,
  {
    output_dir = "${get_terragrunt_dir()}/../../../../deployed_resources"
  }
)
