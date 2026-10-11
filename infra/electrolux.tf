# The daily keep-alive of the Electrolux token chain. Electrolux rotates the refresh
# token on every use; one nobody spends for weeks may simply expire, and the chain
# was found dead on 2026-10-11 after 25 days without a cooking. Spending it once a
# day keeps it in use whatever the kitchen does. Only when the oven is provisioned.
resource "google_cloud_scheduler_job" "electrolux_keep_alive" {
  count = nonsensitive(var.electrolux_refresh_token) != "" ? 1 : 0

  project     = google_project.this.project_id
  region      = var.region
  name        = "electrolux-keep-alive"
  description = "Spends the Electrolux refresh token daily so the chain never goes idle"
  schedule    = "30 4 * * *"
  time_zone   = "Europe/Paris"

  retry_config {
    retry_count = 3
  }

  http_target {
    http_method = "POST"
    uri         = "${google_cloudfunctions2_function.server.service_config[0].uri}/admin/electrolux/refresh"
    headers = {
      Authorization = "Bearer ${local.admin_token_value}"
    }
  }

  depends_on = [google_project_service.apis]
}
