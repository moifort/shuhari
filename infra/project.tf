resource "google_project" "this" {
  name            = var.project_name
  project_id      = var.project_id
  org_id          = var.org_id
  folder_id       = var.folder_id
  billing_account = var.billing_account_id

  labels = {
    app = "shuhari"
  }
}

resource "google_project_service" "apis" {
  for_each = toset([
    "firebase.googleapis.com",
    "firestore.googleapis.com",
    "identitytoolkit.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "compute.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "eventarc.googleapis.com",
    "storage.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "serviceusage.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "firebaserules.googleapis.com",
    "orgpolicy.googleapis.com",
  ])

  project            = google_project.this.project_id
  service            = each.value
  disable_on_destroy = false
}

# Many GCP organizations enforce iam.allowedPolicyMemberDomains, which blocks
# IAM bindings to allUsers / allAuthenticatedUsers. The Cloud Run service must
# be publicly invokable because auth is enforced inside the function (Firebase
# ID token verification). We override the constraint at the project scope so
# the binding succeeds without touching org-wide policies.
# Only meaningful when the project lives under an organization: the
# iam.allowedPolicyMemberDomains constraint is inherited from the org and must be
# overridden for allUsers to be granted. A standalone (no-org) project has no
# such constraint, and setting an org policy would require org-level permissions
# the personal account lacks — so it is skipped there.
resource "google_org_policy_policy" "allow_public_iam" {
  count  = var.org_id != null && var.org_id != "" ? 1 : 0
  parent = "projects/${google_project.this.project_id}"
  name   = "projects/${google_project.this.project_id}/policies/iam.allowedPolicyMemberDomains"

  spec {
    rules {
      allow_all = "TRUE"
    }
  }

  depends_on = [google_project_service.apis]
}

# Org policy changes take ~1 min to propagate before downstream IAM bindings
# (e.g. allUsers on Cloud Run) succeed. Without this gate the first apply
# fails with "do not belong to a permitted customer" and needs a manual rerun.
resource "time_sleep" "wait_for_org_policy" {
  depends_on      = [google_org_policy_policy.allow_public_iam]
  create_duration = "90s"
}
