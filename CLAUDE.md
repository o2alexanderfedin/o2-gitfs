# Claude Code Guidelines for o2.gitfs

## Project Context

o2.gitfs is a git-oriented filesystem. The premise is that git's object store is
content-addressed — hashing, compression and delta encoding dominate its write
path — and that this work is data-local by nature.

The repository is currently a scaffold. Once design documents exist under
`docs/`, they are authoritative: read them before proposing architecture
changes, and update them in the same change that alters behaviour.

## Branching

git-flow, enforced rather than advisory. `main` and `develop` reject direct
commits — locally through `.githooks/pre-commit`, and on GitHub through branch
protection.

Use `git flow feature start <name>` / `finish`, or the matching `release` and
`hotfix` commands. After cloning, install the hook once:
`cp .githooks/pre-commit .git/hooks/ && chmod +x .git/hooks/pre-commit`.
It goes in `.git/hooks/` rather than via `core.hooksPath` so that it applies on
every branch, including ones that do not carry `.githooks/`.

Never try to work around the hook with `--no-verify`; if a change genuinely
belongs on a protected branch, say so and let the human decide.

## Task Execution Strategy

Use subtasks (Task tool) with fresh context for investigation and research, and
run independent subtasks in parallel in a single message. Use map/reduce when
work touches independent files, then merge in one pass.

## Engineering Principles

SOLID, KISS, DRY, YAGNI. Prefer the simplest solution that satisfies the
requirement, and prefer existing, well-maintained libraries over bespoke
implementations.

Test-driven: write the failing test first, implement the minimum that makes it
pass, then refactor while it stays green.

## Verification Before Reporting

Do not report work as complete on the strength of reasoning alone. Build the
project, run the test suite, and quote the actual output. If something fails,
say so plainly along with the failing output — never "this should work".

## Changelog

Record notable changes in `CHANGELOG.md` under `[Unreleased]` as part of the
change itself, not afterwards.
