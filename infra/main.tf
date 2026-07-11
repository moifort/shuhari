provider "google" {
  project = var.project_id
  region  = var.region
  # billing_project + user_project_override are enabled only AFTER the project
  # exists (they route the quota/billing check through var.project_id, which
  # can't be used while the project is still being created). Re-enable both once
  # the project is provisioned.
  billing_project       = var.enable_user_project_override ? var.project_id : null
  user_project_override = var.enable_user_project_override
}

provider "google-beta" {
  project               = var.project_id
  region                = var.region
  billing_project       = var.enable_user_project_override ? var.project_id : null
  user_project_override = var.enable_user_project_override
}

locals {
  # Cloud Storage multi-region IDs are uppercase ("EU", "US", "ASIA"),
  # while Firestore uses lowercase ("eur3", "nam5"). Map between the two
  # so buckets can be co-located with Firestore without a separate var.
  bucket_location = lookup(
    { eur3 = "EU", nam5 = "US", asia1 = "ASIA" },
    var.firestore_location,
    var.firestore_location,
  )
}
