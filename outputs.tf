output "essential_contacts" {
  description = "Map of every managed Essential Contact, keyed by \"<parent>-<email>\", exposing the API resource details."
  value = {
    for key, contact in google_essential_contacts_contact.this : key => {
      name                                = contact.name
      parent                              = contact.parent
      email                               = contact.email
      language_tag                        = contact.language_tag
      notification_category_subscriptions = contact.notification_category_subscriptions
    }
  }
}

output "contact_names" {
  description = "List of the fully-qualified resource names (e.g. \"organizations/123/contacts/456\") of the managed Essential Contacts. Useful for importing or referencing existing contacts."
  value       = [for contact in google_essential_contacts_contact.this : contact.name]
}
