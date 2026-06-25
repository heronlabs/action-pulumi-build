#!/usr/bin/env bats
# bats tests for core/write-report.sh
#
# Pure filesystem / tee operations — no stubs needed. Each test builds a
# throwaway working dir and asserts on pulumi-report.txt content and exit codes.

setup() {
  WRITE_REPORT="$BATS_TEST_DIRNAME/../core/write-report.sh"
}

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
