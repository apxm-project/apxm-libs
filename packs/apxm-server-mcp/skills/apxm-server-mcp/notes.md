# apxm-server-mcp — entry flow design

The skill is a *cross-surface registration planner*. A new server
surface (HTTP route, MCP tool, A2A endpoint) requires coherent edits
across the handler, the route/tool registration, the MCP manifest,
the Dekk CLI wrapper, and a smoke test. Missing any one of those
ships a half-wired surface.

## Decision tree

1. **Surface classification** (`surface` input or inferred from
   `task`).
   - `rest`: HTTP route in `apxm-server` axum router.
   - `mcp`: MCP tool registered through the installer script.
   - `a2a`: A2A bridge endpoint plus capability advertisement.
2. **Cross-surface fanout**. A REST route that should also be
   reachable as an MCP tool needs both the route handler and the
   MCP tool wrapper that calls it. The skill emits the fanout
   list explicitly so the operator does not ship REST-only and
   discover later that MCP clients cannot reach the feature.

## Touch-point template (REST route + MCP fanout)

```
crates/tools/apxm-server/src/routes/<route>.rs    # axum handler
crates/tools/apxm-server/src/router.rs            # router registration
crates/tools/apxm-server/src/contract.rs          # route-path constant
tools/scripts/apxm_mcp_install.py                 # MCP tool entry
.dekk.toml                                        # CLI wrapper (if user-facing)
tests/server/<route>_smoke.rs                     # request roundtrip
docs/api/<route>.md                               # if user-facing
```

## Contract-string discipline

Route paths, env var names, response-marker strings, and MCP tool
names are all *contract strings*. They live in single-source-of-truth
constants modules (`crates/tools/apxm-server/src/contract.rs` for
server-side, `apxm.contract` for Python-side), never as literals in
handlers or registration code.

## Why no LLM call in the entry flow

Registration planning is deterministic. The interesting work — what
the route or tool actually does — is the operator's. The skill's
job is to make sure the registration paperwork lands so the surface
is reachable from every client APXM exposes.

## Hard contracts surfaced in the touch-point list

- Server middleware must use raw ASGI on the Python side, not
  Starlette's `BaseHTTPMiddleware`. The
  `feedback_basehttpmiddleware_breaks_chat` incident is the
  cautionary tale: `BaseHTTPMiddleware` proxies receive via a queue
  that treats listen-for-disconnect polls as disconnects and
  silently nulls chat responses.
- MCP tool names match the tool's contract name exactly. Drift
  between the route name, the MCP tool name, and the Dekk wrapper
  name produces silent client failures.
- Every new user-facing route gets a Dekk wrapper. Raw `curl` to
  the server is for debugging only.
