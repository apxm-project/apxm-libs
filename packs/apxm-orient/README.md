# apxm-orient

Gateway pack. Runs deterministic project orientation against an APXM
checkout (doctor JSON, crate map, recent commits, branch divergence,
companion-repo presence) and emits a structured snapshot. No LLM
calls; pure introspection.

## Install

```bash
dekk apxm libs install apxm-orient
```

## Contents

- `skills/apxm-orient/skill.toml`
- `skills/apxm-orient/SKILL.md`
- `skills/apxm-orient/notes.md` — probe sequence + output schema

## Status

Scaffold. `notes.md` specifies the probe sequence; `skill.air` lands
once the runtime side ships.
