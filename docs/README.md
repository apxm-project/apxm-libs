# `apxm-libs` documentation

Reading order:

1. **[`vision.md`](vision.md)** — what `apxm-libs` is and why a
   separate library catalog exists.
2. **[`architecture.md`](architecture.md)** — the pack model, loading
   modes, runtime execution, and lifecycle.
3. **[`manifests.md`](manifests.md)** — `pack.toml` + `skill.toml`
   schemas, provenance metadata, validation contract.
4. **[`integration-server.md`](integration-server.md)** — how
   `apxm-server` discovers and serves packs (env vars, REST surface,
   inventory).
5. **[`integration-codex.md`](integration-codex.md)** — Codex
   integration model: where a Codex skill becomes an APXM pack.
6. **[`integration-mcp.md`](integration-mcp.md)** — MCP-side surface:
   pack discovery and invocation through the MCP server.
7. **[`registry.md`](registry.md)** — registry transport (GitHub
   Releases v1), pack tarball layout, pack_hash discipline.
8. **[`backlog.md`](backlog.md)** — live remnants of the skill-runtime
   backlog: open gaps (G1–G6), unfinished steps, follow-up tickets.
9. **[`adr/`](adr/)** — Architecture Decision Records (locked
   decisions).

Most of the substantive docs land incrementally as part of the org-wide
doc reorg. The scaffold pages above exist as headers so that contributors
have stable anchors to link against while the substance migrates from
the apxm core repo.
