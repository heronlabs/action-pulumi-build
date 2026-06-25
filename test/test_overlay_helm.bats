#!/usr/bin/env bats
# bats tests for core/overlay-helm.sh
#
# Pure filesystem operations — no stubs needed. Each test builds a throwaway
# working dir, runs the script with cwd inside it, and asserts on resulting files.

setup() {
  OVERLAY="$BATS_TEST_DIRNAME/../core/overlay-helm.sh"
}

@test "overlay: happy path copies Pulumi yamls and environments to engine/" {
  local dir; dir="$(mktemp -d)"
  printf 'name: app\n'    >"$dir/Pulumi.yaml"
  printf 'config: dev\n'  >"$dir/Pulumi.dev.yaml"
  printf 'config: prod\n' >"$dir/Pulumi.prod.yaml"
  mkdir -p "$dir/environments" "$dir/engine"
  printf 'shared: true\n' >"$dir/environments/common.yaml"

  run bash -c "cd '$dir' && bash '$OVERLAY' 2>&1"

  [ "$status" -eq 0 ]
  cmp -s "$dir/Pulumi.yaml"      "$dir/engine/Pulumi.yaml"
  cmp -s "$dir/Pulumi.dev.yaml"  "$dir/engine/Pulumi.dev.yaml"
  cmp -s "$dir/Pulumi.prod.yaml" "$dir/engine/Pulumi.prod.yaml"
  cmp -s "$dir/environments/common.yaml" "$dir/engine/environments/common.yaml"

  rm -rf "$dir"
}

@test "overlay: missing Pulumi.yaml is hard error" {
  local dir; dir="$(mktemp -d)"
  mkdir -p "$dir/engine"

  run bash -c "cd '$dir' && bash '$OVERLAY' 2>&1"

  [ "$status" -ne 0 ]

  rm -rf "$dir"
}
