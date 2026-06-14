# Changelog

All notable changes to this module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this module adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **BREAKING:** each `essential_contacts[*].essential_contacts` map value is now
  an object `{ notification_category_subscriptions = list(string), deletion_policy
  = optional(string) }` instead of a bare list of categories. Migration: wrap the
  category list, e.g. `"a@x.com" = ["ALL"]` becomes
  `"a@x.com" = { notification_category_subscriptions = ["ALL"] }`.
- **BREAKING:** minimum `google-beta` provider raised from `>= 4.62` to `>= 7.33`
  (the release that added `deletion_policy` to `google_essential_contacts_contact`).

### Added

- `deletion_policy` support (`PREVENT` / `ABANDON` / `DELETE`): a module-wide
  `default_deletion_policy` variable, overridable per contact via the contact
  object's optional `deletion_policy`. Exposed on the `essential_contacts` output
  and validated at plan time.

### Fixed

- Imports no longer fail with "Import blocks are only allowed in the root
  module". `import` blocks are a root-module feature and cannot live inside a
  reusable child module, which broke any consuming configuration (including the
  `examples/basic` pipeline check).

### Removed

- **BREAKING:** the `import_contacts` variable and the module's internal
  `import` block. The module is now import-agnostic; import wiring belongs
  wherever the module is the root module.

### Added

- A single `import_contacts` variable as the import interface, used the same way
  in both consumption modes (empty map = no-op; populate to import). No separate
  toggle: an `import` block with `for_each = var.import_contacts` is inert when
  the map is empty.
- `examples/with-import` (native Terraform: root-level `import` block targeting
  the child module) and `examples/terragrunt` (a `generate` block emitting the
  `import_contacts` variable and `import` block into the generated root). The
  block is identical bar the `to` address (`module.` prefix only in native).
- README guidance covering both import workflows.

## [0.1.0] - 2026-06-09

### Added

- Initial release: manage Google Cloud Essential Contacts at the organization,
  folder or project level from a single parent-grouped declaration.
- Plan-time validation of parent format, email format, notification categories,
  `ALL` exclusivity and `(parent, email)` uniqueness.
- Configurable per-group `language_tag` with a module-wide default.
- Declarative import of pre-existing contacts.
- `essential_contacts` and `contact_names` outputs.

[Unreleased]: https://github.com/YpNo/terraform-google-essential-contacts/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/YpNo/terraform-google-essential-contacts/releases/tag/v0.1.0
