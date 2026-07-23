# ============================================================================
# TEAM-OWNED PLATFORM PIN  (set ONCE per team — inherited by every service)
# ============================================================================
# This is the ONE place a team declares WHICH platform and WHICH version, and it
# also assembles the fetch URL (`template`) so services don't repeat it. Every
# unit under this dir sets `source = <read this file>.locals.template`, so the
# git ref appears in NO unit block and is set exactly once per team.
# Upgrading the whole team = bump `platform_version` here.
#
#   platform_repo    : base of the platform repo, as a Terragrunt git source.
#                      In production: "git::https://github.com/acme/platform.git".
#                      Here: a local git repo via git::file:// so the PoC can
#                      fetch a real tag with no network.
#   platform_version : a GIT TAG of that repo. Fetching the platform template at
#                      this ref pulls the template AND modules together — one tag
#                      versions the entire platform for this team.
#   template         : the composed source URL the units point at.
#
# NOTE: because this is a real git fetch, platform code changes are only picked
# up after they're committed and the tag is (re)moved — see the platform README.
#
# FUTURE (see discussion): this same file is the natural home for the other
# per-team facts we don't want in each service, e.g.:
#   gcp_project = "acme-payments-prod"   # deploy target (also the state-key namespace)
#   deployer_sa = "deployer@acme-payments-prod.iam.gserviceaccount.com"
# ----------------------------------------------------------------------------

locals {
  platform_repo    = "git::file://${get_repo_root()}/platform"
  platform_version = "v1.1.0"

  # Fully-built fetch URL — services read THIS directly, nothing to assemble.
  # `//.` = the platform repo root (self-contained template + modules);
  # ?ref pins the whole platform to one tag.
  template = "${local.platform_repo}//.?ref=${local.platform_version}"
}
