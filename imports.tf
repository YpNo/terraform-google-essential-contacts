# Declarative import of pre-existing Essential Contacts.
#
# For every entry in var.import_contacts, Terraform imports the contact whose
# resource name is the map value into the resource instance identified by the
# map key ("<parent>-<email>"). Each key MUST also be declared in
# var.essential_contacts so the target instance exists in the plan.
#
# Requires Terraform >= 1.7 (for_each on import blocks).
import {
  for_each = var.import_contacts

  to = google_essential_contacts_contact.this[each.key]
  id = each.value
}
