# Vision

> Software scaled when code became libraries. Agents will scale only
> when skills do — compiled, versioned, linkable, and governed.

`apxm-libs` is the compiled-skill library for APXM. It was born from
the APXM core repo so the pack catalog can evolve on its own release
cadence, independent of the AIS dialect, compiler, and runtime.

A **pack** is a versioned, install-as-a-unit bundle containing exactly
one skill (singleton model). Each pack carries provenance metadata
(`[source].kind = "original" | "port"`) on top of the upstream
`SkillManifest` contract from `apxm-project/apxm`.

## Two pack classes

- **APXM-development packs** — APXM-authored skills with no source
  prefix (`apxm-orient`, `apxm-plan-as-graph`).
- **obra/superpowers port packs** — community skills (MIT) re-expressed
  as typed AIR graphs, prefixed `obra-superpowers-<name>`. The original
  `SKILL.md` ships verbatim under `skills/<id>/upstream/`; the port adds
  the AIR graph, dispatch hints, cache-reuse groups, and traces that let
  the runtime fold redundant LLM calls and replay from intermediates.

## Why this lives outside APXM core

- The pack catalog grows on its own cadence (one pack at a time).
- Port packs carry upstream provenance and translation notes that don't
  belong in a runtime release.
- Maintainers can publish a new pack version without cutting an apxm
  core release.
- The validator + registry transport can iterate without affecting the
  compiler or runtime.

## Contract with APXM core

The `SkillManifest` contract — the shape of `skill.toml`, dispatch
hints, cache-reuse groups, the manifest loader — is owned by
`apxm-project/apxm` (the `apxm-skill` crate). This repo conforms to
that contract and layers `pack.toml` provenance on top. Schema
changes belong upstream, not here.

## Where the rest of this story lives

The full library-system thesis — Codex integration model, server
loading modes, runtime execution model, skill-conversion pipeline,
gap-closure backlog — is migrating into this docs tree from the apxm
core repo as part of the org-wide reorg. See:

- [`architecture.md`](architecture.md) — pack model, loading modes,
  runtime execution.
- [`integration-codex.md`](integration-codex.md) — Codex integration.
- [`integration-server.md`](integration-server.md) — `apxm-server`
  loader.
- [`integration-mcp.md`](integration-mcp.md) — MCP surface.
- [`manifests.md`](manifests.md) — pack + skill schemas.
- [`backlog.md`](backlog.md) — open gaps.
