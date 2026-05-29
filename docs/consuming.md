# Consuming an `apxm-libs` pack

This guide covers the install path and the three ways an agent
invokes a skill from a pack: HTTP, MCP, and Python.

## Install

### From a GitHub Release

```
dekk apxm libs install <pack-id>==<version> --source github
```

Downloads `<pack-id>-<version>.tar.gz` from
`apxm-project/apxm-libs/releases/download/<pack-id>-<version>/`,
verifies hashes, and unpacks into `~/.apxm/libs/<pack-id>/`
(overridable via `APXM_LIBS_ROOT`).

### From a sibling clone

```
dekk apxm libs install <pack-id>
```

Without `--source github`, the installer copies from a sibling
`apxm-libs/packs/` checkout next to the apxm repo. Useful for
local development against an unreleased pack.

### Install-time verification

Three hash layers are checked on `install`:

| Layer | When | What if it fails |
|---|---|---|
| `pack_hash` (tarball BLAKE3) | After download, before unpack | `sys.exit` — the downloaded bytes do not match `pack.toml::pack_hash`. |
| `artifact_hash` (per-skill `skill.apxmobj` BLAKE3) | After unpack, before declaring success | `sys.exit` — `(pack_id, skill_id, expected, actual)`. |
| Wire-internal BLAKE3 (artifact payload) | On every subsequent `apxm-server` load | The runtime refuses to dispatch and surfaces a typed error; no panic. |

If you have ever tampered with an installed `.apxmobj` (one byte
is enough), the next `dekk apxm libs verify <pack-id>` will fail
clean and the next `apxm-server` load will refuse to dispatch.

**Empty `pack_hash` (unsealed packs).** A dev-built pack ships
`pack.toml [integrity].pack_hash = ""`. In that state `verify` cannot
check the tarball seal. The default (non-strict) behaviour is explicit:
it prints a `WARNING` that the seal is absent and falls back to
per-skill `artifact_hash` verification, so a tampered `.apxmobj` is
still caught when the skill carries its own hash. Pass `--strict`
(`dekk apxm libs verify --strict <pack-id>`) to turn an empty/missing
`pack_hash` into a hard failure — this is what CI and release gates
should use. Recommendation: `--strict` should become the default once
all shipped packs are sealed by the pack-compile workflow.

## Loader discovery

`apxm-server` finds installed packs by walking the
`APXM_SKILL_ROOTS` directory list (split with `std::env::split_paths`,
see `apxm-server/src/skill_resources.rs::parse_skill_roots`). The
loader only reads `APXM_SKILL_ROOTS`; `APXM_LIBS_ROOT` is the
install-path default for `dekk apxm libs install` and is not a loader
variable. Each pack's `skills/<skill-id>/` is discovered through
`find_manifest_dirs` and loaded into the server's `SkillLibrary`.

Point the loader at a libs root by including it explicitly:

```
APXM_SKILL_ROOTS="$HOME/.apxm/libs:/opt/clic/skills" apxm-server ...
# or via CLI: --skill-root $HOME/.apxm/libs --skill-root /opt/clic/skills
```

The v2 multi-skill pack layout is tracked in
[`pack-format.md`](pack-format.md).

To verify what the server sees:

```
dekk apxm libs list
```

The output reports `pack_id`, `version`, `source.kind`, and the
contained skill id for every pack visible to the loader.

## Invoking a skill

A skill has the same identity on every surface — the
`skill_id` from its `skill.toml`. The three surfaces below are
interchangeable; pick the one that fits your caller. Provenance
is recorded identically across them: the server logs the same
`(skill_id, version, artifact_hash)` triple regardless of how
the call arrived.

### HTTP

```
POST /v1/skills/<skill-id>/execute
Content-Type: application/json

{
  "args": ["..."]
}
```

`/v1/skills/<id>` returns the manifest. `/v1/skills/<id>/validate`
runs admission without executing. `/v1/skills/<id>/execute/stream`
returns Server-Sent Events for live progress.

A pinned-version call uses `<id>@<version>` in the path.

### MCP

The `apxm-server` MCP surface exposes:

- `apxm_skills_list` — enumerate installed skills.
- `apxm_skill_get` — fetch a manifest.
- `apxm_skill_validate` — admission preflight.
- `apxm_skill_call` — execute and return outputs.

Capability admission runs identically to the HTTP path
(`read_only` / `sandboxed` / explicit broader policy). A skill
whose declared `side_effect_policy` is not satisfied by the
caller's grant is rejected before execution starts.

### Python

```python
from apxm.libs import load

h = load("apxm-plan-as-graph")           # resolves @latest
h_pinned = load("apxm-orient@0.2.0")     # pinned version

result = h.invoke(task="Refactor the executor")
print(result.content)
print(result.results)
```

`load(skill_id)` posts to the running `apxm-server`'s
`/v1/skills/<id>` route to confirm the skill exists and capture
the manifest; `SkillHandle.invoke(**kwargs)` posts to
`/v1/skills/<id>/execute`. The kwargs map positionally onto the
skill's declared `inputs` in `skill.toml` — passing an unknown
kwarg raises before the HTTP call goes out.

`apxm.libs` reuses the module-level `httpx.AsyncClient` from
`apxm.execution`. There is exactly one HTTP transport for both
raw-AIR (`/v1/execute`) and named-skill (`/v1/skills/{id}/
execute`) calls. `_run_sync` makes `invoke()` safe to call from
inside a Jupyter cell or a synchronous test runner.

## Verifying an installed pack

```
dekk apxm libs verify <pack-id>
```

Recomputes the pack tarball's BLAKE3 and every contained
`skill.apxmobj`'s BLAKE3, and compares both against the recorded
hashes in `pack.toml` and each `skill.toml`. Use this after a
suspicious filesystem event, or as part of a recurring integrity
check.

## Uninstalling

```
dekk apxm libs uninstall <pack-id>
```

Removes `<APXM_LIBS_ROOT>/<pack-id>/`. The server picks up the
removal on its next discovery pass.
