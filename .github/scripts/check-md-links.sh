#!/bin/bash
# Reports relative links in Markdown files that point at nothing.
# Usage: .github/scripts/check-md-links.sh [root]   (default root: .)
# root is the repository root: links starting with / are resolved from it.
# Exits 1 if any link is broken, 2 if a file cannot be read, 0 otherwise.
set -u

root="${1:-.}"
broken=0

# Prints the Markdown file with code removed: fenced blocks (``` and ~~~) become
# empty lines and inline code spans are cut out. Code shows Markdown; it does
# not link.
prose() {
  awk '
    # Removes `code` and ``co`de`` spans: a run of backticks up to the next
    # run of the same length. A run with no partner is kept as text.
    function spans(s,    out, run, rest, scan, used, found) {
      out = ""
      while (match(s, /`+/)) {
        out = out substr(s, 1, RSTART - 1)
        run = RLENGTH; rest = substr(s, RSTART + RLENGTH)
        scan = rest; used = 0; found = 0
        while (match(scan, /`+/)) {
          used += RSTART + RLENGTH - 1
          if (RLENGTH == run) { found = 1; break }
          scan = substr(scan, RSTART + RLENGTH)
        }
        if (found) { s = substr(rest, used + 1) }
        else { out = out substr(s, RSTART, run); s = rest }
      }
      return out s
    }
    fence == "" && match($0, /^ ? ? ?(```+|~~~+)/) {
      open = substr($0, RSTART, RLENGTH); sub(/^ */, "", open)
      # A ``` fence has no backtick after it; otherwise it is inline code.
      if (substr(open, 1, 1) == "~" || index(substr($0, RSTART + RLENGTH), "`") == 0) {
        fence = open; print ""; next
      }
    }
    fence != "" {
      # Closed by the same character, at least as many times, nothing after.
      if (match($0, /^ ? ? ?(```+|~~~+)[ \t]*$/)) {
        shut = substr($0, RSTART, RLENGTH); gsub(/[ \t]/, "", shut)
        if (substr(shut, 1, 1) == substr(fence, 1, 1) && length(shut) >= length(fence))
          fence = ""
      }
      print ""; next
    }
    { print spans($0) }
  ' "$1"
}

# Prints the link targets in a Markdown file, with any <...> and title still
# attached, one per line.
# Inline links: [text](target)
# Reference definitions: [label]: target   (not footnotes, [^1]: text)
targets() {
  local text
  text="$(prose "$1")" || return
  grep -oE '\]\([^)]+\)' <<<"$text" | sed -E 's/^\]\(//; s/\)$//'
  grep -oE '^ {0,3}\[[^]^][^]]*\]:[[:space:]]*(<[^>]*>|[^[:space:]]+)' <<<"$text" \
    | sed -E 's/^[^]]*\]:[[:space:]]*//'
  return 0
}

while IFS= read -r md; do
  if ! list="$(targets "$md")"; then
    echo "::error file=$md::could not read the file"
    exit 2
  fi
  while IFS= read -r target; do
    case "$target" in
      '<'*'>'*) target="${target#<}"; target="${target%%>*}" ;;  # <a b.md>
      *) target="${target%%[[:space:]]*}" ;;   # drop a title: [t](path "Title")
    esac
    case "$target" in https:* | http:* | mailto:* | '#'*) continue ;; esac
    target="${target%%#*}"
    [ -z "$target" ] && continue
    path="$(printf '%b' "${target//%/\\x}")"   # with%20space.md -> with space.md
    case "$path" in
      /*) resolved="$root$path" ;;              # from the repository root
      *) resolved="$(dirname "$md")/$path" ;;   # from the file's directory
    esac
    if [ ! -e "$resolved" ]; then
      echo "::error file=$md::broken relative link: $target"
      broken=1
    fi
  done <<<"$list"
done < <(find "$root" -name '*.md' -not -path '*/.git/*')
exit $broken
