# Self-contained Terragrunt usage with optional Essential Contacts import.
#
# Why a `generate` block instead of an `import` block in the module?
#
#   * Native `module "x" { source = ... }` usage makes this module a CHILD
#     module, and Terraform forbids `import` blocks in child modules. So the
#     module is intentionally kept import-agnostic (no import block in its own
#     .tf files).
#   * Terragrunt copies the `source` module into its cache and runs Terraform
#     with that module as the ROOT module. An `import` block is legal there.
#     Terragrunt cannot express an `import` block directly, but it can GENERATE
#     one into the generated root — which is exactly what this file does.
#
# A single `import_contacts` variable drives everything: an empty map (the
# default) imports nothing, so the `import` block is a harmless no-op on a normal
# run. Populate it to import pre-existing contacts; leave the entries in place
# afterwards (an import block for an already-managed resource is a no-op).
#
# Requires Terraform >= 1.7 (for_each on import blocks).

terraform {
  source = "tfr:///YpNo/essential-contacts/google?version=0.2.0"
}

# Emits the import wiring into the generated root module. Identical in shape to
# the native-Terraform example (examples/with-import); only the `to` address
# differs, because here the module IS the root (no `module.` prefix).
generate "essential_contacts_import" {
  path      = "essential_contacts_import.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<-EOT
    variable "import_contacts" {
      description = "Map of \"<parent>-<email>\" (the resource instance key) to the contact's resource name (\"<parent>/contacts/<id>\"). Empty imports nothing."
      type        = map(string)
      default     = {}
      nullable    = false

      validation {
        condition = alltrue([
          for id in values(var.import_contacts) :
          can(regex("^(organizations|folders|projects)/[^/]+/contacts/[^/]+$", id))
        ])
        error_message = "Each import ID must be a contact resource name like \"organizations/123/contacts/456\"."
      }
    }

    import {
      for_each = var.import_contacts

      to = google_essential_contacts_contact.this[each.key]
      id = each.value
    }
  EOT
}

inputs = {
  # Leave empty for a normal create/manage run. Populate (here, via -var, or via
  # TF_VAR_import_contacts) to import pre-existing contacts.
  import_contacts = {
    # "<parent>-<email>" => "<parent>/contacts/<contact_id>"
    # "organizations/123456789-security@example.com" = "organizations/123456789/contacts/987654321"
  }

  essential_contacts = [
    {
      parent = "organizations/123456789"
      essential_contacts = {
        "security@example.com" = ["SECURITY"]
      }
    },
  ]
}
