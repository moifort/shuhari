terraform {
  backend "gcs" {
    bucket = "shuhari-polyforms-tfstate"
    prefix = "shuhari"
  }
}
