terraform {
  required_version = ">= 1.7.0"
  required_providers {
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 4.62"
    }
  }
}
