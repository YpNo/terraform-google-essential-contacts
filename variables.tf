variable "essential_contacts" {
  description = <<-EOT
    Essential Contacts to manage, grouped by parent resource.

    Each element targets one parent (organization, folder or project) and maps
    one or more contact email addresses to their configuration.

    Attributes:
      - parent:             Resource the contacts are attached to. One of
                            "organizations/<id>", "folders/<id>" or
                            "projects/<id-or-number>".
      - essential_contacts: Map of contact email address to an object:
          - notification_category_subscriptions: List of notification categories
              to subscribe to. Valid categories: ALL, SUSPENSION, SECURITY,
              TECHNICAL, BILLING, LEGAL, PRODUCT_UPDATES, TECHNICAL_INCIDENTS.
              "ALL" must be used on its own.
          - deletion_policy: Optional per-contact override of how Terraform
              treats deletion (PREVENT, ABANDON or DELETE). Falls back to
              var.default_deletion_policy when omitted.
      - language_tag:       Optional preferred language for notifications as an
                            RFC 3066 / BCP 47 tag (e.g. "en-US"). Falls back to
                            var.default_language_tag when omitted.
  EOT

  type = list(object({
    parent = string
    essential_contacts = map(object({
      notification_category_subscriptions = list(string)
      deletion_policy                     = optional(string)
    }))
    language_tag = optional(string)
  }))

  default  = []
  nullable = false

  validation {
    condition = alltrue([
      for group in var.essential_contacts :
      can(regex("^(organizations|folders|projects)/[^/]+$", group.parent))
    ])
    error_message = "Each 'parent' must match \"organizations/<id>\", \"folders/<id>\" or \"projects/<id>\"."
  }

  validation {
    condition = alltrue(flatten([
      for group in var.essential_contacts : [
        for email, _ in group.essential_contacts :
        can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", email))
      ]
    ]))
    error_message = "Every contact key must be a valid email address."
  }

  validation {
    condition = alltrue(flatten([
      for group in var.essential_contacts : [
        for _, contact in group.essential_contacts :
        length(contact.notification_category_subscriptions) > 0
      ]
    ]))
    error_message = "Every contact must subscribe to at least one notification category."
  }

  validation {
    condition = alltrue(flatten([
      for group in var.essential_contacts : [
        for _, contact in group.essential_contacts : [
          for category in contact.notification_category_subscriptions : contains(
            ["ALL", "SUSPENSION", "SECURITY", "TECHNICAL", "BILLING", "LEGAL", "PRODUCT_UPDATES", "TECHNICAL_INCIDENTS"],
            category
          )
        ]
      ]
    ]))
    error_message = "Invalid notification category. Valid values: ALL, SUSPENSION, SECURITY, TECHNICAL, BILLING, LEGAL, PRODUCT_UPDATES, TECHNICAL_INCIDENTS."
  }

  validation {
    condition = alltrue(flatten([
      for group in var.essential_contacts : [
        for _, contact in group.essential_contacts :
        !contains(contact.notification_category_subscriptions, "ALL") || length(contact.notification_category_subscriptions) == 1
      ]
    ]))
    error_message = "The \"ALL\" notification category cannot be combined with other categories."
  }

  validation {
    condition = alltrue(flatten([
      for group in var.essential_contacts : [
        for _, contact in group.essential_contacts :
        contact.deletion_policy == null ? true : contains(["PREVENT", "ABANDON", "DELETE"], contact.deletion_policy)
      ]
    ]))
    error_message = "Each contact 'deletion_policy' must be one of PREVENT, ABANDON or DELETE."
  }

  validation {
    condition = length(flatten([
      for group in var.essential_contacts : [
        for email, _ in group.essential_contacts : "${group.parent}-${email}"
      ]
      ])) == length(distinct(flatten([
        for group in var.essential_contacts : [
          for email, _ in group.essential_contacts : "${group.parent}-${email}"
        ]
    ])))
    error_message = "The same (parent, email) pair is declared more than once; each contact must be unique per parent."
  }
}

variable "default_language_tag" {
  description = "Default preferred language for notifications (RFC 3066 / BCP 47 tag, e.g. \"en-US\") applied when a group omits 'language_tag'."
  type        = string
  default     = "en-US"
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$", var.default_language_tag))
    error_message = "default_language_tag must be a valid RFC 3066 / BCP 47 language tag, e.g. \"en-US\"."
  }
}

variable "default_deletion_policy" {
  description = <<-EOT
    Module-wide default for how Terraform treats deletion of a contact, applied
    when a contact omits 'deletion_policy'. One of:
      - DELETE:  destroying the resource deletes the contact (default).
      - PREVENT: a destroy/apply that would delete the contact fails instead.
      - ABANDON: the contact is removed from Terraform state without being
                 deleted in the API.
  EOT
  type        = string
  default     = "DELETE"
  nullable    = false

  validation {
    condition     = contains(["PREVENT", "ABANDON", "DELETE"], var.default_deletion_policy)
    error_message = "default_deletion_policy must be one of PREVENT, ABANDON or DELETE."
  }
}
