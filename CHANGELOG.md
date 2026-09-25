# Changelog

All notable changes to o2.gitfs are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed

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
