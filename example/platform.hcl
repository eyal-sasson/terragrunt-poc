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
#                      SPECIAL VALUE "local-dev": bypass the git fetch and source
#                      the platform working tree directly (see `template` below).
#   template         : the composed source URL the units point at.
#
# NOTE: with a real version (e.g. v1.1.0) this is a git fetch, so platform code
# changes are only picked up after they're committed and the tag is (re)moved.
# For fast local iteration on platform code, set platform_version = "local-dev":
# `template` then points at the working-tree path (no ?ref), so edits under
# platform/ take effect on the next apply with NO commit/tag. This is a dev-loop
# convenience only — real teams pin a tag.
#
# FUTURE (see discussion): this same file is the natural home for the other
# per-team facts we don't want in each service, e.g.:
#   gcp_project = "acme-payments-prod"   # deploy target (also the state-key namespace)
#   deployer_sa = "deployer@acme-payments-prod.iam.gserviceaccount.com"
# ----------------------------------------------------------------------------

locals {
  # The git repo that HOLDS the platform. In production this is the platform
  # repo itself ("git::https://github.com/acme/platform.git"); here the platform
  # lives in the `platform/` subdir of THIS repo, so the source is
  # <repo-root>//platform (git getter syntax: <repo>//<subdir>?ref=<tag>).
  platform_repo    = "git::file://${get_repo_root()}"
  platform_subdir  = "platform"
  platform_version = "v1.1.0"

  # Fully-built source the units point at — services read THIS directly.
  #   - "local-dev"      -> the platform working tree (plain path, no ?ref):
  #                         instant edits, no commit/tag. Dev loop only.
  #   - a tag (v1.1.0)   -> git fetch of the platform subdir at that ref
  #                         (template + modules together), pinning the entire
  #                         platform to one version.
  template = (
    local.platform_version == "local-dev"
    ? "${get_repo_root()}/${local.platform_subdir}"
    : "${local.platform_repo}//${local.platform_subdir}?ref=${local.platform_version}"
  )
}
