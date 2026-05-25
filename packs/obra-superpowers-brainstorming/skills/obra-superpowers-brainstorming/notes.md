# Translation notes: brainstorming

Maps the upstream 9-step checklist to the typed AIR graph in
`skill.air`.

## Upstream → AIR

| Upstream step | AIR node(s) |
|---|---|
| 1. Explore project context | `read_project_context` (deterministic) |
| 2. Offer visual companion | `plan_check_visual` (CPU planner) |
| 3. Ask clarifying questions | `ideate_questions` (CPU, reuse_group "brainstorm") |
| 4. Propose 2-3 approaches | `propose_approach` × 3, parallel fan-out (CPU, reuse_group "brainstorm") |
| 5. Present design sections | `synthesize_design` (GPU-heavy) |
| 6. Write design doc | `persist_design_doc` (deterministic file write) |
| 7. Spec self-review | `validate_self_review` (CPU) |
| 8. User reviews written spec | handled by host agent, not the AIR graph |
| 9. Transition to implementation | downstream — `obra-superpowers-writing-plans` |

## Why a graph beats the markdown

- The 3 candidate approaches in step 4 are mutually independent — the
  runtime fans them out in parallel instead of asking the model to
  serialize.
- The `ideate_questions` and `propose_approach` nodes share a
  `reuse_group("brainstorm")`, so if the user pivots mid-conversation
  the runtime reuses the cached intent rather than re-paying for it.
- The `synthesize_design` node is the only GPU-heavy call; planner
  and ideation nodes route to a cheaper CPU model via dispatch hints.

## Verification

Run the same `task` through `dekk apxm execute skill.air` and through
a host agent following `upstream/SKILL.md`. The structural outputs
(approach list, design sections, design doc path) should be
indistinguishable.
