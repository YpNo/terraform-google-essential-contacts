# Native Terraform usage with optional Essential Contacts import.
#
#   terraform init
#   terraform plan                                  # normal create/manage
#   terraform plan -var 'import_contacts={...}'     # import pre-existing contacts
#   terraform apply
#
# `import` blocks are a ROOT-MODULE feature: they cannot live inside the reusable
# module. The caller declares them here and targets the resource *inside* the
# child module by its full address. A single `import_contacts` variable drives
# it: an empty map (the default) imports nothing, so the block is a harmless
# no-op on a normal run. Requires Terraform >= 1.7 for `for_each` on import
# blocks.
#
# This mirrors examples/terragrunt; the only difference is the `to` address,
# which carries the `module.` prefix because here the module is a CHILD module.

provider "google-beta" {}

variable "import_contacts" {
  description = <<-EOT
    Map of "<parent>-<email>" (the module's resource instance key, which must
    also appear in `essential_contacts` below) to the contact's fully-qualified
    resource name ("<parent>/contacts/<contact_id>"). Empty imports nothing.

    Discover existing contacts and their IDs with, e.g.:
      gcloud beta essential-contacts list --organization=<org_id>
  EOT

  type     = map(string)
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for id in values(var.import_contacts) :
      can(regex("^(organizations|folders|projects)/[^/]+/contacts/[^/]+$", id))
    ])
    error_message = "Each import ID must be a contact resource name like \"organizations/123/contacts/456\"."
  }
}

module "essential_contacts" {
  source = "../../"

  essential_contacts = [
    {
      parent = "organizations/123456789"
      essential_contacts = {
        "security@example.com" = ["SECURITY"]
      }
    },
  ]
}

import {
  for_each = var.import_contacts

  to = module.essential_contacts.google_essential_contacts_contact.this[each.key]
  id = each.value
}

output "contact_names" {
  description = "Fully-qualified names of the managed contacts."
  value       = module.essential_contacts.contact_names
}
