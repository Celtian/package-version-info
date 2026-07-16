#!/bin/sh

set -eu

workspace=$(pwd)
coverage_dir="$workspace/coverage"
tests_dir="$workspace/zig-out/coverage-tests"

rm -rf "$coverage_dir"
mkdir -p "$coverage_dir/root" "$coverage_dir/cli" "$coverage_dir/merged"

kcov \
  --include-path="$workspace/src" \
  "$coverage_dir/root" \
  "$tests_dir/root-coverage"

kcov \
  --include-path="$workspace/src" \
  "$coverage_dir/cli" \
  "$tests_dir/cli-coverage"

kcov \
  --merge \
  "$coverage_dir/merged" \
  "$coverage_dir/root" \
  "$coverage_dir/cli"
