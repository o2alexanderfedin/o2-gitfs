#!/bin/bash
# Reports relative links in Markdown files that point at nothing.
# Usage: .github/scripts/check-md-links.sh [root]   (default root: .)
# Exits 1 if any link is broken, 0 otherwise.
set -u

root="${1:-.}"
broken=0
while IFS= read -r md; do
  while IFS= read -r target; do
    [ -z "$target" ] && continue
    resolved="$(dirname "$md")/$target"
    if [ ! -e "$resolved" ]; then
      echo "::error file=$md::broken relative link: $target"
      broken=1
    fi
  done < <(
    # Extract link targets, drop URLs, anchors and mailto:
    # Inline links: [text](target)
    # Reference definitions: [label]: target   (not footnotes, [^1]: text)
    {
      grep -oE '\]\([^)]+\)' "$md" | sed -E 's/^\]\(//; s/\)$//'
      grep -oE '^ {0,3}\[[^]^][^]]*\]:[[:space:]]*<?[^[:space:]>]+' "$md" \
        | sed -E 's/^[^]]*\]:[[:space:]]*<?//'
    } \
      | grep -vE '^(https?:|mailto:|#)' \
      | sed -E 's/#.*$//'
  )
done < <(find "$root" -name '*.md' -not -path '*/.git/*')
exit $broken
