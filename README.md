# Pulumi Build Action

[![CI](https://github.com/heronlabs/action-pulumi-build/actions/workflows/ci.yml/badge.svg)](https://github.com/heronlabs/action-pulumi-build/actions/workflows/ci.yml)

> Run a Pulumi command against an engine repository, overlaying the caller's stack config, and publish a report.

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
      - uses: actions/checkout@v6

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

## Notes

- Caller must `actions/checkout` its own repo first; `Pulumi.yaml`, `Pulumi.<stack>.yaml`, and `environments/` must exist at the workspace root, or the overlay hard-fails.
- `pat` needs read access to `engine-repo` — the default `GITHUB_TOKEN` cannot read other repositories.
- Engine is pinned via `engine-ref` for reproducible runs; bump it to adopt a new engine version.
- Node and pnpm versions come from the engine (`.node-version`, `pnpm-lock.yaml`), not the caller.
- A `pulumi-report.txt` artifact and matching job summary are written on `always()`, so the report is produced even when the Pulumi command fails.

## License

MIT
