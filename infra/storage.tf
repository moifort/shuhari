# Bucket holding trial photos (objects keyed users/{userId}/trials/{trialId}.jpg).
# No public / client access: uniform bucket-level access is on and public access
# is enforced-off, so the only way in is through the backend. The Nitro function
# reads/writes objects and mints V4 signed URLs with the runtime SA credentials.
resource "google_storage_bucket" "trial_photos" {
  project                     = google_project.this.project_id
  name                        = "${google_project.this.project_id}-trial-photos"
  location                    = var.region
  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  depends_on = [google_project_service.apis]
}

# The runtime SA needs objectAdmin (read, write, delete, and sign) so the
# function can store trial photos and generate signed URLs for the client.
resource "google_storage_bucket_iam_member" "trial_photos_runtime" {
  bucket = google_storage_bucket.trial_photos.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.function.email}"
}
