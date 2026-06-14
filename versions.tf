terraform {
  required_version = ">= 1.7.0"
  required_providers {
    google-beta = {
      source = "hashicorp/google-beta"
      # 7.33 is the first release with `deletion_policy` on
      # google_essential_contacts_contact (added provider-wide).
      version = ">= 7.33"
    }
  }
}
