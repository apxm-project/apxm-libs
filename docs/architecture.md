# Architecture

This page describes how a pack in `apxm-libs` is structured on disk,
how it relates to the compiled artifact the runtime actually executes,
the three loading modes the server supports, and the conservative
runtime execution model. The deep details of the server-owned API and
its execution sequence live in
[`integration-server.md`](integration-server.md); the schemas that
appear here are documented field-by-field in
[`manifests.md`](manifests.md).

## The classical-library analogy

The cleanest way to read this design is to map APXM's pieces onto a
classical software library. A programmer writes `.h`/`.c`/`.py`, the
toolchain produces `.o`/`.a`/`.so`, and a linker plus a loader makes
those objects callable by name from other code. APXM has most of the
same pieces, with different names; the gaps are exactly where the
analogy is incomplete.

| Classical                | APXM equivalent                                | Notes                                                                                                                                                                                                                                  |
|--------------------------|------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `.h` (header)            | `skill.toml` + `SKILL.md` frontmatter          | `SkillManifest` (from apxm core) declares `skill_id`, `version`, `entry_flow`, `inputs`, `outputs`, `required_capabilities`, `allowed_tools`, and the three-layer hash chain.                                                          |
| `.c` / `.cpp`            | `skill.air` (canonical AIR JSON)               | Compiled by the apxm core compiler through the standard pass pipeline.                                                                                                                                                                 |
| `.py` (source)           | `apxm` Python frontend (decorator DSL → AIR)   | Frontend emits AIR. Consumer-side import surface lives at `apxm.libs.load(skill_id)`; the producer surface is the decorator DSL.                                                                                                       |
| `.o` (object)            | `skill.apxmobj` (wire format)                  | `APXM` magic + version 1 + BLAKE3-of-payload + bincode `ArtifactPayload { metadata, dags: Vec<WireDag>, sections }`. Multi-DAG capable: `is_entry: true` marks the export.                                                              |
| ELF `.note` / debug info | `ArtifactSection { kind, data }` typed sections | `section_kinds::SKILL_MANIFEST_V1 = "apxm.skill_manifest.v1"` is the canonical kind for the embedded manifest. `apxm-server` validates the embedded manifest against the on-disk `skill.toml`.                                          |
| `.a` (archive)           | `packs/<pack-id>/skills/<skill-id>/`           | v1 = one skill per pack. The wire format already permits multiple flows per artifact; the pack layout already permits multiple skills per pack — the singleton is a v1 convention, not a format limit.                                |
| `ld` (linker)            | Cross-skill name resolution                    | Lazy: resolution happens at execution time against the live `SkillLibrary`. There is no separate static-link archive step.                                                                                                              |
| `ld.so` (loader)         | `apxm-server` `SkillLibrary.scan()` + `find()` | `find(requested_id)` accepts `<id>@<version>`; `find_executable()` returns an `ExecutableSkill` that a runtime handler invokes.                                                                                                        |
| Symbol export            | `ExecutionDag.is_entry = true` (one per skill) | The loader returns the entry DAG; non-entry DAGs are reachable today only by flow name within the same artifact.                                                                                                                       |
| Cross-artifact call      | `FLOW_CALL` (in-session) + `call_skill` (across artifacts) | `FLOW_CALL` dispatches by agent+flow inside a session (depth bound `MAX_FLOW_CALL_DEPTH = 100`). Cross-artifact dispatch by manifest identity is the `call_skill` AIS op; resolved `(skill_id, version, artifact_hash)` is recorded in provenance. |
| `python -c "import foo"` | `from apxm.libs import load`                    | `load(skill_id)` resolves through `apxm-server` so capability admission and provenance records stay centralized. `SkillHandle.invoke(**kwargs)` posts to `/v1/skills/{id}/execute` and unpacks the session result.                     |
| `sha256sum`              | Three-layer hash chain (BLAKE3)                | Wire-internal payload hash; per-skill `skill.toml.artifact_hash`; per-pack `pack.toml.pack_hash`. Each layer has a single canonical writer and is verified independently at install and at load.                                       |

## Pack on disk

A pack is the smallest install-as-a-unit and the smallest release
unit. The on-disk shape:

```
<pack-id>/
  pack.toml              # provenance + integrity + license
  README.md              # pack docs, install + usage
  skills/
    <skill-id>/
      skill.toml         # SkillManifest (apxm core contract)
      SKILL.md           # source markdown + frontmatter
      [skill.air]        # optional compiled AIR (JSON)
      [skill.apxmobj]    # optional precompiled artifact
      [notes.md]         # translation notes (port packs)
      [upstream/         # verbatim upstream (port packs)
         SKILL.md]
  [shared/]              # optional shared assets
```

`pack.toml` is owned by this repo (see
[`manifests.md`](manifests.md) for the field reference). `skill.toml`
conforms to the `SkillManifest` schema defined upstream in
`apxm-project/apxm`'s `apxm-skill` crate
(`crates/core/apxm-skill/src/lib.rs`).

### v1 singleton convention

A pack ships **one skill**; an artifact ships **one entry DAG**. The
wire format already supports multiple flows per artifact
(`ArtifactPayload.dags: Vec<WireDag>` with `is_entry` selecting the
export), and the pack layout already supports multiple skills per
pack. v1 keeps the singleton for two reasons:

1. It makes the manifest-versus-artifact correspondence one-to-one,
   which keeps the hash chain and `find()` semantics simple.
2. It keeps the maintainer mental model close to the classical-library
   analogy: one `.c` file becomes one `.o`.

A future multi-skill or multi-entry pack format is not blocked by the
wire format; it is blocked by a deliberate choice. Toolchain
assumptions baked in at v1 must not foreclose that future, so the
canonical writer for the hash chain, the embedded-manifest section,
and the loader's `find()` should all stay structured so that
`Vec<SkillManifest>` and `Vec<is_entry>` can be added additively, not
as a breaking change.

### Source vs APXM forms of a skill

`SKILL.md` alone is a **source skill** — the contract any host agent
can read directly. An **APXM skill** is the same package with a
reviewed `skill.toml`, a valid `skill.air`, and (optionally) a
hash-pinned `skill.apxmobj`. APXM should not execute every source
skill by default. A source-only pack stays a markdown package until
its manifest, AIR, and tests are reviewed; `apxm-server` reports it as
`not_compiled` and refuses to admit it for execution.

## Loading modes

### Static

```
source skill -> skill.air -> skill.apxmobj -> pack release
```

Compile happens at release time (or in CI). The release ships the
hash-pinned `.apxmobj`. Use this mode for demos, CI, benchmark runs,
and production deployments where the artifact must be byte-reproducible
across consumer installs.

### Dynamic

```
request -> discover skill -> validate/convert -> compile/cache -> execute
```

Compile happens at request time, on the server. This is the right
long-term model for a marketplace or user-installed skill catalog, but
it must fail closed on missing capabilities, invalid AIR, unsafe
scripts, disallowed tools, or ambiguous conversion. Dynamic loading is
not on the v1 path — see [`backlog.md`](backlog.md) for what gates it.

### Hybrid

Metadata is served statically; compilation happens on first use. This
is likely the default for developer workflows: discovery is cheap,
validation is visible up front, and warm-cache runs behave like
static loading.

The v1 ship is static. Hybrid and dynamic both require the gate work
captured in [`backlog.md`](backlog.md).

## O2 as the canonical opt level

Every shipped pack is compiled at the apxm core compiler's
`OptimizationLevel::O2`. O2 is the proven-deterministic level: the
compiler emits byte-stable artifacts across repeated invocations on
the same input. Determinism is the precondition for tamper detection
— a pack's `skill.toml.artifact_hash` must byte-match the `.apxmobj`
on every consumer install, and the install transport's tamper check
depends on that match.

O3 is faster on hot paths but is not deterministic-checked and
disables the verifier in places. A per-pack
`pack.toml [compile].opt_level = "O3"` override remains available for
packs whose author has profiled the win and is willing to ship
per-architecture artifacts or accept rebuild-on-install. No v1 pack
uses the override.

## Three-layer hash chain

Three hashes cover three different scopes:

| Hash                          | Covers                  | Writer                                  | Verifier                                  |
|-------------------------------|-------------------------|-----------------------------------------|-------------------------------------------|
| Wire-internal BLAKE3          | `ArtifactPayload` bytes | `Artifact::write_to` (apxm core)        | `Artifact::read_from` on every load       |
| `skill.toml.artifact_hash`    | `.apxmobj` file bytes   | The pack-compile workflow (this repo)   | install + verify path (`dekk apxm libs`)  |
| `pack.toml [integrity].pack_hash` | The shipped tarball bytes | The pack-compile workflow (this repo) | install: pre-unpack gate                  |

The contract: the pack-compile workflow is the **single canonical
writer** for `artifact_hash` and `pack_hash`. The maintainer never
types or copy-pastes either value. The install path verifies the pack
hash before unpacking, the artifact hash after unpacking, and the
wire-internal hash on every load. A mismatch at any layer fails clean
with `(pack_id, skill_id, expected, actual)` — never a panic, never a
silent skip.

## Embedded manifest section

The compiled `.apxmobj` carries its own manifest in a typed artifact
section, kind `apxm.skill_manifest.v1`. `apxm-server` validates the
embedded manifest field-for-field against the on-disk `skill.toml` at
load time and refuses to load on any mismatch. The embed mechanism
reuses the section API the apxm core compiler already uses for sidecar
payloads such as Python tool bundles — no new wire path was
introduced.

The result is that the `.apxmobj` is self-describing: a tampered
install whose `skill.toml` has been edited to match the tampered
artifact is still caught at load, because the embedded section carries
the manifest the artifact was compiled against, and that copy is
integrity-protected by the wire-internal BLAKE3.

## Lazy cross-artifact linking

Cross-artifact dispatch resolves at execution time. The runtime
handler for the cross-skill call op (`call_skill`, defined in apxm
core) asks the live `SkillLibrary` for the artifact whose manifest
identity matches the requested `skill_id` (or `skill_id@version`),
invokes it, and records the resolved
`(skill_id, version, artifact_hash)` triple in the parent session's
provenance. There is no separate "link" artifact step and no on-disk
symbol table that pins names to artifact hashes at build time.

The cost of lazy resolution is one hash lookup per call against an
in-memory map. The benefit is that the producer toolchain stays
simple: no static-link format to design, no archive layout to version,
no separate verifier for cross-artifact symbol tables. Reproducibility
is preserved at the provenance layer instead of at the artifact layer
— replaying a parent session against the same library state produces
the same resolved hashes.

A static-link archive — a single shipping unit bundling a parent skill
together with the artifact hashes of every child it calls — is
plausible but unnecessary at v1. Static linking becomes a candidate
optimization only if profiling shows resolution cost dominates or if a
distribution channel needs an offline-self-contained bundle. Both are
future-phase questions.

## Runtime execution model

The runtime in apxm core already has a usable foundation for compiled
skills:

- `.apxmobj` supports generic extension sections via the artifact
  crate.
- `Runtime::execute_artifact_with_session_and_emitter` loads an
  artifact, validates entry-flow arguments, registers artifact DAGs
  into the flow registry, executes with scheduler hooks, and returns
  node output maps and metrics.
- The runtime parses one artifact sidecar section for Python tool
  bundles today; the embedded skill manifest reuses the same pattern
  under the `apxm.skill_manifest.v1` kind.
- `FlowRegistry` stores compiled flows by agent/flow identity, which
  is the substrate for `FLOW_CALL`.

The first execution path is deliberately conservative:

```
skill.toml + skill.air
  -> compile O0/O2 to skill.apxmobj
  -> attach apxm.skill_manifest section
  -> execute by artifact path
  -> emit session + per-node evidence
  -> compare O0 and O2 outputs/metrics
```

Only after this works does APXM add a named skill target:

```
WORKFLOW_SPAWN(target_kind = "skill", target = "checkout-context-triage@0.1.0")
```

And the alternative invocation, where external agents call
`INV_TOOL(capability = "skill:checkout-context-triage")`, is a good
MCP/server story but is sequenced after artifact-path execution.

## Why execute skills in APXM at all

A prose skill is useful when the host agent only needs guidance. APXM
execution is useful when the skill needs runtime guarantees and
evidence. The question is not "can Codex read the steps?" but "which
parts should be isolated, observable, replayable, and optimizable?"
APXM execution buys:

- **Context separation** — each skill node gets explicit inputs and
  outputs instead of one large host-agent context window.
- **Node-level inspection** — sessions persist per-node `node.json`,
  `prompt.txt`, `response.txt`, `output.json`, `metrics.json`,
  `status.json`, and `trace.ndjson` when enough graph metadata is
  available.
- **Runtime observability** — execution emits operation start/end,
  LLM token, token-usage, scheduler, memory, checkpoint, and
  memoization events.
- **Optimization evidence** — O0 and O2 artifacts can be compared
  through compiler diagnostics, pass stats, eliminated ops, LLM call
  counts, tokens, and traces.
- **Isolation and policy** — compiled skill manifests declare allowed
  tools, required capabilities, filesystem/network policy, and
  approval behavior before runtime admission.
- **Checkpointing and replay** — APXM has checkpoint event payloads,
  pause/resume handlers, server checkpoint routes, and session
  directories; a skill server should attach those to skill runs
  explicitly. Full scheduler-state checkpoint is gated on
  [`backlog.md`](backlog.md) G6.
- **Portable invocation** — Codex, Claude Code, the GUI, MCP clients,
  and other agents can call the same APXM skill by manifest identity
  rather than copying different prose instructions into each host.

The cost is that execution requires a stable ABI and validation
layer. A source skill stays a markdown package until it has a reviewed
`skill.toml`, a valid `skill.air`, and passing tests.

## Server-owned library API (overview)

`apxm-server` is the source of truth for skill discovery, metadata,
validation status, and execution. The GUI and CLI consume the same
endpoints rather than building separate scanners. The server owns:

- `GET /v1/skills` — list discovered skills.
- `GET /v1/skills/{id}` — manifest + status for one skill.
- `POST /v1/skills/{id}/validate` — re-run validation.
- `POST /v1/skills/{id}/execute` — execute a precompiled,
  hash-validated `.apxmobj` under APXM-owned sessions.
- `POST /v1/skills/{id}/execute/stream` — SSE-streamed execution.
- `GET /v1/executions/{execution_id}` — execution status/result.
- `GET /v1/executions/{execution_id}/nodes/{node_id}` — per-node
  output detail.

The full request/response shapes, the execution sequence, the rejected
inputs (raw AIR, client session roots, symlinked artifacts, mismatched
hashes, ...), and the discovery-root configuration (`--skill-root`,
`APXM_SKILLS_PATH`) are documented in
[`integration-server.md`](integration-server.md). The MCP wrapping
lives in [`integration-mcp.md`](integration-mcp.md).
