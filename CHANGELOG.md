# Changelog

All notable changes to o2.gitfs are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed

- The Markdown link check no longer reports links with schemes other than
  http, https and mailto (such as `ftp:` or `tel:`) as broken files. It now
  also checks links written in HTML (`<a href>`, `<img src>`); before, a
  broken one passed without notice.
- The Markdown link check no longer reports valid links as broken when they
  start with `/` (resolved from the repository root, as on GitHub), carry a
  title (`[t](b.md "Title")`), use `<...>` around the target, or use URL
  escapes such as `%20`. Links inside fenced code blocks and inline code are
  no longer checked. A file the check cannot read now fails it instead of
  passing as having no links.
- CI now checks reference-style Markdown links (`[label]: path`). Before, a
  broken one passed the "Relative links in Markdown resolve" step, so readers
  got a dead link that CI had reported as fine. The check moved to
  `.github/scripts/check-md-links.sh`, covered by
  `tests/check-md-links.test.sh`; it no longer keeps state in `/tmp`.
- The pre-commit hook no longer rejects the commit that concludes a conflicted
  merge into `develop` or `main`. `git flow feature finish` (and `release` /
  `hotfix`) stopped on a conflict could only be completed with `--no-verify`.
  Covered by `tests/pre-commit.test.sh`, now run in CI with shellcheck.

## [0.1.0] — 2026-09-10

### Added

- Initial repository scaffold: README, changelog, Claude Code guidelines,
  `.gitignore`, and a CI workflow that checks repository hygiene.
- git-flow branching model (`main` / `develop`).
- git-flow initialised (`gitflow.branch.master = main`) and enforcement of it:
  a versioned `.githooks/pre-commit` rejecting direct commits to `main` and
  `develop`, plus GitHub branch protection on both.
