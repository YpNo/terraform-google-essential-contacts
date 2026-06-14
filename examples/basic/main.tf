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

  # Optional: override the built-in defaults applied when a contact/group omits
  # the corresponding field.
  default_language_tag    = "en-US"
  default_deletion_policy = "DELETE"

  essential_contacts = [
    {
      parent = "organizations/123456789"
      essential_contacts = {
        "all@example.com" = {
          notification_category_subscriptions = ["ALL"]
        }
        "security@example.com" = {
          notification_category_subscriptions = ["SECURITY", "LEGAL"]
          # Per-contact override: never let a destroy remove this one.
          deletion_policy = "PREVENT"
        }
      }
    },
    {
      parent = "folders/469120895423"
      essential_contacts = {
        "infrastructure@example.com" = {
          notification_category_subscriptions = ["SECURITY", "TECHNICAL", "TECHNICAL_INCIDENTS", "PRODUCT_UPDATES"]
        }
      }
      language_tag = "fr-FR"
    },
  ]
}

output "contact_names" {
  description = "Fully-qualified names of the managed contacts."
  value       = module.essential_contacts.contact_names
}
