# Manifests

This page documents the two manifests that every pack carries:
`pack.toml` (owned by this repo) and `skill.toml` (owned upstream in
`apxm-project/apxm` as `SkillManifest`). It also covers the
three-layer hash chain, the provenance discipline for port packs, and
the validation rules `tools/validate_pack.py` enforces. The pack
layout itself lives in [`architecture.md`](architecture.md); the
release transport lives in [`registry.md`](registry.md).

## Ownership

| Manifest | Owner | Source of truth |
| --- | --- | --- |
| `pack.toml` | `apxm-libs` (this repo) | `tools/validate_pack.py` parses; the schema is the body of this page. |
| `skill.toml` | `apxm-project/apxm` (`apxm-skill` crate) | `crates/core/apxm-skill/src/lib.rs::SkillManifest`. `tools/validate_pack.py` reuses the same parser via the published crate / Python bridge. |

Schema additions to `skill.toml` (new fields, new isolation levels,
new dispatch-hint kinds) belong upstream. Schema additions to
`pack.toml` (new provenance kinds, new release-transport metadata)
belong here.

## `pack.toml`

Every pack ships exactly one `pack.toml` at its root. Minimal shape
for an APXM-development pack (`[source].kind = "original"`):

```toml
pack_id = "apxm-orient"
version = "0.0.1"
display_name = "APXM Orient"
description = "Deterministic project orientation: doctor + repo layout summary + crate map. No LLM calls."
skill = "apxm-orient"
license = "Apache-2.0"
homepage = "https://github.com/apxm-project/apxm-libs"

[source]
kind = "original"
attribution = "APXM contributors."

[integrity]
pack_hash = ""        # filled by the pack-compile workflow
```

Minimal shape for a port pack (`[source].kind = "port"`):

```toml
pack_id = "obra-superpowers-brainstorming"
version = "0.0.1"
display_name = "Brainstorming (obra/superpowers port)"
description = "APXM-AIR port of obra/superpowers brainstorming. ..."
skill = "obra-superpowers-brainstorming"
license = "MIT"
homepage = "https://github.com/apxm-project/apxm-libs"

[source]
kind = "port"
upstream = "https://github.com/obra/superpowers"
upstream_path = "skills/brainstorming/SKILL.md"
upstream_commit = "f2cbfbefebbfef77321e4c9abc9e949826bea9d7"
upstream_license = "MIT"
attribution = "Original SKILL.md by Jesse Vincent (obra); APXM AIR port by APXM contributors."

[integrity]
pack_hash = ""
```

### Top-level fields

| Field | Required | Purpose |
| --- | --- | --- |
| `pack_id` | yes | Stable identifier. Must equal the directory name under `packs/` and the top-level directory inside the release tarball. |
| `version` | yes | SemVer. Must match `skills/<skill-id>/skill.toml::version` (singleton constraint). |
| `display_name` | recommended | UI text, never an identifier. |
| `description` | recommended | One-line catalog summary. |
| `skill` | yes | The single skill id this pack contains (singleton). |
| `license` | yes | SPDX identifier for the pack as published (the license of the AIR, not the upstream prose for ports — that is `[source].upstream_license`). |
| `homepage` | recommended | URL for catalog UIs. |

### `[source]`

| Field | When | Purpose |
| --- | --- | --- |
| `kind` | always | `"original"` for APXM-authored packs; `"port"` for re-expressions of upstream skills. |
| `attribution` | always | Free-form credits string. |
| `upstream` | `kind = "port"` only | Repo URL of the upstream skill source. |
| `upstream_path` | `kind = "port"` only | Path inside the upstream repo at `upstream_commit`. |
| `upstream_commit` | `kind = "port"` only | Pinned commit SHA. Required so the verbatim `upstream/SKILL.md` shipped in the pack is reproducible. |
| `upstream_license` | `kind = "port"` only | SPDX identifier of the upstream skill (e.g. `MIT`). |

The validator refuses to ship a `kind = "port"` pack without all four
upstream fields, and refuses to ship a `kind = "original"` pack with
any of them.

### `[integrity]`

| Field | When | Purpose |
| --- | --- | --- |
| `pack_hash` | every release | `blake3:` hex of the canonical release tarball. Empty in dev; populated by the pack-compile workflow at release time. |

### `[compile]` (optional)

| Field | Purpose |
| --- | --- |
| `opt_level` | One of `"O0"`, `"O2"`, `"O3"`. Defaults to `"O2"`. Override only when the pack maintainer has profiled an O3 win and is willing to ship per-architecture artifacts or rebuild-on-install. No v1 pack uses the override. |

## `skill.toml` (`SkillManifest`)

`skill.toml` is the upstream contract. The canonical schema is the
Rust struct in apxm core:

```rust
// crates/core/apxm-skill/src/lib.rs (apxm-project/apxm)
pub struct SkillManifest {
    pub skill_id: String,
    pub version: String,
    pub display_name: Option<String>,
    pub description: Option<String>,
    pub entry_flow: String,
    pub source_hash: Option<String>,
    pub air_hash: Option<String>,
    pub artifact_hash: Option<String>,
    pub compiler_version: Option<String>,
    pub runtime_version: Option<String>,
    pub required_capabilities: Vec<String>,
    pub allowed_tools: Vec<String>,
    pub timeout_ms: Option<u64>,
    pub token_limit: Option<u64>,
    pub isolation_policy: Option<String>,
    pub side_effect_policy: Option<String>,
    pub inputs: Vec<SkillParam>,
    pub outputs: Vec<SkillParam>,
}

pub struct SkillParam {
    pub name: String,
    pub type_name: Option<String>,    // serde rename "type"
    pub description: Option<String>,
    pub required: Option<bool>,
}
```

Minimal example, from `packs/apxm-orient/skills/apxm-orient/skill.toml`:

```toml
skill_id = "apxm-orient"
version = "0.0.1"
display_name = "APXM Orient"
description = "Deterministic project orientation: doctor + repo layout summary + crate map. No LLM calls."
entry_flow = "apxm_orient"
required_capabilities = []
timeout_ms = 30000
token_limit = 0
isolation_policy = "sandboxed"
side_effect_policy = "sandboxed"

[[inputs]]
name = "focus_area"
type = "string"
description = "Optional subsystem filter (compiler, runtime, server, frontend, eval)."
required = false

[[outputs]]
name = "orientation"
type = "json"
description = "Structured orientation card: doctor status, crate map, recent commits, active branches, open todos."
```

The parser accepts either layout: top-level fields (as above) or a
nested `[skill]` table (legacy form). New packs use the top-level
form.

### Field reference (essentials)

| Field | Required | Notes |
| --- | --- | --- |
| `skill_id` | yes | Stable identifier. Must equal the directory name under `skills/`. |
| `version` | yes | SemVer. Must match `pack.toml::version`. |
| `entry_flow` | yes | Name of the entry flow inside the compiled artifact. The runtime rejects calls whose target flow doesn't match. |
| `source_hash` | optional | `blake3:` hex of `SKILL.md` (and any source-skill support files, when the pack defines that bundle). |
| `air_hash` | optional | `blake3:` hex of `skill.air`. |
| `artifact_hash` | for packs that ship `.apxmobj` | `blake3:` hex of `skill.apxmobj`. Verified at install (post-unpack) and at load (against the embedded `apxm.skill_manifest.v1` section). |
| `compiler_version`, `runtime_version` | recommended | Compatibility hints; apxm-server uses them to flag known-bad pairs. |
| `required_capabilities`, `allowed_tools` | optional | Capability and tool admission lists. The runtime refuses to dispatch `INV_TOOL` for any capability or tool not declared here. |
| `timeout_ms`, `token_limit` | recommended | Per-call budgets. Required by `/v1/skills/{id}/execute` and `apxm_skill_call` for every invocation; the manifest provides the default. |
| `isolation_policy` | recommended | Currently `"sandboxed"` is the only value the v1 admission path treats as side-effect-safe. |
| `side_effect_policy` | recommended | `"read_only"` (or omitted) constrains admitted capabilities to read-only; `"sandboxed"` requires sandbox routing for any side-effectful capability. |
| `inputs`, `outputs` | recommended | Typed ABI. Validated by `/v1/skills/{id}/execute` before runtime dispatch. |

`SkillParam.type_name` is serialized as `type` in TOML (Rust serde
rename). Use `type = "string"`, `type = "json"`, etc.

## Hash chain

Three hashes cover three different scopes. All three use BLAKE3 with
the `blake3:` prefix.

| Hash | Covers | Writer | Verifier |
| --- | --- | --- | --- |
| Wire-internal | `ArtifactPayload` bytes inside `.apxmobj` | apxm core compiler (`Artifact::write_to`) | apxm core runtime (`Artifact::read_from`) on every load |
| `skill.toml.artifact_hash` | `.apxmobj` file bytes | The pack-compile workflow (this repo) | `dekk apxm libs install` (post-unpack), `dekk apxm libs verify` |
| `pack.toml [integrity].pack_hash` | The release tarball bytes | The pack-compile workflow (this repo) | `dekk apxm libs install` (pre-unpack) |

The contract: the pack-compile workflow is the **single canonical
writer** for `artifact_hash` and `pack_hash`. Maintainers never type
or copy-paste either value.

Mismatch handling at any layer is deterministic and structured:

- Pre-unpack `pack_hash` mismatch → install aborts before touching
  the install root.
- Post-unpack `artifact_hash` mismatch → install rolls back, leaves no
  partial pack on disk.
- Load-time wire-internal mismatch → `apxm-server` refuses to admit
  the pack, with a clear error naming `(pack_id, skill_id, expected,
  actual)`. Never a panic, never a silent skip.

## Embedded manifest section

The compiled `.apxmobj` carries its own copy of `skill.toml` as a
typed artifact section, kind `apxm.skill_manifest.v1`. At load time,
`apxm-server` field-compares the embedded copy against the on-disk
`skill.toml` and refuses to admit on any mismatch. This is what makes
tamper detection robust against an attacker who edits `skill.toml` to
match a tampered `skill.apxmobj` — the embedded copy is
integrity-protected by the wire-internal BLAKE3.

The section kind constant lives in apxm core
(`section_kinds::SKILL_MANIFEST_V1 = "apxm.skill_manifest.v1"`).

## Provenance discipline for port packs

A port pack re-expresses an upstream `SKILL.md` as a typed AIR graph.
The provenance contract:

1. Ship the upstream `SKILL.md` **verbatim** at
   `skills/<skill-id>/upstream/SKILL.md`. Do not edit it. The hash of
   that file at the pinned `[source].upstream_commit` is the witness
   that the port is faithful.
2. Pin `[source].upstream`, `[source].upstream_path`,
   `[source].upstream_commit`, and `[source].upstream_license` in
   `pack.toml`. The validator refuses port packs without all four.
3. Write `skills/<skill-id>/notes.md` describing the markdown → AIR
   translation: which steps became reasoning nodes, which became
   tool capabilities, which became typed control flow, which were
   intentionally restructured, and why.
4. Set the pack `license` field to the SPDX of the AIR
   (Apache-2.0 for APXM-authored AIR over MIT upstreams is the
   typical pattern). Set `[source].upstream_license` to the upstream
   SPDX (`MIT` for obra/superpowers).

Original (`[source].kind = "original"`) packs never carry any of the
`upstream_*` fields.

## Validation discipline

`tools/validate_pack.py` runs all of the following on every pack:

1. `pack.toml` parses and has the required fields for its `[source]
   .kind`.
2. `skill.toml` parses against the `SkillManifest` parser from apxm
   core's `apxm-skill` crate.
3. `pack.toml::version` equals `skill.toml::version`.
4. `pack.toml::skill` equals the single directory name under
   `skills/` and equals `skill.toml::skill_id`.
5. `manifest_shape_errors` from `apxm-skill` is empty
   (`skill_id`/`version`/`entry_flow` non-empty, `timeout_ms` and
   `token_limit` positive when set).
6. When `skill.toml::artifact_hash` is declared and a `.apxmobj` file
   exists in the skill directory, the recomputed BLAKE3 matches.
7. When `skill.toml::source_hash` is declared, the recomputed BLAKE3
   over `SKILL.md` matches.
8. Port packs ship a non-empty `skills/<skill-id>/upstream/SKILL.md`.

Validation runs at three points:

- In CI on every PR (the repo's GitHub Actions workflow runs the
  validator against `packs/*/`).
- Before every release: `python tools/validate_pack.py packs/<pack-id>`.
- At install time: `dekk apxm libs install` re-runs the equivalent
  Rust validation against the unpacked pack before marking it
  installed.

A pack that fails validation at any of those points is rejected
cleanly with a structured error — never installed with warnings,
never silently skipped.

## Adding a new manifest field

For a new `pack.toml` field:

1. Extend the schema in this page.
2. Update `tools/validate_pack.py` to parse and validate it.
3. Update existing packs that should declare it (or leave it
   optional and document the default).

For a new `skill.toml` field:

1. Add the field in `crates/core/apxm-skill/src/lib.rs` (apxm core)
   with the appropriate `#[serde(default)]`.
2. Run `dekk apxm build-dialect` and `dekk apxm codegen` upstream so
   the Python frontend and Rust runtime see it consistently.
3. Update the Field reference table on this page to describe it.
4. Update `tools/validate_pack.py` (or the apxm-skill Python bridge it
   uses) if the new field has shape constraints beyond the Rust
   struct's defaults.

Never add a `skill.toml` field by editing only the validator. Schema
drift between the upstream parser and the validator is the failure
mode the `apxm-skill` crate exists to prevent.
