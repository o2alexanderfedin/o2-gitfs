#!/bin/bash
# Exercises .github/scripts/check-md-links.sh on throwaway Markdown trees.
# Usage: tests/check-md-links.test.sh   (exit status is the number of failures)
# Backticks in single quotes below are Markdown code, not command substitution.
# shellcheck disable=SC2016
set -u

CHECK="$(cd "$(dirname "$0")/.." && pwd)/.github/scripts/check-md-links.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
failures=0

# A tree holding docs/page.md with the given content, plus docs/present.md
# and "docs/with space.md".
new_tree() {
  local dir="$WORK/$1"
  mkdir -p "$dir/docs"
  echo present > "$dir/docs/present.md"
  echo present > "$dir/docs/with space.md"
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

# A target starting with / is relative to the repository root, as on GitHub.
expect "root-relative link to an existing file is clean" clean \
  "$(check "$(new_tree root-ok '[r](/docs/present.md)')")"

expect "root-relative link is not resolved from the file's directory" /present.md \
  "$(check "$(new_tree root-broken '[r](/present.md)')")"

# A link may carry a title after the target.
expect "link with a double-quoted title is clean" clean \
  "$(check "$(new_tree title-double '[t](present.md "The title")')")"

expect "link with a single-quoted title is clean" clean \
  "$(check "$(new_tree title-single "[t](present.md 'The title')")")"

expect "missing link with a title reports only the target" missing.md \
  "$(check "$(new_tree title-broken '[t](missing.md "The title")')")"

# <...> lets a target contain spaces.
expect "angle-bracket inline target is clean" clean \
  "$(check "$(new_tree angle-inline '[a](<with space.md>)')")"

expect "angle-bracket reference target is clean" clean \
  "$(check "$(new_tree angle-ref "$(printf '[a][ref]\n\n[ref]: <with space.md>')")")"

# %20 and other escapes name the decoded file.
expect "URL-encoded target is clean" clean \
  "$(check "$(new_tree encoded-ok '[e](with%20space.md)')")"

expect "missing URL-encoded target is reported as written" no%20such.md \
  "$(check "$(new_tree encoded-broken '[e](no%20such.md)')")"

# Code shows Markdown; it does not link.
expect "link inside a backtick fence is not checked" clean \
  "$(check "$(new_tree fence-backtick "$(printf '```md\n[m](missing.md)\n[r]: missing-ref.md\n```')")")"

expect "link inside a tilde fence is not checked" clean \
  "$(check "$(new_tree fence-tilde "$(printf '~~~\n[m](missing.md)\n~~~')")")"

expect "link after a closed fence is checked" missing.md \
  "$(check "$(new_tree fence-closed "$(printf '```\nx\n```\n[m](missing.md)')")")"

expect "link inside an inline code span is not checked" clean \
  "$(check "$(new_tree code-span 'Write `[m](missing.md)` to link.')")"

expect "link inside a double-backtick span holding a backtick is not checked" clean \
  "$(check "$(new_tree code-span-double 'Write ``a ` [m](missing.md)`` here.')")"

expect "link after a closed code span is checked" missing.md \
  "$(check "$(new_tree code-span-closed 'Run `ls` then read [m](missing.md).')")"

# A file the checker cannot read must fail the check, not pass it as clean.
unreadable="$(new_tree unreadable '[m](missing.md)')"
chmod 000 "$unreadable/docs/page.md"
expect "unreadable file fails the check" "status 2" \
  "$(check "$unreadable" | head -n 1 | cut -c1-8)"
chmod 644 "$unreadable/docs/page.md"

echo
echo "$failures failure(s)"
exit "$failures"
