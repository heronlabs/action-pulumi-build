#!/usr/bin/env bash

set -euo pipefail

: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}"

# Overlay the caller's stack configuration (from the checked-out workspace root)
# onto the engine so Pulumi resolves Pulumi.yaml, the per-stack Pulumi.<stack>.yaml
# files, and environments/ from the caller rather than the engine's defaults.
cp -v Pulumi.yaml Pulumi.*.yaml engine/
cp -rv environments engine/
