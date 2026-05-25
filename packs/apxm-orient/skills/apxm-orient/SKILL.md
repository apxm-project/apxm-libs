---
name: apxm-orient
description: Read-only project orientation. Run before any non-trivial APXM coding work — surfaces dekk doctor status, crate boundaries, and recent activity without making LLM calls.
fallback: native repo exploration
---

# APXM Orient

Use this skill at the start of an APXM session to ground yourself in the
current state of the workspace before touching code. It executes purely
deterministic introspection commands and returns a structured card —
no LLM calls, no side effects beyond reading the repo.

## When to use

- Starting a fresh session on the APXM monorepo (`apxm-project/apxm`).
- Returning to APXM after working in a companion repo for a while.
- Before any plan that touches more than one crate or subsystem.

## Inputs

- `focus_area` (optional): one of `compiler`, `runtime`, `server`,
  `frontend`, `eval`. Narrows the crate map and recent-activity summary.

## Output

A JSON card with:

- `doctor`: `dekk apxm doctor` status (pass/fail + key env vars).
- `crate_map`: workspace members grouped by `crates/{core,compiler,runtime,tools}/`.
- `recent_commits`: last 10 commits with type/scope/subject.
- `active_branch`: current branch + upstream divergence.
- `companion_repos`: sibling-clone status for `apxm-eval` and `apxm-libs`.

## Fallback

If `dekk apxm` is not on PATH, returns a partial card with what `git`
and filesystem reads can produce, plus a clear note about the missing
toolchain.
