# apxm-libs — agent-facing project memory

This file is the single source of truth (SSOT) for coding agents that enter
this repository. `CLAUDE.md`, `AGENTS.md`, `CODEX.md`, `.cursorrules`,
`.agents.json`, and Copilot instructions are generated from this file by
`dekk apxm-libs skills generate`. Edit this file first, then regenerate.

## 1. What apxm-libs is

`apxm-libs` was born from APXM to ship the compiled-skill library — the
versioned, install-as-a-unit packs that `apxm-server` loads at runtime —
on a release cadence separate from the core compiler and runtime. APXM
core owns the AIS dialect, MLIR compiler, runtime, and `SkillManifest`
contract; `apxm-libs` owns the pack catalog and the manifest provenance
metadata that sits on top.

A **pack** is a versioned bundle containing exactly one skill (singleton
model), with `pack.toml` carrying provenance (original vs. port) and
`skills/<skill-id>/` carrying the `SkillManifest`-conforming bundle.

## 2. Authority CLI

Use `dekk apxm-libs` for normal authoring and validation. Standard
commands:

```bash
dekk apxm-libs validate
dekk apxm-libs validate-one <path>
dekk apxm-libs validate-skill <path>
dekk apxm-libs lint
dekk apxm-libs doctor
dekk apxm-libs list
dekk apxm-libs skills generate
dekk apxm-libs skills status
```

Validation is the primary CI surface: every pack must parse against the
`SkillManifest` contract and (when shipping a compiled `.apxmobj`)
recompute its blake3 artifact hash cleanly.

## 3. Repo ownership

- **`packs/`** — the pack catalog. Each subdirectory is one pack with
  `pack.toml`, `README.md`, and `skills/<skill-id>/{skill.toml, SKILL.md,
  skill.air?, skill.apxmobj?, upstream/?, notes.md?}`.
- **`tools/validate_pack.py`** — manifest + provenance + artifact-hash
  validator for `packs/<pack-id>/`.
- **`tools/validate_skill.py`** — manifest validator for a single
  `skill.toml` under any pack.
- **`docs/`** — architecture, manifests, integration surfaces, and
  registry.
- **`.agents/`** — this SSOT, the pack-authoring skills, and shared
  rules.

## 4. Substrate

`apxm-project/apxm` is the runtime, compiler, and server this catalog
is consumed by. It owns the `SkillManifest` contract every pack here
conforms to. Do not describe `apxm-libs` as APXM core: it is the
library catalog, loaded by APXM core's server; the manifest contract
lives upstream.

## 5. Two pack classes

| Class                       | Pack id convention            | Example                              |
|-----------------------------|-------------------------------|--------------------------------------|
| APXM-development            | no source prefix              | `apxm-orient`, `apxm-plan-as-graph`  |
| obra/superpowers port       | `obra-superpowers-<name>`     | `obra-superpowers-brainstorming`     |

Ports re-express community skills (MIT, github.com/obra/superpowers) as
typed AIR graphs. The original `SKILL.md` ships verbatim under
`skills/<id>/upstream/`; the APXM port adds the AIR graph, dispatch
hints, cache-reuse groups, and session traces that let the runtime
fold redundant LLM calls and replay from intermediates.

## 6. Pack-authoring skills

Skills under `.agents/skills/` are tooling for working *on* packs —
authoring `pack.toml`, writing `SKILL.md`, attaching translation notes
for port packs, and validating before PR. The `apxm-skill-authoring`
skill (formerly in apxm core) lives here because pack authoring is
this repo's primary surface.

## 7. Operating rules

- Generated files are not hand-edited. Change `.agents/project.md` or
  `.agents/skills/`, then run `dekk apxm-libs skills generate`.
- Every pack PR must pass `dekk apxm-libs validate` for the touched
  pack(s). Do not weaken the validator to land a broken pack; fix the
  pack.
- Pack ids carry provenance discipline: no source prefix for APXM
  originals; `<source>-<name>` prefix for ports.
- Port packs ship the upstream `SKILL.md` verbatim under
  `skills/<id>/upstream/`, pin `upstream_commit` + `upstream_license`
  in `pack.toml [source]`, and include a `notes.md` describing the
  markdown → AIR translation.
- The `SkillManifest` contract is owned by `apxm-project/apxm` (the
  `apxm-skill` crate). Do not re-declare or shadow it here; cite the
  upstream definition.
- Do not commit registry-side artifacts (download caches, signed
  release tarballs) — those belong in a future registry, not this repo.

## 8. Verification

```bash
dekk apxm-libs validate
dekk apxm-libs doctor
```

Before opening a PR that touches a pack, run `dekk apxm-libs
validate-one packs/<pack-id>`.

## 9. Boundaries

- Never edit the `SkillManifest` schema here; that lives upstream in
  `apxm-project/apxm`. Open an issue/PR there instead.
- Never push to `main`; always work on a feature branch and open a PR.
- Never bypass commit hooks with `--no-verify`.
- Never commit secrets.
