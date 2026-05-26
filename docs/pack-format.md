# Pack format

This document is the shipping contract for an `apxm-libs` pack. It
defines the directory layout, the required files, the two manifest
schemas (`pack.toml`, `skill.toml`), the embedded manifest section
inside `skill.apxmobj`, the three-layer hash chain, and the v1
singleton convention.

If you are *writing* a pack, read [`authoring.md`](authoring.md). If
you are *installing* one, read [`consuming.md`](consuming.md).

## Directory layout

```
packs/<pack-id>/
    pack.toml                     # pack manifest + integrity
    README.md                     # pack docs
    skills/<skill-id>/
        skill.toml                # SkillManifest
        SKILL.md                  # source markdown + frontmatter
        skill.air                 # canonical AIR graph
        skill.apxmobj             # compiled artifact (O2)
        notes.md                  # AIR-node design notes / port map
        upstream/SKILL.md         # port packs only: verbatim source
    [shared/]                     # optional shared resources
```

The pack directory name and `pack.toml::pack_id` must match. The
skill directory name and `skill.toml::skill_id` must match. The pack
directory name is what the tarball's top-level entry is named (see
[`REGISTRY.md`](../REGISTRY.md)).

## v1 singleton convention

A v1 pack contains **exactly one skill** and the compiled artifact
contains **exactly one entry DAG** (`is_entry: true`). The pack
wire format (`apxm_artifact::ArtifactPayload`) and the on-disk pack
layout both *permit* multi-skill packs and multi-flow artifacts —
the singleton is a v1 contract, not a format limitation. Future
multi-flow pack layouts are tracked in the APXM design tree; pack
authors should not pre-emptively split across this boundary.

## `pack.toml` schema

```toml
pack_id      = "apxm-orient"            # kebab-case, globally unique
version      = "0.1.0"                  # SemVer; must equal skill.toml::version
display_name = "APXM Orient"
description  = "<= 200 chars; first sentence ends with period."
skill        = "apxm-orient"            # name of the singleton skill
license      = "Apache-2.0"             # SPDX id
homepage     = "https://github.com/apxm-project/apxm-libs"

[source]
kind        = "original"                # "original" | "port"
attribution = "APXM contributors."

# Port packs only:
# upstream         = "https://github.com/obra/superpowers"
# upstream_path    = "skills/brainstorming/SKILL.md"
# upstream_commit  = "<sha>"
# upstream_license = "MIT"

[integrity]
pack_hash = "blake3:<hex>"              # written by `dekk apxm libs build`

[compile]                                # optional
opt_level = "O2"                         # "O0" | "O1" | "O2" | "O3"; default O2
```

`[compile].opt_level` defaults to `O2`. O2 is the proven-deterministic
level (`apxm/crates/compiler/apxm-compiler/tests/pass_idempotency_test.rs`).
A pack author may override to O3 only after profiling shows the win
and accepting that consumers may need to re-build on install — v1
ships every pack at O2.

## `skill.toml` schema

```toml
skill_id      = "apxm-orient"           # must match enclosing dir
version       = "0.1.0"                 # must match pack.toml::version
display_name  = "APXM Orient"
description   = "Deterministic project orientation."
entry_flow    = "apxm_orient"           # name of the entry DAG
artifact_hash = "blake3:<hex>"          # written by `dekk apxm libs build`

required_capabilities = []              # ids the skill needs
timeout_ms            = 30000
token_limit           = 0               # 0 = no cap
isolation_policy      = "sandboxed"     # "read_only" | "sandboxed" | other
side_effect_policy    = "sandboxed"

[[inputs]]
name        = "focus_area"
type        = "string"
description = "Optional subsystem filter."
required    = false

[[outputs]]
name        = "orientation"
type        = "json"
description = "Structured orientation card."
```

## Embedded manifest section

Every `skill.apxmobj` carries its `skill.toml` content as an
`ArtifactSection { kind: "apxm.skill_manifest.v1", data: <bytes> }`.
The embedded copy has `artifact_hash` stripped (chicken-and-egg —
the artifact's hash cannot be inside the bytes it covers); the
on-disk `skill.toml::artifact_hash` is the canonical value.

`apxm-server` calls `validate_embedded_skill_manifest` on every load
and rejects an artifact whose embedded manifest disagrees with the
on-disk `skill.toml` on any non-stripped field.

## Three-layer hash chain

| Layer | Hash | Written by | Verified by |
|---|---|---|---|
| Wire-internal | BLAKE3 of the bincode payload | `Artifact::write_to` (compile time) | `Artifact::read_from` (every load) |
| Per-skill | `skill.toml::artifact_hash = blake3:<hex>` of `skill.apxmobj` | `dekk apxm libs build` | `apxm libs install` (and on `verify`) |
| Per-pack | `pack.toml::pack_hash = blake3:<hex>` of the release tarball | `dekk apxm libs build` (then `gh release`) | `apxm libs install` |

The build command is the **single canonical writer** for all three.
Pack authors never paste hashes by hand. An install-time mismatch on
any layer fails clean with `(pack_id, skill_id, expected, actual)` —
no panic, no silent skip.

## File-level requirements (validator)

`tools/validate_pack.py` checks:

- `pack.toml` parses; declares `pack_id`, `version`, `skill`,
  `license`.
- `[source].kind` is `original` or `port`; port packs require
  `upstream`, `upstream_path`, `upstream_commit`, `upstream_license`.
- `skills/<skill>/` exists; `skill.toml` is a valid SkillManifest.
- Port packs: `skills/<skill>/upstream/SKILL.md` exists.

With `--require-artifact`: also fails when `skill.apxmobj` is
missing or its BLAKE3 disagrees with `skill.toml::artifact_hash`.
Without the flag, scaffold packs (no `.apxmobj` yet) are accepted —
authoring stays frictionless.

## What's *not* in a pack

- No build script. Compilation goes through the APXM toolchain
  (`dekk apxm libs build`), never a per-pack `build.sh`.
- No vendored APXM runtime. The runtime ships with `apxm-server`.
- No version-pinned dependencies on other packs. Cross-pack calls
  resolve lazily through the loader (`SkillLibrary.find_executable`).
