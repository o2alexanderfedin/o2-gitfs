#!/bin/bash
# Reports relative links in Markdown files that point at nothing.
# Usage: .github/scripts/check-md-links.sh [root]   (default root: .)
# root is the repository root: links starting with / are resolved from it.
# Exits 1 if any link is broken, 2 if a file cannot be read, 0 otherwise.
set -u

root="${1:-.}"
broken=0
scheme='^[A-Za-z][A-Za-z0-9+.-]*:'

# Prints the Markdown file with code removed, so that example links in code
# are not checked. Code shows Markdown; it does not link.
# - Fenced blocks (``` and ~~~) and indented code blocks become empty lines.
# - Code spans are cut out; one may continue onto the next line of the same
#   paragraph, so text is kept until the paragraph ends and cut as a whole.
# - Inside a list item, lines are printed without the item's indentation, and
#   code there starts 4 columns past the item's text. Block-quote markers (>)
#   are removed.
# - A reference definition whose target is on the next line is joined into
#   one line: "[label]:" + "  target" -> "[label]: target".
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
    # Prints the paragraph kept so far, code spans cut out.
    function flush() {
      if (para != "") print spans(para)
      para = ""; last = ""
    }
    # Tabs in the indentation become spaces, to the next multiple of 4.
    function untab(s,    out, c) {
      out = ""
      while ((c = substr(s, 1, 1)) == " " || c == "\t") {
        out = out " "
        if (c == "\t") while (length(out) % 4) out = out " "
        s = substr(s, 2)
      }
      return out s
    }
    {
      line = $0; sub(/\r$/, "", line)          # CRLF line ends
      line = untab(line)
      while (match(line, /^ ? ? ?> ?/)) line = untab(substr(line, RLENGTH + 1))
      match(line, /^ */); ind = RLENGTH
      blank = (ind == length(line))
    }
    fence != "" {
      # Closed by the same character, at least as many times, nothing after.
      rel = substr(line, (ind < fbase ? ind : fbase) + 1)
      if (match(rel, /^ ? ? ?(```+|~~~+)[ \t]*$/)) {
        shut = substr(rel, RSTART, RLENGTH); gsub(/[ \t]/, "", shut)
        if (substr(shut, 1, 1) == substr(fence, 1, 1) && length(shut) >= length(fence))
          fence = ""
      }
      print ""; next
    }
    incode {
      if (blank || ind >= base + 4) { gap = gap || blank; print ""; next }
      incode = 0
    }
    blank { flush(); gap = 1; print ""; next }
    {
      # A list item ends at a line, after a blank one, indented less than its
      # text; a new item marker ends the items it is not nested in.
      item = (line ~ /^ *([-+*]|[0-9]+[.)])( |$)/) && !(line ~ /^ *([-*_] *)+$/)
      if (gap || item) while (depth > 0 && ind < stack[depth]) depth--
      gap = 0
      base = depth ? stack[depth] : 0
      if (para == "" && ind >= base + 4) { incode = 1; print ""; next }
      rel = ind >= base ? substr(line, base + 1) : substr(line, ind + 1)
    }
    match(rel, /^ ? ? ?(```+|~~~+)/) {
      open = substr(rel, RSTART, RLENGTH); sub(/^ */, "", open)
      # A ``` fence has no backtick after it; otherwise it is inline code.
      if (substr(open, 1, 1) == "~" || index(substr(rel, RSTART + RLENGTH), "`") == 0) {
        flush(); fence = open; fbase = base; print ""; next
      }
    }
    item && ind - base < 4 {
      flush()
      match(rel, /^ *([-+*]|[0-9]+[.)]) ?/); text = RLENGTH
      match(substr(rel, text + 1), /^ */)
      if (RLENGTH < 4 && text + RLENGTH < length(rel)) text += RLENGTH
      stack[++depth] = base + text
    }
    rel ~ /^ ? ? ?#+( |\t|$)/ || rel ~ /^ *([-*_] *)+$/ { flush(); print spans(rel); next }
    {
      # "[label]:" alone on its line takes its target from the next line.
      if (last ~ /^ ? ? ?\[[^]]*\]:[ \t]*$/) { sub(/^ */, "", rel); para = para " " rel }
      else para = (para == "" ? rel : para "\n" rel)
      last = rel
    }
    END { flush() }
  ' "$1"
}

# Prints the target of each inline link [text](target) in the text read from
# standard input, without its title; <target> keeps its angle brackets. The
# target may hold balanced or \-escaped parentheses, as in CommonMark;
# [t](a(b.md) has an unbalanced one and is plain text, not a link.
inline_targets() {
  awk '
    {
      s = $0
      while ((i = index(s, "](")) > 0) {
        s = substr(s, i + 2); sub(/^[ \t]*/, "", s)
        if (substr(s, 1, 1) == "<") {
          if ((j = index(s, ">")) > 0) print substr(s, 1, j)
          continue
        }
        target = ""; depth = 0; ok = 0
        for (k = 1; k <= length(s); k++) {
          c = substr(s, k, 1)
          if (c == "\\" && substr(s, k + 1, 1) ~ /[^A-Za-z0-9 ]/) {
            k++; target = target substr(s, k, 1); continue
          }
          if (c == " " || c == "\t") { ok = (depth == 0); break }
          if (c == "(") depth++
          else if (c == ")") { if (depth == 0) { ok = 1; break }; depth-- }
          target = target c
        }
        if (ok && target != "") print target
        s = substr(s, k)
      }
    }
  '
}

# Prints, as <value>, each href and src attribute value in HTML tags read from
# standard input: <a href="x.md">, <img src='y.png'>, <A HREF=z.md>.
html_targets() {
  local q="'"
  grep -oE '<[A-Za-z][^>]*>' \
    | grep -oE "[[:space:]]([Hh][Rr][Ee][Ff]|[Ss][Rr][Cc])[[:space:]]*=[[:space:]]*(\"[^\"]*\"|${q}[^$q]*$q|[^[:space:]\"$q>]+)" \
    | sed -E "s/^[^=]*=[[:space:]]*//; s/^[\"$q]//; s/[\"$q]\$//; s/.*/<&>/"
  return 0
}

# Prints the link targets in a Markdown file, with any <...> and title still
# attached, one per line.
# Inline links: [text](target)
# Reference definitions: [label]: target   (not footnotes, [^1]: text)
# HTML: href= and src= inside a tag, printed as <target> so that a space in
# the value does not cut it the way it cuts off a Markdown title.
targets() {
  local text
  text="$(prose "$1")" || return
  inline_targets <<<"$text"
  grep -oE '^ {0,3}\[[^]^][^]]*\]:[[:space:]]*(<[^>]*>|[^[:space:]]+)' <<<"$text" \
    | sed -E 's/^[^]]*\]:[[:space:]]*//'
  html_targets <<<"$text"
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
    # A URL ("scheme:" per RFC 3986: https:, mailto:, ftp:, tel:, ...) or an
    # anchor in this file: not a path.
    [[ $target =~ $scheme ]] && continue
    case "$target" in '#'*) continue ;; esac
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
