# Integration with MCP

This page documents the MCP surface that `apxm-mcp-server` (the stdio
companion to `apxm-server`) exposes for `apxm-libs` packs: the tool
catalog, the `skill://` resource scheme, and the policy contract.
REST equivalents live in
[`integration-server.md`](integration-server.md); pack discovery and
loading live in [`architecture.md`](architecture.md).

The MCP server code lives in apxm core under
`crates/tools/apxm-server/src/mcp.rs`, `src/mcp_tools.rs`,
`src/mcp_protocol.rs`, `src/skill_resources.rs`, and
`src/bin/apxm_mcp.rs`.

## Why one generic tool, not one tool per skill

External agents (Codex, Claude Code, ...) should call one
policy-checked skill API first, not a dynamic tool for every installed
pack. Reasons:

- The MCP client cache invalidates whenever the tool list changes.
  Per-skill tools mean every pack install or uninstall churns the
  client.
- Per-skill tools push policy enforcement to N tool definitions
  instead of one. One generic `apxm_skill_call` keeps capability,
  timeout, token, and sandbox policy in one place.
- Skill identity is already `skill_id` plus `version` — a generic
  call with that pair as arguments is more honest than 50 tools that
  each pretend to be a top-level capability.

The generic surface stays the default. A per-skill MCP tool view (for
cases where a host agent's UI benefits from seeing one tool per skill)
is a layered concern, sequenced after the generic policy contract is
proven.

## Tool catalog

### Implemented

| MCP tool | Purpose |
| --- | --- |
| `apxm_skills_list` | Discover available packs (the same inventory `GET /v1/skills` returns). |
| `apxm_skill_get` | Fetch one pack's manifest, hashes, capability requirements, and status. |
| `apxm_skill_validate` | Validate a pack (source or compiled), returning structured errors and warnings. |
| `apxm_skill_call` | Execute a static, hash-validated pack through the same manifest/hash/session checks as REST. |

### Planned

| MCP tool | Purpose |
| --- | --- |
| `apxm_skill_explain` | Summarize graph shape, capabilities, risks, and execution contract for a pack (read-only summary view). |
| `apxm_skill_compile` | Admin/dev tool for compiling a validated pack (gated on the `POST /v1/skills/{id}/compile` REST landing). |
| `apxm_skill_run_status` | Query execution status by `execution_id` (gated on the reloadable execution-index work — see G1 in [`backlog.md`](backlog.md)). |

## Policy contract

`apxm_skill_call` enforces the same admission contract as
`POST /v1/skills/{id}/execute` — see
[`integration-server.md`](integration-server.md). In particular:

- Only manifest-identified, precompiled artifacts from server-owned
  skill roots are admitted.
- Raw AIR is rejected.
- Client-provided artifact paths and session roots are rejected.
- Token budget and timeout limits are required for every call.
- `INV_TOOL` capability admission follows the manifest's
  `required_capabilities`, `allowed_tools`, and `side_effect_policy`.
- Side-effectful capabilities require sandbox routing, with
  bubblewrap (or stronger) preferred over the process fallback.

MCP cannot bypass the policy that REST enforces. If a check passes
through one surface, it passes through both; if it fails on one, it
fails on both.

## `skill://` resource scheme

`apxm-mcp-server` exposes `resources/list` and `resources/read` for
allowlisted `skill://` resources so that external agents can read pack
contents without shelling out or filesystem-scanning. The allowlist
covers:

| Resource | Source |
| --- | --- |
| `skill://<skill-id>/SKILL.md` | The source-skill prose contract. |
| `skill://<skill-id>/_manifest` | `skill.toml` rendered as JSON. |
| `skill://<skill-id>/prompt.md` | Pack-supplied prompt text, when present. |
| `skill://<skill-id>/schema.json` | Pack-supplied input/output schema, when present. |
| `skill://<skill-id>/examples/*` | Pack-supplied example payloads, when present. |

When two installed packs share a `skill_id` (different versions), the
versioned URI form is required:

```
skill://<skill-id>@<version>/SKILL.md
skill://<skill-id>@<version>/_manifest
```

Ambiguous unversioned reads against duplicate ids are rejected with a
clear error rather than silently picking one.

## Protocol registry

Method names, tool names, schema fields, server names, and stdio
tool-result keys are not free-form strings. They live in a shared MCP
protocol registry (in apxm core,
`crates/tools/apxm-server/src/mcp_protocol.rs`) that REST routes, MCP
tool definitions, and the validator all read from. This keeps
`apxm_skill_call`'s tool name, the `skill://` resource scheme, and
the response shapes consistent across the wire.

If you need to add an MCP tool that talks to packs, register the name
in the protocol registry, route it through the same policy-checked
admission path as `apxm_skill_call`, and document it on this page —
do not introduce a parallel literal.

## What MCP does not do

- It does not run skills that are not in a configured skill root.
- It does not let the client choose a session root or an artifact
  path.
- It does not surface raw runtime events directly. Events flow
  through the apxm core event taxonomy
  (`crates/core/apxm-core/src/events/`) and reach the MCP client only
  through tool results and (future) streamed result wrappers.
- It does not assume Codex or Claude Code are the only clients. Any
  MCP-compliant host can call the tool catalog.
- It does not yet expose per-execution streaming. The streaming
  variant of `apxm_skill_call` is sequenced after the persistent
  execution index lands.
