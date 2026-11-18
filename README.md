# Stet GitHub Action: guardrails for AI coding agents

[![guarded by stet](https://img.shields.io/badge/guarded%20by-stet-FFF01F?labelColor=0E1116)](https://getstet.dev)

Fail pull requests where an AI coding agent (Claude Code, Cursor, Codex, Copilot, ChatGPT…) changed files outside the agreed task, touched protected paths, or broke a locked behaviour. Runs [Stet](https://getstet.dev) (`stet guard` and `stet check`) and writes the results to the job summary.

## Setup

1. In your repo, run `npx stet-cli init`, set protected paths in `.stet/config.json`, lock what must keep working (`stet lock add`), and commit `.stet/`, `AGENTS.md` and `CLAUDE.md`.
2. Add `.github/workflows/stet.yml`:

```yaml
name: Stet
on:
  pull_request:
  push:
    branches: [main]

jobs:
  stet:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0          # Stet compares against the merge base
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci               # locks run your own tests, so install dependencies first
      - uses: shamazkhan/stet-action@v1
```

## What it checks

| Check | Fails when |
|---|---|
| **Guard** | A file changed in protected paths (`.stet/config.json` → `protect`), outside the scope committed in `.stet/scope.json`, or an approved snapshot was edited by hand. |
| **Check** | A locked behaviour fails: a command that proves a feature works, or a snapshot whose output changed. |

On a pull request the comparison is against the merge base with the target branch, so only the PR's own changes count.

## Inputs

| Input | Default | |
|---|---|---|
| `guard` | `true` | Run `stet guard`. |
| `check` | `true` | Run `stet check`. |
| `warn-only` | `false` | Report guard violations as warnings instead of failing. |
| `pr-format` | `false` | On pull requests, fail when the PR description doesn't follow the format from `stet pr` (missing sections, unwritten "What and why", removed footer). Needs stet-cli 0.7.0+. |
| `only` | | Run only these locks, e.g. `L1,L3`. |
| `base` | merge base | Commit or branch to compare against. |
| `version` | `latest` | `stet-cli` version. |
| `node-version` | `20` | Node.js 18+. |
| `working-directory` | `.` | Folder containing `.stet/` (monorepos). |

Output `result`: `pass`, `guard-failed`, `check-failed` or `failed`.

## Examples

Guard only, as a warning while you adopt it:

```yaml
      - uses: shamazkhan/stet-action@v1
        with:
          check: false
          warn-only: true
```

Monorepo package:

```yaml
      - uses: shamazkhan/stet-action@v1
        with:
          working-directory: apps/web
```

## Privacy

Everything runs inside your GitHub runner. Stet has no account and no telemetry, and your code is not sent anywhere.

## Links

[getstet.dev](https://getstet.dev) · [Stet CLI](https://github.com/shamazkhan/stet) · [Guides](https://getstet.dev/guides/index.html) · MIT licence
