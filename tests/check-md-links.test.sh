#!/bin/bash
# Exercises .github/scripts/check-md-links.sh on throwaway Markdown trees.
# Usage: tests/check-md-links.test.sh   (exit status is the number of failures)
set -u

CHECK="$(cd "$(dirname "$0")/.." && pwd)/.github/scripts/check-md-links.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
failures=0

# A tree holding docs/page.md with the given content, plus docs/present.md.
new_tree() {
  local dir="$WORK/$1"
  mkdir -p "$dir/docs"
  echo present > "$dir/docs/present.md"
  printf '%s\n' "$2" > "$dir/docs/page.md"
  echo "$dir"
}

expect() {
  local name="$1" want="$2" got="$3"
  if [ "$want" = "$got" ]; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (wanted $want, got $got)"
    failures=$((failures + 1))
  fi
}

# Prints "clean", or the targets reported broken, space-separated. An exit
# status that disagrees with the report, or a crash, shows up as itself.
check() {
  local out status
  out="$("$CHECK" "$1" 2>&1)"
  status=$?
  if [ "$status" -eq 0 ] && [ -z "$out" ]; then echo clean; return; fi
  if [ "$status" -ne 1 ]; then echo "status $status: $out"; return; fi
  printf '%s\n' "$out" | sed -n 's/^::error file=.*::broken relative link: //p' | paste -sd' ' -
}

expect "inline link to an existing file is clean" clean \
  "$(check "$(new_tree inline-ok '[p](present.md)')")"

expect "inline link to a missing file is reported" missing.md \
  "$(check "$(new_tree inline-broken '[m](missing.md)')")"

expect "URLs, mailto and anchors are not checked" clean \
  "$(check "$(new_tree skipped '[u](https://example.com/x.md) [e](mailto:a@b.c) [a](#top)')")"

expect "anchor on an existing file is clean" clean \
  "$(check "$(new_tree anchor '[p](present.md#part)')")"

# A reference-style link names its target on a definition line of its own,
# with no parentheses. It is a relative link all the same.
expect "reference-style link to an existing file is clean" clean \
  "$(check "$(new_tree ref-ok "$(printf '[p][ref]\n\n[ref]: present.md')")")"

expect "reference-style link to a missing file is reported" missing-ref.md \
  "$(check "$(new_tree ref-broken "$(printf '[m][ref]\n\n[ref]: missing-ref.md')")")"

expect "reference-style URL is not checked" clean \
  "$(check "$(new_tree ref-url "$(printf '[u][ref]\n\n[ref]: https://example.com/x.md')")")"

expect "footnote definition is not a link" clean \
  "$(check "$(new_tree footnote "$(printf 'Text.[^1]\n\n[^1]: a note, not a path')")")"

echo
echo "$failures failure(s)"
exit "$failures"
