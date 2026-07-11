# Shuhari — Terraform infrastructure

This module provisions the entire Firebase stack for Shuhari from a
greenfield GCP project: project itself, Firebase enablement, Firestore
(Native), security rules + indexes, Identity Platform with Apple OAuth,
the iOS Firebase app (and downloads `GoogleService-Info.plist`), the
secrets in Secret Manager, the GCS bucket for trial photos, and the Cloud
Function Gen 2 that runs the Nitro/GraphQL backend.

## Prerequisites

- `gcloud` CLI authenticated with Application Default Credentials:
  `gcloud auth application-default login`
- `terraform >= 1.6`
- `bun` (used by the `bootstrap.sh` driver to build the Nitro bundle)
- An Apple Developer account with a Service ID and a `.p8` private key
  (Sign in with Apple).
- A GCP billing account id and either an `org_id` or `folder_id`.

## One-time bootstrap

```bash
cp infra/terraform.tfvars.example infra/terraform.tfvars
# Edit terraform.tfvars: project_id, billing, Apple, secrets
cp ~/Downloads/AuthKey_KEY1234567.p8 infra/

# From repo root
bun run bootstrap
```

The `bootstrap.sh` driver:

1. validates prerequisites,
2. runs `bun install + bun run generate:graphql + bun run build`,
3. runs `terraform init && terraform apply -auto-approve`,
4. migrates the state to GCS and writes `infra/backend.tf`,
5. POSTs `/admin/migrate` with the generated admin token,
6. prints the Cloud Function URL and the iOS plist path.

End state after a fresh bootstrap: backend operational, Firestore ready,
Apple Sign-In configured, `ios/Shuhari/GoogleService-Info.plist` written.

## Subsequent deploys (CI)

Every push to `main` runs the deploy workflow, which builds the Nitro
bundle and runs `terraform apply` against the same state stored in GCS.
Only the function source archive changes between runs, so the diff is
minimal.

## Teardown

```bash
bun run destroy
```

Removes the Cloud Function, Firestore data, project, and everything else
created by this module. The project will retain billing for ~30 days
after deletion (GCP soft-delete).
