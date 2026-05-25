# apxm-libs

The compiled-skill library for [APXM](https://github.com/apxm-project/apxm).

> Software scaled when code became libraries. Agents will scale only when
> skills do — compiled, versioned, linkable, and governed.
> *(VISION.md)*

Each entry under `skills/` is a self-contained compiled skill bundle
(`skill.toml` + `SKILL.md` + optional `skill.air` + `skill.apxmobj`)
that the APXM runtime can load, validate, and execute.

## Install

### v1 — sibling clone (current)

`apxm-server` auto-discovers a sibling `apxm-libs/skills/` directory
relative to your `apxm` checkout. Clone the two repos next to each
other:

```bash
git clone https://github.com/apxm-project/apxm.git
git clone https://github.com/apxm-project/apxm-libs.git
# from inside the apxm checkout, apxm-server picks up ../apxm-libs/skills automatically
```

### v1b — user install

Place the library under your home directory:

```bash
git clone https://github.com/apxm-project/apxm-libs.git ~/.apxm/libs
```

`apxm-server` auto-discovers `~/.apxm/libs/` regardless of where you
run it from.

### v1c — explicit override

```bash
export APXM_SKILL_ROOTS=/path/to/apxm-libs/skills
apxm-server
```

Or pass `--skill-root /path/to/apxm-libs/skills` to `apxm-server` /
`apxm-mcp-server` directly.

### v2 — registry install (planned, R.9)

```bash
dekk apxm libs install apxm-plan-as-graph        # download + hash-verify + install
dekk apxm libs list                              # what's installed
dekk apxm libs search <query>                    # query the registry
```

## What's here

```
skills/
    apxm-plan-as-graph/    Plan-as-graph dispatcher (the original
                           bundled skill; seeds the registry)
```

More packs land as R.8 ships:

- `apxm-orient` — read-only project orientation (R.8 priority)
- `apxm-demos-benchmarks` — benchmark authoring (R.8 priority)
- `apxm-author-python`, `apxm-compiler-pass`, `apxm-runtime-backends`,
  `apxm-server-mcp`, `apxm-quality-eval`, `apxm-design-docs` (R.8.4)

## Skill bundle layout

Each bundle conforms to `apxm-skill::SkillManifest` (defined in
`apxm/crates/core/apxm-skill/src/lib.rs`):

```
skills/<skill-id>/
    skill.toml          Manifest (skill_id, version, capabilities,
                        isolation_policy, entry_flow, inputs, outputs,
                        artifact_hash for v2 verification)
    SKILL.md            Source (markdown with YAML frontmatter)
    prompt.md           Optional templated prompt
    schema.json         Optional input/output schema
    skill.air           Optional compiled AIR (entry_flow target)
    skill.apxmobj       Optional pre-built artifact (built from skill.air)
    examples/           Optional executable examples
```

## Contributing a new skill

1. Pick a `skill_id` not in use; bump `version` per SemVer.
2. Author `skill.toml` + `SKILL.md`.
3. If the skill is a flow, author `skill.air` and ensure
   `dekk apxm compile skill.air` succeeds.
4. Run the local validator (lands with R.8.3):
   ```bash
   python tools/validate_skill.py skills/<skill-id>
   ```
5. Open a PR. Maintainers tag releases when a bundle is ready to ship
   to the v2 registry (R.9).

For the design rationale, read
[`apxm/docs/design/apxm-aware-codex-skill-libraries.md`](https://github.com/apxm-project/apxm/blob/main/docs/design/apxm-aware-codex-skill-libraries.md).

## Related repos

- [apxm-project/apxm](https://github.com/apxm-project/apxm) — runtime
  that loads these bundles
- [apxm-project/apxm-eval](https://github.com/apxm-project/apxm-eval) —
  evaluation harness + preregistrations
