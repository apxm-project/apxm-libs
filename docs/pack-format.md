# Pack format

This document is the shipping contract for an `apxm-libs` pack. It defines
the directory layout, required files, manifest schemas (`pack.toml`,
`skill.toml`, optional `agent.toml` / `hierarchy.toml` / `tools.toml`), the
embedded manifest section inside `skill.apxmobj`, and the three-layer hash
chain.

A pack ships **one or more skills** and **optionally** an agent definition
+ hierarchy + tool manifests at the pack root. There is no separate
singleton-pack vs. agent-bundle format — one shape covers both.

If you are *writing* a pack, read [`authoring.md`](authoring.md). If you
are *installing* one, read [`consuming.md`](consuming.md).

## Directory layout

```
packs/<pack-id>/
    pack.toml                     # pack manifest + integrity (required)
    README.md                     # pack docs
    agent.toml                    # optional: agent identity owned by this pack
    hierarchy.toml                # optional: parent_agent + child_agents
    tools.toml                    # optional: [[tool]] manifests with callback URLs
    skills/<skill-id>/            # one or more skill directories
        skill.toml                # SkillManifest
        SKILL.md                  # source markdown + frontmatter
        skill.air                 # canonical AIR graph
        skill.apxmobj             # compiled artifact (O2)
        notes.md                  # AIR-node design notes / port map
        upstream/SKILL.md         # port packs only: verbatim source
    [shared/]                     # optional shared resources
```

The pack directory name and `pack.toml::pack_id` must match. Every skill
directory name and `skill.toml::skill_id` must match. The pack directory
name is what the tarball's top-level entry is named (see
[`REGISTRY.md`](../REGISTRY.md)).

## `pack.toml` schema

```toml
pack_id      = "apxm-orient"            # kebab-case, globally unique
version      = "0.1.0"                  # SemVer
display_name = "APXM Orient"
description  = "<= 200 chars; first sentence ends with period."
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
A pack author may override to O3 only after profiling shows the win and
accepting that consumers may need to re-build on install.

## `skill.toml` schema

```toml
skill_id      = "apxm-orient"           # must match enclosing dir
version       = "0.1.0"
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

A pack with N skills ships N `skills/<skill-id>/skill.toml` files. The
exposed-skill list of the pack is the union of all `skill.toml::skill_id`
values discovered under `skills/`.

## `agent.toml` schema (optional)

When a pack ships an agent, this file at the pack root declares its
identity. `apxm-server`'s loader reads it on discovery and calls
`/v1/agents/register` with the fields below.

```toml
agent_id             = "module.crm"
display_name         = "CRM Agent"
agent_type           = "module"                     # AgentType enum
scope                = "module"
runtime_skill_ids    = ["clic-crm-dispatch"]        # skills/<id>/ entries the agent dispatches
default_capabilities = ["crm.lead.search", "lead.find_or_create"]
```

## `hierarchy.toml` schema (optional)

```toml
parent_agent = "agent.workflow_supervisor"
child_agents = ["task.crm.followup", "task.crm.qualify"]
```

When both spawner and target have `parent_agent` set, `SPAWN_AGENT`
validates the edge (target's `parent_agent` must equal the spawner's
name).

## `tools.toml` schema (optional)

```toml
[[tool]]
name              = "crm.lead.search"
capability        = "crm.lead.search"
endpoint_pattern  = "/clic/tools/invoke/crm.lead.search"
requires_approval = false
read_only         = true
# Optional JSON-Schema-shaped tables:
# [tool.schema]        type = "object"  ...
# [tool.result_schema] type = "object"  ...
```

`endpoint_pattern` is the templated HTTP callback URL the loader registers
with `/v1/capabilities/register`. When the capability is invoked, the
runtime POSTs the call arguments to the resolved URL and awaits a
`{"result": ...}` response.

## Embedded manifest section

Every `skill.apxmobj` carries its `skill.toml` content as an
`ArtifactSection { kind: "apxm.skill_manifest.v1", data: <bytes> }`. The
embedded copy has `artifact_hash` stripped (chicken-and-egg — the
artifact's hash cannot be inside the bytes it covers); the on-disk
`skill.toml::artifact_hash` is the canonical value.

`apxm-server` calls `validate_embedded_skill_manifest` on every load and
rejects an artifact whose embedded manifest disagrees with the on-disk
`skill.toml` on any non-stripped field.

## Three-layer hash chain

| Layer | Hash | Written by | Verified by |
|---|---|---|---|
| Wire-internal | BLAKE3 of the bincode payload | `Artifact::write_to` (compile time) | `Artifact::read_from` (every load) |
| Per-skill | `skill.toml::artifact_hash = blake3:<hex>` of `skill.apxmobj` | `dekk apxm libs build` | `apxm libs install` (and on `verify`) |
| Per-pack | `pack.toml::pack_hash = blake3:<hex>` of the release tarball | `dekk apxm libs build` (then `gh release`) | `apxm libs install` |

The build command is the **single canonical writer** for all three. Pack
authors never paste hashes by hand. An install-time mismatch on any layer
fails clean with `(pack_id, skill_id, expected, actual)` — no panic, no
silent skip.

## File-level requirements (validator)

`tools/validate_pack.py` checks:

- `pack.toml` parses; declares `pack_id`, `version`, `license`.
- `[source].kind` is `original` or `port`; port packs require
  `upstream`, `upstream_path`, `upstream_commit`, `upstream_license`.
- `skills/` contains at least one skill; each `skills/<id>/skill.toml`
  is a valid SkillManifest.
- Port packs: `skills/<id>/upstream/SKILL.md` exists.
- When present: `agent.toml` declares `agent_id`, `display_name`,
  `agent_type`, `scope`; `hierarchy.toml::parent_agent` is a string and
  `child_agents` is a list of strings; every `tools.toml::[[tool]]`
  entry declares `name`, `capability`, `endpoint_pattern`.

With `--require-artifact`: also fails when any skill's `skill.apxmobj`
is missing or its BLAKE3 disagrees with `skill.toml::artifact_hash`.
Without the flag, scaffold packs (no `.apxmobj` yet) are accepted —
authoring stays frictionless.

## What's *not* in a pack

- No build script. Compilation goes through the APXM toolchain
  (`dekk apxm libs build`), never a per-pack `build.sh`.
- No vendored APXM runtime. The runtime ships with `apxm-server`.
- No version-pinned dependencies on other packs. Cross-pack calls
  resolve lazily through the loader (`SkillLibrary.find_executable`).
