# Google Cloud - Essential Contacts Module

[![CI](https://github.com/YpNo/terraform-google-essential-contacts/actions/workflows/ci.yml/badge.svg)](https://github.com/YpNo/terraform-google-essential-contacts/actions/workflows/ci.yml)
[![Latest Release](https://img.shields.io/github/v/release/YpNo/terraform-google-essential-contacts?sort=semver&logo=github)](https://github.com/YpNo/terraform-google-essential-contacts/releases)
[![Terraform Registry](https://img.shields.io/badge/terraform-registry-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/modules/YpNo/essential-contacts/google/latest)
[![Terraform](https://img.shields.io/badge/terraform-%3E%3D_1.7.0-7B42BC?logo=terraform&logoColor=white)](https://developer.hashicorp.com/terraform/install)
[![Provider](https://img.shields.io/badge/google--beta-%3E%3D_4.62-4285F4?logo=googlecloud&logoColor=white)](https://registry.terraform.io/providers/hashicorp/google-beta/latest)
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
  categories, `ALL` exclusivity, duplicates) so misconfiguration fails fast
  rather than at the GCP API.
- `language_tag` defaults are configurable and applied per group.

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

- Terraform `>= 1.7.0` (the module uses `for_each` on `import` blocks).
- A configured `google-beta` provider with permission to manage Essential
  Contacts on each targeted parent (role
  `roles/essentialcontacts.admin` or equivalent).
- The Essential Contacts API (`essentialcontacts.googleapis.com`) enabled.

## Usage

```hcl
provider "google-beta" {}

module "essential_contacts" {
  source  = "YpNo/essential-contacts/google"
  version = "~> 0.1"

  # Optional, defaults to "en-US"
  default_language_tag = "en-US"

  essential_contacts = [
    {
      parent = "organizations/123456789"
      essential_contacts = {
        "all@example.com"      = ["ALL"]
        "security@example.com" = ["SECURITY", "LEGAL"]
      }
    },
    {
      parent = "folders/469120895423"
      essential_contacts = {
        "infrastructure@example.com" = ["SECURITY", "TECHNICAL", "TECHNICAL_INCIDENTS", "PRODUCT_UPDATES"]
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
        "ypno.gh+security@gmail.com" = ["SECURITY", "LEGAL"]
      }
    },
  ]
}
```

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

## Importing existing contacts

The module imports pre-existing contacts declaratively via the
`import_contacts` variable — no manual `terraform import` commands or hand-edited
`import` blocks required. The module renders a `for_each` `import` block from the
map, so imports are reproducible and survive across runs.

1. List the existing contacts and their IDs:

   ```bash
   gcloud beta essential-contacts list --organization=123456789
   ```

   Contact names look like `organizations/123456789/contacts/987654321`.

2. Declare the contact in `essential_contacts` (so it stays managed) **and** map
   its instance key to its resource name in `import_contacts`:

   ```hcl
   module "essential_contacts" {
     source  = "YpNo/essential-contacts/google"
     version = "~> 0.1"

     essential_contacts = [
       {
         parent             = "organizations/123456789"
         essential_contacts = { "security@example.com" = ["SECURITY"] }
       },
     ]

     import_contacts = {
       # "<parent>-<email>" => "<parent>/contacts/<contact_id>"
       "organizations/123456789-security@example.com" = "organizations/123456789/contacts/987654321"
     }
   }
   ```

3. Run `terraform plan` to preview the import, then `terraform apply`. Once
   applied, the entry can be removed from `import_contacts` — the contact stays
   managed through `essential_contacts`.

The instance key is always `"<parent>-<email>"`, and every key in
`import_contacts` must also be declared in `essential_contacts`.

## Testing

Tests use the native Terraform test framework with a mocked `google-beta`
provider — no GCP credentials or API calls required:

```bash
terraform init -backend=false
terraform test
```

The suite (`tests/essential_contacts.tftest.hcl`) covers flattening, the
`language_tag` fallback, the empty-input no-op, declarative import (via an
`override_resource` stand-in for the mock provider), and every input validation
(invalid parent, invalid/empty categories, `ALL` exclusivity, invalid email,
invalid default language tag, malformed import ID).

## CI/CD

- **Pre-commit** (`.pre-commit-config.yaml`) runs `terraform fmt`,
  `terraform validate`, `tflint` and `terraform-docs` (README injection).
- **GitHub Actions** (`.github/workflows/ci.yml`) runs on every push and PR to
  `main`:
  - `fmt` — `terraform fmt -check`
  - `validate` — `init` + `validate` on the module and `examples/basic`, across
    the supported Terraform floor (`1.7.0`) and `latest`
  - `lint` — `tflint` with the GCP ruleset (`.tflint.hcl`)
  - `test` — `terraform test`
  - `docs` — fails if the README `terraform-docs` block is out of date
  - `security` — Trivy IaC misconfiguration scan (fails on HIGH/CRITICAL)

  All actions are pinned to commit SHAs and kept current by Renovate
  (`helpers:pinGitHubActionDigests`).
- Releases follow [Semantic Versioning](https://semver.org); see
  [CHANGELOG.md](CHANGELOG.md).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | >= 4.62 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google-beta"></a> [google-beta](#provider\_google-beta) | >= 4.62 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google-beta_google_essential_contacts_contact.this](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_essential_contacts_contact) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_default_language_tag"></a> [default\_language\_tag](#input\_default\_language\_tag) | Default preferred language for notifications (RFC 3066 / BCP 47 tag, e.g. "en-US") applied when a group omits 'language\_tag'. | `string` | `"en-US"` | no |
| <a name="input_essential_contacts"></a> [essential\_contacts](#input\_essential\_contacts) | Essential Contacts to manage, grouped by parent resource.<br/><br/>Each element targets one parent (organization, folder or project) and maps<br/>one or more contact email addresses to the notification categories they<br/>should be subscribed to.<br/><br/>Attributes:<br/>  - parent:             Resource the contacts are attached to. One of<br/>                        "organizations/<id>", "folders/<id>" or<br/>                        "projects/<id-or-number>".<br/>  - essential\_contacts: Map of contact email address to the list of<br/>                        notification categories to subscribe to. Valid<br/>                        categories: ALL, SUSPENSION, SECURITY, TECHNICAL,<br/>                        BILLING, LEGAL, PRODUCT\_UPDATES, TECHNICAL\_INCIDENTS.<br/>                        "ALL" must be used on its own.<br/>  - language\_tag:       Optional preferred language for notifications as an<br/>                        RFC 3066 / BCP 47 tag (e.g. "en-US"). Falls back to<br/>                        var.default\_language\_tag when omitted. | <pre>list(object({<br/>    parent             = string<br/>    essential_contacts = map(list(string))<br/>    language_tag       = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_import_contacts"></a> [import\_contacts](#input\_import\_contacts) | Pre-existing Essential Contacts to import into Terraform state, declared as a<br/>map of "<parent>-<email>" (the resource instance key, which must also be<br/>declared in var.essential\_contacts) to the contact's fully-qualified<br/>resource name ("<parent>/contacts/<contact\_id>").<br/><br/>Discover existing contacts and their IDs with, e.g.:<br/>  gcloud beta essential-contacts list --organization=<org\_id><br/><br/>Each listed contact is imported via a dynamic `import` block, so the import<br/>is declarative and survives `terraform plan`/`apply` runs. Requires<br/>Terraform >= 1.7 (for\_each on import blocks). | `map(string)` | `{}` | no |

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
Copyright 2026 YpNo

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
