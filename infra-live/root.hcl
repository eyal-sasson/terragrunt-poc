# Root Terragrunt configuration.
# In production, your remote_state (GCS backend) block goes here.

# No OpenTofu ("tofu") binary is installed in this PoC environment,
# so pin Terragrunt to the Terraform binary.
terraform_binary = "terraform"

# ---------------------------------------------------------------------------
# PLATFORM-WIDE MODULE VERSION
# ---------------------------------------------------------------------------
# This is the ONE place to upgrade the platform modules for every environment.
# Bump `module_version` here and every child env picks it up automatically —
# developers never edit their own terragrunt.hcl.
locals {
  # Base of the published modules repo. In production this would be
  # e.g. "git::https://github.com/your-org/tf-modules.git"
  module_base    = "git::file://${get_repo_root()}//tf-modules"
  module_version = "v1.0.0"
}

