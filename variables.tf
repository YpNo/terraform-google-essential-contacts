variable "essential_contacts" {
  description = <<-EOT
    Essential Contacts to manage, grouped by parent resource.

    Each element targets one parent (organization, folder or project) and maps
    one or more contact email addresses to the notification categories they
    should be subscribed to.

    Attributes:
      - parent:             Resource the contacts are attached to. One of
                            "organizations/<id>", "folders/<id>" or
                            "projects/<id-or-number>".
      - essential_contacts: Map of contact email address to the list of
                            notification categories to subscribe to. Valid
                            categories: ALL, SUSPENSION, SECURITY, TECHNICAL,
                            BILLING, LEGAL, PRODUCT_UPDATES, TECHNICAL_INCIDENTS.
                            "ALL" must be used on its own.
      - language_tag:       Optional preferred language for notifications as an
                            RFC 3066 / BCP 47 tag (e.g. "en-US"). Falls back to
                            var.default_language_tag when omitted.
  EOT

  type = list(object({
    parent             = string
    essential_contacts = map(list(string))
    language_tag       = optional(string)
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
        for _, categories in group.essential_contacts :
        length(categories) > 0
      ]
    ]))
    error_message = "Every contact must subscribe to at least one notification category."
  }

  validation {
    condition = alltrue(flatten([
      for group in var.essential_contacts : [
        for _, categories in group.essential_contacts : [
          for category in categories : contains(
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
        for _, categories in group.essential_contacts :
        !contains(categories, "ALL") || length(categories) == 1
      ]
    ]))
    error_message = "The \"ALL\" notification category cannot be combined with other categories."
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
