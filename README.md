# apxm-libs

Compiled, hash-pinned, importable skill library for
[`apxm-server`](https://github.com/apxm-project/apxm).

Each pack is a versioned bundle containing exactly one skill plus
optional shared resources. Packs install into `~/.apxm/libs/<pack-id>/`
and are loaded by `apxm-server` via `APXM_SKILLS_PATH`. Calls go
through HTTP, MCP, or the `apxm.libs` Python module — provenance
records the same `(skill_id, version, artifact_hash)` regardless of
surface.

## Documentation

- [`docs/pack-format.md`](docs/pack-format.md) — directory layout,
  `pack.toml` / `skill.toml` schemas, embedded manifest section,
  three-layer hash chain, v1 singleton convention.
- [`docs/authoring.md`](docs/authoring.md) — scaffold → AIR graph
  → `dekk apxm libs build` → publish.
- [`docs/consuming.md`](docs/consuming.md) — install path, install-
  time verification, the three call surfaces (HTTP, MCP, Python).
- [`apxm/docs/design/skill-library-model.md`](https://github.com/apxm-project/apxm/blob/main/docs/design/skill-library-model.md)
  — the design model: classical `.h`/`.c`/`.o`/`.a`/`ld`/`ld.so`
  analogues for the APXM artifact stack.
- [`REGISTRY.md`](REGISTRY.md) — pack-release transport (GitHub
  Releases as v1; SemVer per pack).

## Install

```bash
dekk apxm libs install <pack-id>                          # sibling clone
dekk apxm libs install <pack-id>==<version> --source github
dekk apxm libs list
dekk apxm libs verify <pack-id>
```

Install verifies the tarball `pack_hash`, every per-skill
`artifact_hash`, and the wire-internal BLAKE3 on first load. Any
mismatch fails clean with `(pack_id, skill_id, expected, actual)` —
no panic, no silent skip.

## Use

```python
from apxm.libs import load

h = load("apxm-plan-as-graph")           # @latest
h_pinned = load("apxm-orient@0.2.0")     # pinned

result = h.invoke(task="...")
print(result.content, result.results)
```

HTTP and MCP equivalents in [`docs/consuming.md`](docs/consuming.md).

## Pack classes

| Class | Pack id convention | Provenance |
|---|---|---|
| APXM-development | no prefix (`apxm-orient`) | `[source].kind = "original"` |
| Port (obra/superpowers etc.) | `<source>-<name>` (`obra-superpowers-brainstorming`) | `[source].kind = "port"` with `upstream`, `upstream_commit`, `upstream_license` |

Port packs ship the upstream `SKILL.md` verbatim under
`skills/<id>/upstream/` and document the markdown → AIR translation
in `notes.md`.

## Catalog

APXM-development packs:

- `apxm-plan-as-graph` — plan-as-graph dispatcher
- `apxm-orient` — read-only project orientation
- `apxm-design-docs` — `docs/design/` editor with overclaim guard
- `apxm-quality-eval` — quality-eval harness work
- `apxm-author-python`, `apxm-compiler-pass`,
  `apxm-runtime-backends`, `apxm-server-mcp`,
  `apxm-demos-benchmarks`

obra/superpowers port packs (14):

```
obra-superpowers-{brainstorming, systematic-debugging,
test-driven-development, verification-before-completion,
writing-plans, executing-plans, dispatching-parallel-agents,
requesting-code-review, receiving-code-review, using-git-worktrees,
finishing-a-development-branch, subagent-driven-development,
writing-skills, using-superpowers}
```

## Validating a pack

```bash
python tools/validate_pack.py packs/<pack-id>
python tools/validate_pack.py --require-artifact packs/<pack-id>
```

`--require-artifact` is the strict mode used by `libs publish`; it
rejects any pack whose skills lack a compiled `.apxmobj` or whose
recorded `artifact_hash` doesn't match the bytes on disk. Without
the flag, scaffolds (no `.apxmobj` yet) pass — authoring stays
frictionless.

## Contributing

1. Choose a pack id (APXM original: no prefix; port:
   `<source>-<name>`).
2. Scaffold per [`docs/authoring.md`](docs/authoring.md).
3. `python tools/validate_pack.py packs/<pack-id>`.
4. Open a PR. Maintainers tag releases.

## Related repos

- [`apxm-project/apxm`](https://github.com/apxm-project/apxm) —
  runtime, compiler, server.
- [`apxm-project/apxm-eval`](https://github.com/apxm-project/apxm-eval)
  — evaluation harness + preregistrations.
- [`apxm-project/apxm-gui`](https://github.com/apxm-project/apxm-gui)
  — web dashboard.
