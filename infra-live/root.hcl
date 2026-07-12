# Root Terragrunt configuration.
# In production, your remote_state (GCS backend) block goes here.

# No OpenTofu ("tofu") binary is installed in this PoC environment,
# so pin Terragrunt to the Terraform binary.
terraform_binary = "terraform"
