# Contributing to apxm-libs

apxm-libs is the public catalog of APXM packs. A pack is the install
unit; each pack contains exactly one skill plus optional shared
resources. See `README.md` for the pack model and layout; see
`REGISTRY.md` for the release flow.

## What belongs here

Two pack classes ship from this repo:

1. **APXM-development packs** (no source prefix) — skills for working
   *on* APXM itself: orientation, authoring a compiler pass, writing
   a runtime backend, etc. These are APXM-original work.
2. **Port packs** (`<source>-<skill-name>`) — community or vendor
   skills re-expressed as APXM-AIR graphs. Currently the only port
   source is `obra/superpowers` (`obra-superpowers-*`).

Skills that are tooling for a *specific user's* private project don't
belong here; ship them as a sibling-clone-installed local pack
instead.

## Add a new APXM-development pack

```
packs/<pack-id>/
  pack.toml
  README.md
  skills/<pack-id>/
    skill.toml
    SKILL.md
    [skill.air]
    [skill.apxmobj]
    [notes.md]
```

Use the pack id verbatim as the contained skill id (singleton pack
model). Set `pack.toml [source].kind = "original"` and put
`attribution = "APXM contributors."` (or your name) — no `upstream*`
keys.

`skill.toml` must conform to the `SkillManifest` contract defined in
the apxm repo at `crates/core/apxm-skill/src/lib.rs`. The validator
checks all required fields.

## Add a new port pack

Ports take a community skill (currently `obra/superpowers`) and
re-express its markdown checklist as a typed APXM-AIR graph. The
typed graph lets the runtime dispatch CPU-cheap planning separately
from GPU-heavy synthesis, fold redundant LLM calls across cache-reuse
groups, fan out independent steps, and replay any node from cached
intermediates.

Required structure:

```
packs/<source>-<skill-name>/
  pack.toml                                 # kind="port", upstream* set
  README.md
  skills/<source>-<skill-name>/
    SKILL.md                                # APXM port description
    skill.toml
    skill.air                               # typed AIR graph (the port)
    notes.md                                # upstream → AIR translation map
    upstream/SKILL.md                       # verbatim from upstream, pinned
```

`pack.toml [source]` must declare `kind = "port"`, `upstream`,
`upstream_path`, `upstream_commit`, `upstream_license`, and
`attribution`. `upstream/SKILL.md` must byte-match the upstream file
at `upstream_commit`.

Map every upstream step to a graph node in `notes.md`. The
translation pattern from `README.md` (Plan/Search/Analyze/Validate/
Synthesize with `@cpu`/`@gpu` and `@reuse_group` hints) is the
default vocabulary; deviate only where the upstream demands it and
explain why in `notes.md`.

## House rules

- **No referential comments anywhere** — no plan IDs, ticket numbers,
  release phase markers, or "deferred to X" pointers in `pack.toml`,
  `skill.toml`, `SKILL.md`, `notes.md`, `README.md`, or any code
  comments. State implementation status as a fact ("Not yet compiled
  — `skill.air` absent"), not a reference.
- **One skill per pack** — singleton pack model is non-negotiable for
  v1. Multi-skill packs may land later but require a separate design.
- **No GitHub Actions** — validation runs as a pre-commit hook
  locally; releases are cut by maintainers running `gh release
  create` from a clean checkout. See `REGISTRY.md`.
- **Provenance is load-bearing** — port packs must pin
  `upstream_commit` and ship `upstream/SKILL.md` verbatim so future
  contributors can audit fidelity.

## Validate before opening a PR

```bash
# Validate just the pack you changed
python3 tools/validate_pack.py packs/<pack-id>/

# Validate everything (CI-equivalent)
python3 tools/validate_pack.py packs/*/
```

The validator parses `pack.toml`, verifies the `[source]` block by
kind, recurses into `tools/validate_skill.py` for the contained
skill, and (for port packs) confirms `upstream/SKILL.md` is present.

A clean validator run is required before a PR can be merged.

## Author-side workflow with dekk

If you have `dekk apxm` available, the registry-side commands work
on local packs too:

```bash
# Search across the catalog
dekk apxm libs search <substring>

# Install your in-progress pack into ~/.apxm/libs/ for end-to-end testing
dekk apxm libs install <pack-id> --source /path/to/apxm-libs/packs --force

# Verify the installed bytes against pack.toml [integrity].pack_hash
dekk apxm libs verify <pack-id>
```

## PR conventions

- One pack change per PR. Multi-pack changes are tolerated only for
  cross-cutting infrastructure (e.g. a validator rule rollout).
- Pack version bumps follow SemVer (see `REGISTRY.md`); the PR title
  is `release(<pack-id>): v<version>` for release PRs and
  `feat(<pack-id>): <change>` for in-progress work.
- Cite the upstream URL for port packs in the PR description so
  reviewers can spot-check fidelity.
