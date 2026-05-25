# apxm-libs

The compiled-skill library for [APXM](https://github.com/apxm-project/apxm).

> Software scaled when code became libraries. Agents will scale only when
> skills do — compiled, versioned, linkable, and governed.
> *(VISION.md)*

`apxm-libs` is a catalog of **packs**. Each pack is a versioned,
install-as-a-unit bundle containing exactly one skill (singleton model):

```
packs/<pack-id>/
    pack.toml                     # pack manifest + provenance
    README.md                     # pack docs
    skills/<skill-id>/
        skill.toml                # SkillManifest
        SKILL.md                  # source markdown + frontmatter
        skill.air                 # optional compiled AIR
        skill.apxmobj             # optional artifact
        upstream/SKILL.md         # original (port packs only)
        notes.md                  # translation notes (port packs)
```

The runtime loads packs via the existing `apxm-skill::SkillManifest`
contract (defined in
`apxm/crates/core/apxm-skill/src/lib.rs`); packs add provenance
metadata on top — every pack declares `[source].kind` as either
`original` (APXM-authored) or `port` (re-expression of an upstream
skill).

## Two pack classes

| Class | Pack id convention | Example |
|---|---|---|
| APXM-development | no source prefix | `apxm-orient`, `apxm-plan-as-graph` |
| obra/superpowers port | `obra-superpowers-<name>` | `obra-superpowers-brainstorming` |

Ports re-express obra/superpowers community skills (MIT, at
`github.com/obra/superpowers`) as typed AIR graphs. The original
`SKILL.md` is shipped verbatim under `skills/<id>/upstream/`; the
APXM port adds the AIR graph, dispatch hints, cache-reuse groups, and
session traces that let the runtime fold redundant LLM calls and
replay from intermediates.

## Install

### Sibling clone

`apxm-server` auto-discovers a sibling `apxm-libs/packs/` directory:

```bash
git clone https://github.com/apxm-project/apxm.git
git clone https://github.com/apxm-project/apxm-libs.git
```

### User install

```bash
git clone https://github.com/apxm-project/apxm-libs.git ~/.apxm/libs
```

`apxm-server` auto-discovers `~/.apxm/libs/packs/` regardless of cwd.

### Explicit override

```bash
export APXM_SKILL_ROOTS=/path/to/apxm-libs/packs
apxm-server
```

Or pass `--skill-root /path/to/apxm-libs/packs` to `apxm-server` /
`apxm-mcp-server`.

### Registry (planned)

```bash
dekk apxm libs install <pack-id>        # download + blake3-verify + install
dekk apxm libs list                     # installed packs
dekk apxm libs search <query>           # query the registry
```

## What's here

### APXM-development packs (singleton each)

```
packs/
    apxm-plan-as-graph/              Plan-as-graph dispatcher (shipped)
    apxm-orient/                     Read-only project orientation
    apxm-demos-benchmarks/           Benchmark authoring
    apxm-author-python/              Python frontend authoring
    apxm-compiler-pass/              Compiler pass authoring
    apxm-runtime-backends/           Runtime/backend adapter work
    apxm-server-mcp/                 apxm-server REST/MCP surface
    apxm-quality-eval/               Quality-eval harness work
    apxm-design-docs/                docs/design/ editor with overclaim guard
```

### obra/superpowers port packs (14 singletons)

```
packs/
    obra-superpowers-brainstorming/             (priority, AIR compiled)
    obra-superpowers-systematic-debugging/      (priority, AIR compiled)
    obra-superpowers-test-driven-development/
    obra-superpowers-verification-before-completion/
    obra-superpowers-writing-plans/
    obra-superpowers-executing-plans/
    obra-superpowers-dispatching-parallel-agents/
    obra-superpowers-requesting-code-review/
    obra-superpowers-receiving-code-review/
    obra-superpowers-using-git-worktrees/
    obra-superpowers-finishing-a-development-branch/
    obra-superpowers-subagent-driven-development/
    obra-superpowers-writing-skills/
    obra-superpowers-using-superpowers/
```

Non-priority port packs ship pack.toml + verbatim upstream SKILL.md +
translation notes; their `skill.air` lands incrementally.

## Validating a pack

```bash
python tools/validate_pack.py packs/<pack-id>            # one pack
python tools/validate_pack.py packs/*/                   # everything
```

The validator parses `pack.toml`, confirms `[source]` matches its
kind, confirms the contained skill bundle parses against
`SkillManifest`, and recomputes `artifact_hash` when a `.apxmobj` is
present.

## Contributing a new pack

1. Choose a pack id: APXM-authored work uses no prefix; ports prefix
   with `<source>-` (e.g. `obra-superpowers-<skill>`).
2. Author `pack.toml` with the appropriate `[source].kind`.
3. Author `skills/<skill-id>/skill.toml` + `SKILL.md`.
4. For port packs: include the upstream `SKILL.md` verbatim under
   `skills/<skill-id>/upstream/`, pin `upstream_commit` and
   `upstream_license` in `pack.toml [source]`, and write `notes.md`
   describing the markdown → AIR translation.
5. Run `python tools/validate_pack.py packs/<pack-id>`.
6. Open a PR. Maintainers tag releases when a pack is ready to ship to
   the registry.

## Related repos

- [apxm-project/apxm](https://github.com/apxm-project/apxm) — runtime
  that loads these packs
- [apxm-project/apxm-eval](https://github.com/apxm-project/apxm-eval) —
  evaluation harness + preregistrations
