# Changelog

All notable changes to o2.gitfs are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Initial repository scaffold: README, changelog, Claude Code guidelines,
  `.gitignore`, and a CI workflow that checks repository hygiene.
- git-flow branching model (`main` / `develop`).
- git-flow initialised (`gitflow.branch.master = main`) and enforcement of it:
  a versioned `.githooks/pre-commit` rejecting direct commits to `main` and
  `develop`, plus GitHub branch protection on both.
