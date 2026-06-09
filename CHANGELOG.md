# Changelog

All notable changes to this module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this module adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-06-09

### Added

- Initial release: manage Google Cloud Essential Contacts at the organization,
  folder or project level from a single parent-grouped declaration.
- Plan-time validation of parent format, email format, notification categories,
  `ALL` exclusivity and `(parent, email)` uniqueness.
- Configurable per-group `language_tag` with a module-wide default.
- Declarative import of pre-existing contacts via `import_contacts`.
- `essential_contacts` and `contact_names` outputs.

[Unreleased]: https://github.com/YpNo/terraform-google-essential-contacts/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/YpNo/terraform-google-essential-contacts/releases/tag/v0.1.0
