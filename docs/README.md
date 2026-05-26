# `apxm-libs` documentation

Reading order:

1. **[`architecture.md`](architecture.md)** — the pack model, loading
   modes, runtime execution, and lifecycle.
2. **[`pack-format.md`](pack-format.md)** — directory layout, manifest
   shapes, hash chain.
3. **[`manifests.md`](manifests.md)** — `pack.toml` + `skill.toml`
   schemas, provenance metadata, validation contract.
4. **[`authoring.md`](authoring.md)** — workflow for creating a new
   pack.
5. **[`consuming.md`](consuming.md)** — install paths and the three
   invocation modes (HTTP, MCP, Python).
6. **[`registry.md`](registry.md)** — registry transport (GitHub
   Releases v1), pack tarball layout, `pack_hash` discipline.
7. **[`integration-server.md`](integration-server.md)** — how
   `apxm-server` discovers and serves packs.
8. **[`integration-mcp.md`](integration-mcp.md)** — MCP-side surface:
   pack discovery and invocation through the MCP server.
9. **[`integration-codex.md`](integration-codex.md)** — Codex
   integration model: where a Codex skill becomes an APXM pack.
