#!/usr/bin/env bash
# Offline test harness for core/overlay-helm.sh and core/write-report.sh.
#
# Both scripts are pure filesystem / tee operations with no external CLI to stub,
# so each test builds a throwaway working dir (mktemp -d), runs the script with the
# cwd inside it (the scripts use relative paths like engine/ and pulumi-report.txt),
# and asserts on the resulting files / exit codes. No network, no real Pulumi.
#
# shellcheck disable=SC2015  # `cond && ok || bad` is intentional; ok() always returns 0
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERLAY="$HERE/../core/overlay-helm.sh"
WRITE_REPORT="$HERE/../core/write-report.sh"

pass=0
fail=0
note() { printf '  %s\n' "$*"; }
ok()   { pass=$((pass + 1)); printf 'ok   - %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf 'FAIL - %s\n' "$1"; [ -n "${2:-}" ] && note "$2"; }

# ---------------------------------------------------------------- overlay-helm.sh

test_overlay_happy_path() {
  local dir; dir="$(mktemp -d)"
  printf 'name: app\n'    >"$dir/Pulumi.yaml"
  printf 'config: dev\n'  >"$dir/Pulumi.dev.yaml"
  printf 'config: prod\n' >"$dir/Pulumi.prod.yaml"
  mkdir -p "$dir/environments" "$dir/engine"
  printf 'shared: true\n' >"$dir/environments/common.yaml"

  local out rc
  out="$(cd "$dir" && bash "$OVERLAY" 2>&1)"; rc=$?

  [ "$rc" -eq 0 ] && ok "overlay: exit 0 on happy path" || bad "overlay: exit 0 on happy path" "rc=$rc out=$out"
  cmp -s "$dir/Pulumi.yaml"      "$dir/engine/Pulumi.yaml"      && ok "overlay: Pulumi.yaml copied to engine"      || bad "overlay: Pulumi.yaml copied to engine"
  cmp -s "$dir/Pulumi.dev.yaml"  "$dir/engine/Pulumi.dev.yaml"  && ok "overlay: Pulumi.dev.yaml copied to engine"  || bad "overlay: Pulumi.dev.yaml copied to engine"
  cmp -s "$dir/Pulumi.prod.yaml" "$dir/engine/Pulumi.prod.yaml" && ok "overlay: Pulumi.prod.yaml copied to engine" || bad "overlay: Pulumi.prod.yaml copied to engine"
  cmp -s "$dir/environments/common.yaml" "$dir/engine/environments/common.yaml" && ok "overlay: environments/ copied to engine" || bad "overlay: environments/ copied to engine"

  rm -rf "$dir"
}

test_overlay_missing_config_hard_error() {
  local dir; dir="$(mktemp -d)"
  mkdir -p "$dir/engine"

  local out rc
  out="$(cd "$dir" && bash "$OVERLAY" 2>&1)"; rc=$?

  [ "$rc" -ne 0 ] && ok "overlay: hard error when Pulumi.yaml missing" || bad "overlay: hard error when Pulumi.yaml missing" "rc=$rc out=$out"

  rm -rf "$dir"
}

# ---------------------------------------------------------------- write-report.sh

test_report_happy_path() {
  local dir sum; dir="$(mktemp -d)"; sum="$(mktemp)"

  local out rc
  out="$(cd "$dir" && env COMMAND=preview ENVIRONMENT=dev GITHUB_STEP_SUMMARY="$sum" REPORT=$'line1\nplan-output' bash "$WRITE_REPORT" 2>&1)"; rc=$?

  [ "$rc" -eq 0 ] && ok "report: exit 0 on happy path" || bad "report: exit 0 on happy path" "rc=$rc out=$out"
  [ -f "$dir/pulumi-report.txt" ] && ok "report: pulumi-report.txt written in cwd" || bad "report: pulumi-report.txt written in cwd"
  grep -Fq '## Pulumi preview — heronlabs / dev' "$dir/pulumi-report.txt" && ok "report: header line present" || bad "report: header line present" "$(cat "$dir/pulumi-report.txt")"
  [ "$(grep -Fc '````' "$dir/pulumi-report.txt")" -eq 2 ] && ok "report: body wrapped in a fenced block" || bad "report: body wrapped in a fenced block" "$(cat "$dir/pulumi-report.txt")"
  grep -Fq 'plan-output' "$dir/pulumi-report.txt" && ok "report: report body present inside fence" || bad "report: report body present inside fence" "$(cat "$dir/pulumi-report.txt")"
  cmp -s "$dir/pulumi-report.txt" "$sum" && ok "report: tee appended identical content to step summary" || bad "report: tee appended identical content to step summary"

  rm -rf "$dir"; rm -f "$sum"
}

test_report_empty_report() {
  local dir sum; dir="$(mktemp -d)"; sum="$(mktemp)"

  local out rc
  out="$(cd "$dir" && env -u REPORT COMMAND=up ENVIRONMENT=prod GITHUB_STEP_SUMMARY="$sum" bash "$WRITE_REPORT" 2>&1)"; rc=$?

  [ "$rc" -eq 0 ] && ok "report(empty): exit 0 when REPORT unset" || bad "report(empty): exit 0 when REPORT unset" "rc=$rc out=$out"
  grep -Fq '## Pulumi up — heronlabs / prod' "$dir/pulumi-report.txt" && ok "report(empty): header line present" || bad "report(empty): header line present" "$(cat "$dir/pulumi-report.txt")"
  [ "$(grep -Fc '````' "$dir/pulumi-report.txt")" -eq 2 ] && ok "report(empty): fenced block still present" || bad "report(empty): fenced block still present" "$(cat "$dir/pulumi-report.txt")"

  rm -rf "$dir"; rm -f "$sum"
}

test_report_missing_env_hard_error() {
  local dir sum; dir="$(mktemp -d)"; sum="$(mktemp)"

  local out rc
  out="$(cd "$dir" && env -u COMMAND ENVIRONMENT=dev GITHUB_STEP_SUMMARY="$sum" REPORT=x bash "$WRITE_REPORT" 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] && ok "report: hard error when COMMAND unset" || bad "report: hard error when COMMAND unset" "rc=$rc out=$out"

  out="$(cd "$dir" && env -u GITHUB_STEP_SUMMARY COMMAND=preview ENVIRONMENT=dev REPORT=x bash "$WRITE_REPORT" 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] && ok "report: hard error when GITHUB_STEP_SUMMARY unset" || bad "report: hard error when GITHUB_STEP_SUMMARY unset" "rc=$rc out=$out"

  rm -rf "$dir"; rm -f "$sum"
}

# ---------------------------------------------------------------- run

test_overlay_happy_path
test_overlay_missing_config_hard_error
test_report_happy_path
test_report_empty_report
test_report_missing_env_hard_error

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
