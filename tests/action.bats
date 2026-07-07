#!/usr/bin/env bats

# --- overlay tests ---
# bats tests for core/overlay-helm.sh
#
# Pure filesystem operations — no stubs needed. Each test builds a throwaway
# working dir, runs the script with cwd inside it, and asserts on resulting files.

setup() {
  OVERLAY="$BATS_TEST_DIRNAME/../core/overlay-helm.sh"
  WRITE_REPORT="$BATS_TEST_DIRNAME/../core/write-report.sh"
}

@test "overlay: happy path copies Pulumi yamls and environments to engine/" {
  local dir; dir="$(mktemp -d)"
  printf 'name: app\n'    >"$dir/Pulumi.yaml"
  printf 'config: dev\n'  >"$dir/Pulumi.dev.yaml"
  printf 'config: prod\n' >"$dir/Pulumi.prod.yaml"
  mkdir -p "$dir/environments" "$dir/engine"
  printf 'shared: true\n' >"$dir/environments/common.yaml"

  run bash -c "cd '$dir' && GITHUB_WORKSPACE='$dir' bash '$OVERLAY' 2>&1"

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

  run bash -c "cd '$dir' && GITHUB_WORKSPACE='$dir' bash '$OVERLAY' 2>&1"

  [ "$status" -ne 0 ]

  rm -rf "$dir"
}

@test "overlay: missing GITHUB_WORKSPACE is hard error" {
  local dir; dir="$(mktemp -d)"

  run bash -c "cd '$dir' && bash '$OVERLAY' 2>&1"

  [ "$status" -ne 0 ]

  rm -rf "$dir"
}

# --- report tests ---
# bats tests for core/write-report.sh
#
# Pure filesystem / tee operations — no stubs needed. Each test builds a
# throwaway working dir and asserts on pulumi-report.txt content and exit codes.

@test "report: happy path writes pulumi-report.txt and step summary" {
  local dir sum; dir="$(mktemp -d)"; sum="$(mktemp)"

  run bash -c "cd '$dir' && env COMMAND=preview ENVIRONMENT=dev GITHUB_STEP_SUMMARY='$sum' REPORT=\$'line1\nplan-output' bash '$WRITE_REPORT' 2>&1"

  [ "$status" -eq 0 ]
  [ -f "$dir/pulumi-report.txt" ]
  grep -Fq '## Pulumi preview — heronlabs / dev' "$dir/pulumi-report.txt"
  [ "$(grep -Fc '````' "$dir/pulumi-report.txt")" -eq 2 ]
  grep -Fq 'plan-output' "$dir/pulumi-report.txt"
  cmp -s "$dir/pulumi-report.txt" "$sum"

  rm -rf "$dir"; rm -f "$sum"
}

@test "report: empty REPORT still writes header and fenced block" {
  local dir sum; dir="$(mktemp -d)"; sum="$(mktemp)"

  run bash -c "cd '$dir' && env -u REPORT COMMAND=up ENVIRONMENT=prod GITHUB_STEP_SUMMARY='$sum' bash '$WRITE_REPORT' 2>&1"

  [ "$status" -eq 0 ]
  grep -Fq '## Pulumi up — heronlabs / prod' "$dir/pulumi-report.txt"
  [ "$(grep -Fc '````' "$dir/pulumi-report.txt")" -eq 2 ]

  rm -rf "$dir"; rm -f "$sum"
}

@test "report: missing COMMAND or GITHUB_STEP_SUMMARY is hard error" {
  local dir sum; dir="$(mktemp -d)"; sum="$(mktemp)"

  run bash -c "cd '$dir' && env -u COMMAND ENVIRONMENT=dev GITHUB_STEP_SUMMARY='$sum' REPORT=x bash '$WRITE_REPORT' 2>&1"
  [ "$status" -ne 0 ]

  run bash -c "cd '$dir' && env -u GITHUB_STEP_SUMMARY COMMAND=preview ENVIRONMENT=dev REPORT=x bash '$WRITE_REPORT' 2>&1"
  [ "$status" -ne 0 ]

  rm -rf "$dir"; rm -f "$sum"
}
