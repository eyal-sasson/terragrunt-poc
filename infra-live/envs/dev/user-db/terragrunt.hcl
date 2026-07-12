# 1. Inherit the root configuration
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# 2. Point to the secure platform module we created in Step 2
terraform {
  source = "../../../../tf-modules/mock-db"
}

# 3. Read the developer's YAML file dynamically
locals {
  developer_vars = yamldecode(file("infra.yaml"))
}

# 4. Pass the YAML data into the Terraform module as variables.
#    "version" is a reserved variable name in Terraform, so the platform
#    layer maps the developer's friendly `version` key to `pg_version`.
inputs = {
  db_name    = local.developer_vars.db_name
  size       = local.developer_vars.size
  pg_version = local.developer_vars.version

  # Write the simulated resource to the PoC root, not inside the
  # ephemeral .terragrunt-cache dir where the module actually runs.
  # get_terragrunt_dir() = infra-live/envs/dev/user-db  ->  ../../../.. = PoC root
  output_dir = "${get_terragrunt_dir()}/../../../../deployed_resources"
}
