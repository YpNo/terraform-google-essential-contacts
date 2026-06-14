locals {
  # Flatten the grouped input (parent -> { email -> categories }) into a flat
  # list of individual contact objects, one per (parent, email) pair. The
  # language tag falls back to the module default when a group omits it.
  contacts = flatten([
    for group in var.essential_contacts : [
      for email, contact in group.essential_contacts : {
        parent                              = group.parent
        email                               = email
        language_tag                        = coalesce(group.language_tag, var.default_language_tag)
        notification_category_subscriptions = contact.notification_category_subscriptions
        deletion_policy                     = coalesce(contact.deletion_policy, var.default_deletion_policy)
      }
    ]
  ])

  # Key each contact by "<parent>-<email>" so the same address can be
  # registered against several parents without collisions. This key is also the
  # resource instance address; keep it stable to avoid recreating contacts.
  contacts_by_key = {
    for contact in local.contacts : "${contact.parent}-${contact.email}" => contact
  }
}

resource "google_essential_contacts_contact" "this" {
  provider = google-beta

  for_each = local.contacts_by_key

  parent                              = each.value.parent
  email                               = each.value.email
  language_tag                        = each.value.language_tag
  notification_category_subscriptions = each.value.notification_category_subscriptions
  deletion_policy                     = each.value.deletion_policy
}
