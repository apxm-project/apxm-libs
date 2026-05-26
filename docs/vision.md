# Vision

> Software scaled when code became libraries. Agents will scale only
> when skills do — compiled, versioned, linkable, and governed.

`apxm-libs` is the compiled-skill library for APXM. It was born from
the APXM core repo so the pack catalog can evolve on its own release
cadence, independent of the AIS dialect, compiler, and runtime.

## What this doc owns

This page states the thesis behind `apxm-libs`, names the contract
boundary with APXM core, and points the reader at the sibling docs
that implement each piece. The substance of the architecture lives in
[`architecture.md`](architecture.md); the integration surfaces with
specific consumers (Codex, `apxm-server`, MCP) live in their own
`integration-*.md` files.

## The fragmented-skills problem

In every team running agents in production, the same scene repeats:
each team encodes the same processes as a slightly different "skill",
with no shared compiled object, no shared optimizer, and no shared
governance. A `SKILL.md` file is useful to a host agent, but the host
still interprets the prose ad hoc — there is no IR, no validator, no
artifact format, and no replayable execution.

APXM exists because agent systems need the same shared infrastructure
that classical software systems built: a clean IR, modular optimization
passes, portable artifacts, and an open runtime contract. Skills are
the right pressure test for that thesis. The APXM form of a skill is:

- The source package remains a readable `SKILL.md` that any agent can
  consume directly.
- The APXM form lowers the skill into typed AIR (the AIS dialect from
  APXM core).
- The compiler validates and optimizes the skill graph.
- The runtime executes it with explicit capabilities, sessions,
  metrics, and inspectable traces.
- The server exposes the catalog so Codex, the GUI, MCP clients, and
  other agents see the same inventory by manifest identity instead of
  copying prose into each host.

`apxm-libs` is where the catalog of packs that conform to this contract
is curated and shipped.

## Two pack classes

A **pack** is a versioned, install-as-a-unit bundle that contains
exactly one skill (the v1 singleton model — see
[`architecture.md`](architecture.md) for why the wire format already
permits more and v1 deliberately doesn't). Every pack carries
provenance metadata on top of the upstream `SkillManifest` contract.

- **APXM-development packs** — APXM-authored skills with no source
  prefix (`apxm-orient`, `apxm-plan-as-graph`,
  `apxm-compiler-pass`, ...). These cover working *on* APXM itself:
  orientation, compiler pass authoring, runtime/backend work, server
  and MCP surface changes, quality eval, demos, design docs.
  `[source].kind = "original"` in `pack.toml`.

- **obra/superpowers port packs** — community skills (MIT, from
  `github.com/obra/superpowers`) re-expressed as typed AIR graphs.
  Prefixed `obra-superpowers-<name>`. The original `SKILL.md` ships
  verbatim under `skills/<id>/upstream/`; the port adds the AIR graph,
  dispatch hints, cache-reuse groups, and session traces that let the
  runtime fold redundant LLM calls and replay from intermediates.
  `[source].kind = "port"` in `pack.toml`, with `upstream`,
  `upstream_path`, `upstream_commit`, and `upstream_license`.

The full pack catalog ships at
[github.com/apxm-project/apxm-libs/tree/main/packs](https://github.com/apxm-project/apxm-libs/tree/main/packs).

## Contract with APXM core

The relationship between the two repos is unambiguous: **APXM core
defines the contract; `apxm-libs` is the conforming library.**

What lives upstream in `apxm-project/apxm` and is consumed here:

- The `SkillManifest` schema, parser, hash chain, and validation
  primitives — `crates/core/apxm-skill/src/lib.rs` in the apxm core
  repo.
- The compiled wire format (`.apxmobj`, the `ArtifactPayload`
  envelope, typed `ArtifactSection`s) —
  `crates/orchestration/apxm-artifact/`.
- The pass pipeline that lowers `skill.air` to `.apxmobj` —
  `crates/compiler/apxm-compiler/`.
- The runtime that loads, validates, admits, and executes packs —
  `crates/runtime/apxm-runtime/` and `crates/tools/apxm-server/`.
- The dispatch-hint attribute taxonomy (cache-reuse groups, pin
  groups, priority lanes) — `crates/core/apxm-core/`.

What lives in `apxm-libs` and is produced here:

- The pack format (`pack.toml`, `[source].kind`, `[integrity]
  .pack_hash`, the `<pack-id>/skills/<skill-id>/` directory layout)
  and its validator (`tools/validate_pack.py`).
- The provenance convention for port packs (verbatim `upstream/`,
  pinned `upstream_commit` + `upstream_license`, translation
  `notes.md`).
- The release transport — GitHub Releases assets named
  `<pack-id>-<version>.tar.gz`, with a per-pack SemVer cadence —
  see [`registry.md`](registry.md).
- The curated catalog of packs that an `apxm-server` deployment can
  discover.

Schema changes to `SkillManifest`, new artifact section kinds, and
runtime admission semantics belong upstream. `pack.toml` additions,
provenance conventions, the validator, and the catalog belong here.

## Why this lives outside APXM core

- The pack catalog grows one pack at a time and should not gate apxm
  core releases.
- Port packs carry upstream provenance, translation notes, and license
  metadata that don't belong in a runtime release.
- A maintainer can publish a new pack version without cutting an apxm
  core release.
- The validator + registry transport can iterate without touching the
  compiler or runtime.

## Where the rest of the story lives

- [`architecture.md`](architecture.md) — pack model, loading modes,
  runtime execution model, server-owned library API at a glance.
- [`integration-codex.md`](integration-codex.md) — how Codex (and
  other coding agents) become APXM-aware and how source skills are
  converted into packs.
- [`integration-server.md`](integration-server.md) — full
  `apxm-server` skill-library API: REST routes, execution sequence,
  loading modes.
- [`integration-mcp.md`](integration-mcp.md) — the MCP tool surface
  exposed by `apxm-mcp-server`.
- [`manifests.md`](manifests.md) — `pack.toml`, `skill.toml`, hash
  chain, validation discipline.
- [`registry.md`](registry.md) — GitHub Releases as the v1 registry
  transport.
- [`backlog.md`](backlog.md) — open gaps, in priority order, with
  acceptance criteria.
