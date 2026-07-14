variable "project_id" {
  description = "Globally unique GCP project id (e.g. shuhari-polyforms)"
  type        = string
}

variable "project_name" {
  description = "Human-readable project name shown in the GCP console"
  type        = string
  default     = "Shuhari"
}

variable "org_id" {
  description = "GCP organization id (mutually exclusive with folder_id)"
  type        = string
  default     = null
}

variable "folder_id" {
  description = "GCP folder id (mutually exclusive with org_id)"
  type        = string
  default     = null
}

variable "billing_account_id" {
  description = "GCP billing account id (e.g. AAAA-BBBB-CCCC-DDDD)"
  type        = string
}

variable "region" {
  description = "Region for the Cloud Function (Gen 2) and the trial-photos bucket"
  type        = string
  default     = "europe-west3"
}

variable "firestore_location" {
  description = "Firestore multi-region or region (e.g. eur3, europe-west3)"
  type        = string
  default     = "eur3"
}

variable "ios_bundle_id" {
  description = "iOS app bundle identifier"
  type        = string
  default     = "com.polyforms.shuhari.app"
}

# Apple Sign-In — all required, comes from Apple Developer
variable "apple_team_id" {
  description = "Apple Developer Team ID (10-char alphanum)"
  type        = string
}

variable "apple_services_id" {
  description = "Apple Sign-In Services ID (acts as OAuth client_id)"
  type        = string
}

variable "apple_key_id" {
  description = "Apple private key ID (10-char alphanum, matches the .p8 filename)"
  type        = string
}

variable "apple_private_key_path" {
  description = "Path to the AuthKey_XXXXXXXXXX.p8 file from Apple Developer"
  type        = string
}

# Backend secrets
variable "google_api_key" {
  description = "Google AI API key for recipe generation (Gemini). Exposed to the function as NITRO_GOOGLE_API_KEY."
  type        = string
  sensitive   = true
}

variable "sentry_dsn" {
  description = "Sentry DSN for error reporting (empty disables Sentry). Exposed to the function as NITRO_SENTRY_DSN, read via process.env.NITRO_SENTRY_DSN in the Nitro plugin."
  type        = string
  sensitive   = true
  default     = ""
}

variable "admin_token" {
  description = "Bearer token guarding /admin/* routes. Auto-generated if null."
  type        = string
  sensitive   = true
  default     = null
}

variable "github_repo" {
  description = "GitHub repository (owner/name) allowed to deploy via Workload Identity Federation"
  type        = string
  default     = "moifort/shuhari"
}

variable "enable_user_project_override" {
  description = "Route quota/billing through var.project_id. Disable for the first apply (project not created yet), enable afterwards."
  type        = bool
  default     = true
}
