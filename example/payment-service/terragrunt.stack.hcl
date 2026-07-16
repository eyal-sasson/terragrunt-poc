# One stack describes ALL infrastructure for the payment-service app.
# Each `unit` block generates an isolated, independently-applied module
# (its own Terraform state) from the shared service-module template.
#
# Adding a module = add its block to infra.yaml + a small `unit` block here.
# No new directory to create by hand — terragrunt generates it under
# .terragrunt-stack/ from the `path` below.

locals {
  app_vars   = yamldecode(file("${get_terragrunt_dir()}/infra.yaml"))
  template   = "${get_repo_root()}/example/_templates/service-module"
  output_dir = "${get_repo_root()}/example/deployed_resources"
}

unit "cloudsql" {
  source = local.template
  path   = "cloudsql"
  values = {
    module_name    = "mock-db"
    developer_vars = local.app_vars.cloudsql
    output_dir     = local.output_dir
  }
}

unit "redis" {
  source = local.template
  path   = "redis"
  values = {
    module_name    = "mock-redis"
    developer_vars = local.app_vars.redis
    output_dir     = local.output_dir
  }
}
