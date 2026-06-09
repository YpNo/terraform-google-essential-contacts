# Basic usage of the google-essential-contacts module.
#
#   terraform init
#   terraform plan
#
# Requires a configured google-beta provider with permission to manage
# Essential Contacts on the targeted parent(s).

provider "google-beta" {}

module "essential_contacts" {
  source = "../../"

  # Optional: overrides the built-in "en-US" default for groups that omit
  # `language_tag`.
  default_language_tag = "en-US"

  essential_contacts = [
    {
      parent = "organizations/123456789"
      essential_contacts = {
        "all@example.com"      = ["ALL"]
        "security@example.com" = ["SECURITY", "LEGAL"]
      }
    },
    {
      parent = "folders/469120895423"
      essential_contacts = {
        "infrastructure@example.com" = ["SECURITY", "TECHNICAL", "TECHNICAL_INCIDENTS", "PRODUCT_UPDATES"]
      }
      language_tag = "fr-FR"
    },
  ]
}

output "contact_names" {
  description = "Fully-qualified names of the managed contacts."
  value       = module.essential_contacts.contact_names
}
