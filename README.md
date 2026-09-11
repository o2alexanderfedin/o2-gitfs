# o2.gitfs

A git-oriented filesystem, by [O2.services](https://o2.services).

## Status

**Scaffold.** The repository structure, branching model and contribution
conventions are in place; the design and implementation are not yet written.

Nothing here is load-bearing yet — treat every decision below as revisable
until the first design document lands in `docs/`.

## Idea

Git's object store is content-addressed: every blob, tree and commit is named by
the hash of its contents, then zlib-compressed and periodically repacked with
delta compression. Those three operations — hashing, compression, delta
encoding — are exactly the kind of bulk, data-local work that does not need to
travel to the host CPU to be done.

`o2.gitfs` explores what a filesystem looks like when it is built around that
observation rather than adapted to it.

## Repository layout

| Path | Purpose |
|---|---|
| `docs/` | Design documents — the authoritative source once written |
| `.github/workflows/` | CI |
| `CHANGELOG.md` | Notable changes, [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format |
| `CLAUDE.md` | Guidelines for Claude Code sessions in this repository |

## Branching model

git-flow:

- `main` — released state
- `develop` — integration branch, base for day-to-day work
- `feature/*`, `chore/*`, `docs/*` — branched from and merged back into `develop`

`main` and `develop` are protected: direct commits are rejected locally by a
pre-commit hook and on GitHub by branch protection. Work goes through
`git flow`.

## Getting started

```bash
git clone https://github.com/o2alexanderfedin/o2-gitfs.git
cd o2-gitfs
git config core.hooksPath .githooks   # enable the protected-branch hook
git flow init -d                      # main / develop, default prefixes
git checkout develop
```

The `core.hooksPath` line is required once per clone: git deliberately does not
let a repository activate its own hooks, so a versioned hook still has to be
opted into. Skipping it costs you only the local guard — GitHub branch
protection still rejects pushes straight to `main` and `develop`.

Day-to-day:

```bash
git flow feature start <name>
# work, commit
git flow feature finish <name>       # merges into develop
```
