# Unit tests for the google-essential-contacts module.
#
# A mocked google-beta provider is used so the suite runs with `terraform test`
# without any GCP credentials or API calls. Assertions target plan-time,
# configured attributes only (computed values such as `name` are unknown).

mock_provider "google-beta" {}

# ---------------------------------------------------------------------------
# Happy path: flattening, keying and language_tag defaulting.
# ---------------------------------------------------------------------------
run "flattens_contacts_and_applies_defaults" {
  command = plan

  variables {
    essential_contacts = [
      {
        parent = "organizations/123456789"
        essential_contacts = {
          "all@example.com"      = ["ALL"]
          "security@example.com" = ["SECURITY", "LEGAL"]
        }
        language_tag = "fr-FR"
      },
      {
        # Same email as above but a different parent -> distinct resource.
        # Omits language_tag -> falls back to default_language_tag.
        parent = "folders/987654321"
        essential_contacts = {
          "security@example.com" = ["SECURITY"]
        }
      },
    ]
  }

  assert {
    condition     = length(google_essential_contacts_contact.this) == 3
    error_message = "Expected one contact resource per (parent, email) pair (3 total)."
  }

  assert {
    condition     = google_essential_contacts_contact.this["organizations/123456789-security@example.com"].language_tag == "fr-FR"
    error_message = "An explicit language_tag must be honored."
  }

  assert {
    condition     = google_essential_contacts_contact.this["folders/987654321-security@example.com"].language_tag == "en-US"
    error_message = "A missing language_tag must fall back to default_language_tag (en-US)."
  }

  assert {
    condition     = google_essential_contacts_contact.this["organizations/123456789-all@example.com"].parent == "organizations/123456789"
    error_message = "The parent must be propagated to the contact resource."
  }
}

# ---------------------------------------------------------------------------
# default_language_tag is configurable.
# ---------------------------------------------------------------------------
run "default_language_tag_is_overridable" {
  command = plan

  variables {
    default_language_tag = "es-ES"
    essential_contacts = [
      {
        parent             = "projects/my-project"
        essential_contacts = { "ops@example.com" = ["TECHNICAL"] }
      },
    ]
  }

  assert {
    condition     = google_essential_contacts_contact.this["projects/my-project-ops@example.com"].language_tag == "es-ES"
    error_message = "default_language_tag override must be applied when a group omits language_tag."
  }
}

# ---------------------------------------------------------------------------
# Empty input is a valid no-op.
# ---------------------------------------------------------------------------
run "empty_input_creates_nothing" {
  command = plan

  variables {
    essential_contacts = []
  }

  assert {
    condition     = length(google_essential_contacts_contact.this) == 0
    error_message = "An empty input must create no resources."
  }
}

# ---------------------------------------------------------------------------
# Validation: bad parent prefix.
# ---------------------------------------------------------------------------
run "rejects_invalid_parent" {
  command = plan

  variables {
    essential_contacts = [
      {
        parent             = "billingAccounts/000-111"
        essential_contacts = { "a@example.com" = ["ALL"] }
      },
    ]
  }

  expect_failures = [var.essential_contacts]
}

# ---------------------------------------------------------------------------
# Validation: invalid notification category.
# ---------------------------------------------------------------------------
run "rejects_invalid_category" {
  command = plan

  variables {
    essential_contacts = [
      {
        parent             = "organizations/1"
        essential_contacts = { "a@example.com" = ["NOT_A_CATEGORY"] }
      },
    ]
  }

  expect_failures = [var.essential_contacts]
}

# ---------------------------------------------------------------------------
# Validation: ALL cannot be combined with other categories.
# ---------------------------------------------------------------------------
run "rejects_all_combined_with_others" {
  command = plan

  variables {
    essential_contacts = [
      {
        parent             = "organizations/1"
        essential_contacts = { "a@example.com" = ["ALL", "SECURITY"] }
      },
    ]
  }

  expect_failures = [var.essential_contacts]
}

# ---------------------------------------------------------------------------
# Validation: empty category list.
# ---------------------------------------------------------------------------
run "rejects_empty_category_list" {
  command = plan

  variables {
    essential_contacts = [
      {
        parent             = "organizations/1"
        essential_contacts = { "a@example.com" = [] }
      },
    ]
  }

  expect_failures = [var.essential_contacts]
}

# ---------------------------------------------------------------------------
# Validation: malformed email.
# ---------------------------------------------------------------------------
run "rejects_invalid_email" {
  command = plan

  variables {
    essential_contacts = [
      {
        parent             = "organizations/1"
        essential_contacts = { "not-an-email" = ["ALL"] }
      },
    ]
  }

  expect_failures = [var.essential_contacts]
}

# ---------------------------------------------------------------------------
# Validation: bad default_language_tag.
# ---------------------------------------------------------------------------
run "rejects_invalid_default_language_tag" {
  command = plan

  variables {
    default_language_tag = "english!"
    essential_contacts   = []
  }

  expect_failures = [var.default_language_tag]
}
