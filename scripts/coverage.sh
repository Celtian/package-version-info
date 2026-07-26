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

coverage_xml="$coverage_dir/merged/kcov-merged/cobertura.xml"

sed -i \
  's/ branch-rate="[^"]*" branches-covered="[^"]*" branches-rate="[^"]*"/ branch-rate="0" branches-covered="0" branches-valid="0"/' \
  "$coverage_xml"

line_rate=$(sed -n 's/^<coverage line-rate="\([^"]*\)".*/\1/p' "$coverage_xml")
test -n "$line_rate"

awk -v line_rate="$line_rate" 'BEGIN {
  minimum = 0.95
  printf "Line coverage: %.2f%% (minimum: %.2f%%)\n", line_rate * 100, minimum * 100
  if (line_rate < minimum) exit 1
}'
