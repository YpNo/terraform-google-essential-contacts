# Google Cloud - Essential Contacts Module

[![CI](https://github.com/YpNo/terraform-google-essential-contacts/actions/workflows/ci.yml/badge.svg)](https://github.com/YpNo/terraform-google-essential-contacts/actions/workflows/ci.yml)
[![Latest Release](https://img.shields.io/github/v/release/YpNo/terraform-google-essential-contacts?sort=semver&logo=github)](https://github.com/YpNo/terraform-google-essential-contacts/releases)
[![Terraform Registry](https://img.shields.io/badge/terraform-registry-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/modules/YpNo/essential-contacts/google/latest)
[![Terraform](https://img.shields.io/badge/terraform-%3E%3D_1.7.0-7B42BC?logo=terraform&logoColor=white)](https://developer.hashicorp.com/terraform/install)
[![Provider](https://img.shields.io/badge/google--beta-%3E%3D_7.33-4285F4?logo=googlecloud&logoColor=white)](https://registry.terraform.io/providers/hashicorp/google-beta/latest)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-FAB040?logo=pre-commit&logoColor=white)](https://pre-commit.com/)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

Terraform module to manage [Google Cloud Essential Contacts](https://cloud.google.com/resource-manager/docs/managing-notification-contacts)
at the **organization**, **folder** or **project** level.

Essential Contacts let Google notify the right people about important events
(security, billing, technical incidents, …) for a given resource. This module
takes a parent-grouped declaration of contacts and creates one
`google_essential_contacts_contact` per `(parent, email)` pair.

## Overview

- One declarative input groups contacts per parent resource.
- The same email address can be attached to several parents without collision.
- Inputs are validated at plan time (parent format, email format, notification
  categories, `ALL` exclusivity, deletion policy, duplicates) so misconfiguration
  fails fast rather than at the GCP API.
- `language_tag` and `deletion_policy` have module-wide defaults, each
  overridable (`language_tag` per group, `deletion_policy` per contact).

## Architecture

The input is a list of *groups*. Each group is flattened into individual
contacts and keyed by `"<parent>-<email>"`, which is also the resource instance
address (kept stable across versions to avoid recreation):

```
var.essential_contacts (list of groups)
        │  flatten: one object per (parent, email)
        ▼
local.contacts_by_key { "<parent>-<email>" => contact }
        │  for_each
        ▼
google_essential_contacts_contact.this
```

## Prerequisites

- Terraform `>= 1.7.0` (required for `for_each` on the `import` blocks used by
  the import workflow under [Importing existing contacts](#importing-existing-contacts)).
- A configured `google-beta` provider with permission to manage Essential
  Contacts on each targeted parent (role
  `roles/essentialcontacts.admin` or equivalent).
- The Essential Contacts API (`essentialcontacts.googleapis.com`) enabled.

## Usage

```hcl
provider "google-beta" {}

module "essential_contacts" {
  source  = "YpNo/essential-contacts/google"
  version = "~> 0.2"

  # Optional module-wide defaults.
  default_language_tag    = "en-US"   # default "en-US"
  default_deletion_policy = "DELETE"  # default "DELETE"

  essential_contacts = [
    {
      parent = "organizations/123456789"
      essential_contacts = {
        "all@example.com" = {
          notification_category_subscriptions = ["ALL"]
        }
        "security@example.com" = {
          notification_category_subscriptions = ["SECURITY", "LEGAL"]
          deletion_policy                     = "PREVENT" # per-contact override
        }
      }
    },
    {
      parent = "folders/469120895423"
      essential_contacts = {
        "infrastructure@example.com" = {
          notification_category_subscriptions = ["SECURITY", "TECHNICAL", "TECHNICAL_INCIDENTS", "PRODUCT_UPDATES"]
        }
      }
      language_tag = "fr-FR"
    },
  ]
}
```

A runnable example lives in [`examples/basic`](examples/basic).

### With Terragrunt

```hcl
terraform {
  source = "tfr:///YpNo/essential-contacts/google?version=0.1.0"
}

inputs = {
  essential_contacts = [
    {
      parent = "organizations/${local.global_config.locals.org_id}"
      essential_contacts = {
        "ypno.gh+security@gmail.com" = {
          notification_category_subscriptions = ["SECURITY", "LEGAL"]
        }
      }
    },
  ]
}
```

To import pre-existing contacts under Terragrunt, see
[Importing existing contacts](#importing-existing-contacts) and the runnable
[`examples/terragrunt`](examples/terragrunt).

## Configuration

### Notification categories

Valid values for each contact's category list:

`ALL`, `SUSPENSION`, `SECURITY`, `TECHNICAL`, `BILLING`, `LEGAL`,
`PRODUCT_UPDATES`, `TECHNICAL_INCIDENTS`.

`ALL` subscribes to every category and **must be used on its own** — combining
it with other categories is rejected at plan time.

### Parent format

`parent` must be one of `organizations/<id>`, `folders/<id>` or
`projects/<id-or-number>`.

### Deletion policy

Controls what Terraform does when a contact would be destroyed. Set the
module-wide default with `default_deletion_policy` and override it per contact
with `deletion_policy`:

| Value     | Behavior                                                              |
| --------- | -------------------------------------------------------------------- |
| `DELETE`  | Destroying the resource deletes the contact via the API (default).   |
| `PREVENT` | A `destroy`/`apply` that would delete the contact fails instead.     |
| `ABANDON` | The contact is removed from Terraform state without an API deletion. |

> Requires `google-beta >= 7.33` — `deletion_policy` was added to
> `google_essential_contacts_contact` in that release.

## Importing existing contacts

Terraform `import` blocks are a **root-module-only** feature, so this reusable
module is intentionally kept import-agnostic — it carries no `import` block of
its own. The import wiring lives wherever the module is the **root** module.

A single `import_contacts` variable drives everything, used **the same way** in
both Terraform and Terragrunt:

- Map of `"<parent>-<email>"` (the resource instance key) to the contact's
  resource name (`"<parent>/contacts/<id>"`).
- An empty map (the default) imports nothing — so the `import` block is a
  harmless no-op on a normal run, and you can leave it in place permanently.
- Every imported key must also be declared in `essential_contacts` so it stays
  managed after import. The instance key is always `"<parent>-<email>"`.
- Discover existing contacts and their IDs with:

  ```bash
  gcloud beta essential-contacts list --organization=123456789
  ```

  Contact names look like `organizations/123456789/contacts/987654321`.

The `import` block is identical in both modes; **only the `to` address differs**,
because the module is the root under Terragrunt but a child under native
Terraform.

### Native Terraform (`module { source = ... }`)

The module is a **child** module, so the `import` block goes in **your own root**
and targets the resource by its full address (`module.<name>...`). See the
runnable [`examples/with-import`](examples/with-import).

```hcl
variable "import_contacts" {
  type    = map(string)
  default = {}
}

module "essential_contacts" {
  source  = "YpNo/essential-contacts/google"
  version = "~> 0.2"

  essential_contacts = [
    {
      parent = "organizations/123456789"
      essential_contacts = {
        "security@example.com" = { notification_category_subscriptions = ["SECURITY"] }
      }
    },
  ]
}

import {
  for_each = var.import_contacts

  to = module.essential_contacts.google_essential_contacts_contact.this[each.key]
  id = each.value
}
```

```bash
terraform apply -var 'import_contacts={"organizations/123456789-security@example.com"="organizations/123456789/contacts/987654321"}'
```

### Terragrunt

Terragrunt runs the `source` module as the **root** module in its cache, so an
`import` block is legal there. Terragrunt can't write one directly, but it can
`generate` one into the generated root — see the runnable
[`examples/terragrunt`](examples/terragrunt). The generated file declares the
`import_contacts` variable and the `import` block, so nothing import-related
leaks into the module's published inputs. Note the `to` address has **no**
`module.` prefix here (the module is the root):

```hcl
generate "essential_contacts_import" {
  path      = "essential_contacts_import.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOT
    variable "import_contacts" { type = map(string) default = {} }

    import {
      for_each = var.import_contacts
      to       = google_essential_contacts_contact.this[each.key]
      id       = each.value
    }
  EOT
}

inputs = {
  import_contacts = {
    "organizations/123456789-security@example.com" = "organizations/123456789/contacts/987654321"
  }
}
```

## Testing

Tests use the native Terraform test framework with a mocked `google-beta`
provider — no GCP credentials or API calls required:

```bash
terraform init -backend=false
terraform test
```

The suite (`tests/essential_contacts.tftest.hcl`) covers flattening, the
`language_tag` and `deletion_policy` fallbacks/overrides, the empty-input no-op,
and every input validation (invalid parent, invalid/empty categories, `ALL`
exclusivity, invalid email, invalid deletion policy, invalid default language
tag and deletion policy).

## CI/CD

- **Pre-commit** (`.pre-commit-config.yaml`) runs `terraform fmt`,
  `terraform validate`, `tflint` and `terraform-docs` (README injection).
- **CI** (`.github/workflows/ci.yml`) runs on every **pull request** to `main`
  (and is reused as a release gate, see below):
  - `fmt` — `terraform fmt -check`
  - `validate` — `init` + `validate` on the module, `examples/basic` and
    `examples/with-import`, across the supported Terraform floor (`1.7.0`) and
    `latest` (the Terragrunt example is HCL config for Terragrunt and is not
    `terraform validate`-able)
  - `lint` — `tflint` with the GCP ruleset (`.tflint.hcl`)
  - `test` — `terraform test`
  - `docs` — fails if the README `terraform-docs` block is out of date
  - `security` — Trivy IaC misconfiguration scan (fails on HIGH/CRITICAL)
- **Release** (`.github/workflows/release.yml`) runs on **merge to `main`** and,
  in a single run:
  1. re-runs the full CI suite as a gate (never releases an untested `main`);
  2. runs [`release-it`](https://github.com/release-it/release-it) with the
     `@release-it/conventional-changelog` plugin (config in `.release-it.json`),
     which owns the whole release: it derives the next [SemVer](https://semver.org)
     from [Conventional Commits](https://www.conventionalcommits.org)
     (`feat:` → minor, `fix:`/`perf:` → patch, `!` / `BREAKING CHANGE` → major),
     creates and pushes the tag, and cuts a GitHub Release. The Terraform
     Registry ingests the release automatically.

  `release-it` runs on every merge with new commits; `git.requireCommits` makes
  it skip cleanly when nothing changed since the last tag. Note it does **not**
  skip docs/chore-only merges — those still cut a patch release. A run can also
  be triggered manually via `workflow_dispatch`. `release-it` is fetched on
  demand with `npx` (versions pinned in the workflow `env`); GitHub Actions are
  pinned to commit SHAs and kept current by Renovate
  (`helpers:pinGitHubActionDigests`). Notable changes are recorded in
  [CHANGELOG.md](CHANGELOG.md).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | >= 7.33 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google-beta"></a> [google-beta](#provider\_google-beta) | >= 7.33 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google-beta_google_essential_contacts_contact.this](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_essential_contacts_contact) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_default_deletion_policy"></a> [default\_deletion\_policy](#input\_default\_deletion\_policy) | Module-wide default for how Terraform treats deletion of a contact, applied<br/>when a contact omits 'deletion\_policy'. One of:<br/>  - DELETE:  destroying the resource deletes the contact (default).<br/>  - PREVENT: a destroy/apply that would delete the contact fails instead.<br/>  - ABANDON: the contact is removed from Terraform state without being<br/>             deleted in the API. | `string` | `"DELETE"` | no |
| <a name="input_default_language_tag"></a> [default\_language\_tag](#input\_default\_language\_tag) | Default preferred language for notifications (RFC 3066 / BCP 47 tag, e.g. "en-US") applied when a group omits 'language\_tag'. | `string` | `"en-US"` | no |
| <a name="input_essential_contacts"></a> [essential\_contacts](#input\_essential\_contacts) | Essential Contacts to manage, grouped by parent resource.<br/><br/>Each element targets one parent (organization, folder or project) and maps<br/>one or more contact email addresses to their configuration.<br/><br/>Attributes:<br/>  - parent:             Resource the contacts are attached to. One of<br/>                        "organizations/<id>", "folders/<id>" or<br/>                        "projects/<id-or-number>".<br/>  - essential\_contacts: Map of contact email address to an object:<br/>      - notification\_category\_subscriptions: List of notification categories<br/>          to subscribe to. Valid categories: ALL, SUSPENSION, SECURITY,<br/>          TECHNICAL, BILLING, LEGAL, PRODUCT\_UPDATES, TECHNICAL\_INCIDENTS.<br/>          "ALL" must be used on its own.<br/>      - deletion\_policy: Optional per-contact override of how Terraform<br/>          treats deletion (PREVENT, ABANDON or DELETE). Falls back to<br/>          var.default\_deletion\_policy when omitted.<br/>  - language\_tag:       Optional preferred language for notifications as an<br/>                        RFC 3066 / BCP 47 tag (e.g. "en-US"). Falls back to<br/>                        var.default\_language\_tag when omitted. | <pre>list(object({<br/>    parent = string<br/>    essential_contacts = map(object({<br/>      notification_category_subscriptions = list(string)<br/>      deletion_policy                     = optional(string)<br/>    }))<br/>    language_tag = optional(string)<br/>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_contact_names"></a> [contact\_names](#output\_contact\_names) | List of the fully-qualified resource names (e.g. "organizations/123/contacts/456") of the managed Essential Contacts. Useful for importing or referencing existing contacts. |
| <a name="output_essential_contacts"></a> [essential\_contacts](#output\_essential\_contacts) | Map of every managed Essential Contact, keyed by "<parent>-<email>", exposing the API resource details. |
<!-- END_TF_DOCS -->

## License

This module is licensed under the **Apache License 2.0** — see the
[LICENSE](LICENSE) and [NOTICE](NOTICE) files for details.

```
Copyright 2026 - YpNo

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
