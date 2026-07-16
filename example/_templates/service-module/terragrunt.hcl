# Generic, reusable service-module unit template.
# Every module a service uses is generated from THIS single file by a
# terragrunt.stack.hcl `unit` block — there is no per-module terragrunt.hcl
# to hand-write anymore. The stack passes three values:
#   - values.module_name    : which platform module to pull (e.g. "mock-db")
#   - values.developer_vars : that module's slice of the app's infra.yaml
#   - values.output_dir     : platform-owned injected input

include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

# Build the module source from the shared base + version (owned by root.hcl).
terraform {
  source = "${local.root.locals.module_base}/${values.module_name}?ref=${local.root.locals.module_version}"
}

# Developer's YAML slice, plus the inputs the PLATFORM owns.
inputs = merge(
  values.developer_vars,
  {
    output_dir = values.output_dir
  }
)
