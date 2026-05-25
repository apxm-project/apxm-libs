---
name: apxm-server-mcp
description: Coherent edits across the apxm-server REST routes, MCP tool surface, and A2A bridge — keeps handler + registration + Dekk + manifest in sync.
fallback: read crates/tools/apxm-server/src/ + tools/scripts/apxm_mcp_install.py
---

# APXM Server / MCP

Use this skill when adding or changing a server surface (HTTP route,
MCP tool, A2A endpoint). The skill enforces the cross-file
registration discipline so a new route doesn't ship without its MCP
manifest entry and Dekk wrapper.

## Scaffold status

Not yet implemented — `skill.air` and `skill.apxmobj` are absent.
