# 🏗️ action-pulumi-build — Run Pulumi against engine repo

[![CI][ci-badge]][ci-url]
[![License: MIT][license-badge]][license-url]
[![GitHub Marketplace][marketplace-badge]][marketplace-url]

> **GitHub Action** to run a Pulumi command against an engine repository, overlaying the caller's stack config, and publish a report.

## Contents

- [Usage](#usage)
- [Inputs](#inputs)
- [Outputs](#outputs)
- [Permissions](#permissions)
- [Architecture](#architecture)
- [How it works](#how-it-works)
- [Notes](#notes)
- [License](#license)

Checks out a pinned ref of the Pulumi engine, overlays the caller's `Pulumi.yaml`, per-stack `Pulumi.<stack>.yaml`, and `environments/` onto it, installs dependencies with pnpm, then runs the requested command via `pulumi/actions`. Output is published as both a job summary and an uploaded artifact.

## Usage

```yaml
name: Deploy

on:
  workflow_dispatch:
    inputs:
      command:
        description: Pulumi command
        required: true
        default: preview
      environment:
        description: Stack name
        required: true
        default: sandbox

permissions:
  contents: read

jobs:
  cd:
    name: ${{ inputs.command }} | ${{ inputs.environment }}
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v7

      - uses: heronlabs/action-pulumi-build@v2
        with:
          command: ${{ inputs.command }}
          environment: ${{ inputs.environment }}
          engine-repo: my-org/my-engine
          engine-ref: v1.4.0
          pat: ${{ secrets.PAT }}
          pulumi-token: ${{ secrets.PULUMI_TOKEN }}
```

## Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `command` | Pulumi command to run (e.g. `preview`, `up`, `destroy`, `refresh`). | Yes | — |
| `environment` | Pulumi stack name to target (e.g. `production`, `sandbox`, `shared`). | Yes | — |
| `engine-repo` | Repository (`owner/name`) holding the Pulumi engine (program code, `package.json`, `.node-version`, pnpm lockfile). | Yes | — |
| `engine-ref` | Git ref (tag, branch, or SHA) of `engine-repo` to check out. | Yes | — |
| `pat` | GitHub PAT with read access to the engine repository. | Yes | — |
| `pulumi-token` | Pulumi access token (`PULUMI_ACCESS_TOKEN`) used to authenticate with the Pulumi backend. | Yes | — |

## Outputs

| Name | Description |
|------|-------------|
| `output` | Raw stdout from the Pulumi command. |

## Permissions

```yaml
permissions:
  contents: read
```

## Architecture

Bash shell scripts wrapped by a composite GitHub Action.

```
├── action.yml                    # Composite action definition
├── core/
│   ├── overlay-helm.sh           # Helm chart overlay
│   └── write-report.sh           # Pulumi report writer
├── tests/
│   ├── __mocks__/
│   │   └── stub.sh               # Test stub
│   └── action.bats               # BATS tests
├── Makefile                      # test (bats) + lint (shellcheck)
└── version.txt                   # Current version
```

## Notes

- Caller must `actions/checkout` its own repo first; `Pulumi.yaml`, `Pulumi.<stack>.yaml`, and `environments/` must exist at the workspace root, or the overlay hard-fails.
- `pat` needs read access to `engine-repo` — the default `GITHUB_TOKEN` cannot read other repositories.
- Engine is pinned via `engine-ref` for reproducible runs; bump it to adopt a new engine version.
- Node and pnpm versions come from the engine (`.node-version`, `pnpm-lock.yaml`), not the caller.
- A `pulumi-report.txt` artifact and matching job summary are written on `always()`, so the report is produced even when the Pulumi command fails.

## How it works

Composite action with two shell scripts:

1. **Overlay config** (`core/overlay-helm.sh`) — copies the caller's `Pulumi.yaml`, stack-specific `Pulumi.<stack>.yaml`, and `environments/` onto the checked-out engine.
2. **Run and report** — `pnpm/action-setup` and `actions/setup-node` install the engine's dependencies, `pulumi/actions` runs the command, and `core/write-report.sh` publishes results as both a job summary and an uploaded artifact.

## License

MIT

[ci-badge]: https://github.com/heronlabs/action-pulumi-build/actions/workflows/continuous-integration.yml/badge.svg
[ci-url]: https://github.com/heronlabs/action-pulumi-build/actions/workflows/continuous-integration.yml
[license-badge]: https://img.shields.io/badge/License-MIT-blue.svg
[license-url]: ./LICENSE
[marketplace-badge]: https://img.shields.io/badge/GitHub-Marketplace-green.svg
[marketplace-url]: https://github.com/marketplace/actions/action-pulumi-build
