# Translation notes: dispatching-parallel-agents

Maps the upstream markdown sections to APXM-AIR nodes. The runtime
implementation lands incrementally; this file is the spec.

## Upstream → AIR

| Upstream section | Suggested AIR node(s) |
|---|---|
| (fill in per upstream/SKILL.md) | (fill in) |

## Open questions

- Which steps can fan out in parallel?
- Which steps benefit from cache reuse?
- Where does a Validate gate prevent expensive Synthesize calls?

## Verification

After authoring `skill.air`, the port is considered behaviorally
equivalent when its output on a representative task is structurally
indistinguishable from running the upstream markdown skill on the
same task (manual diff acceptable).
