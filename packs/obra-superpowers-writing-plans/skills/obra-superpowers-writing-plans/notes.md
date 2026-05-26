# Translation notes: writing-plans

APXM-AIR port of obra/superpowers `writing-plans`. The upstream
markdown lives verbatim in `upstream/SKILL.md` and remains the source
of truth for behavior; the AIR graph in `skill.air` makes the workflow
typed and dispatchable.

## Upstream sections to AIR nodes

| Upstream section          | AIR node(s)                                | Notes                                                     |
|---------------------------|--------------------------------------------|-----------------------------------------------------------|
| Overview + announce       | `announce_writing_plans` (cpu)             | Deterministic banner, no LLM call.                        |
| Scope Check               | `scope_check` (cpu)                        | Suggests splitting if the spec spans subsystems.          |
| File Structure            | `map_file_structure` (cpu)                 | Names files to create or modify; outputs a structure JSON.|
| Bite-Sized Task Granularity + Task Structure | `decompose_tasks` (gpu) `@reuse_group("writing_plans")` | Single GPU call produces task list; cached across reviews.|
| Plan Document Header      | `render_plan_header` (cpu)                 | Pure template fill from earlier nodes.                    |
| No Placeholders + Self-Review | `validate_self_review` (cpu)           | Hard gate: rejects placeholder phrases and missing tests. |
| Execution Handoff         | `render_execution_handoff` (cpu)           | Appends the subagent/inline choice prose.                 |
| Persist plan              | `persist_plan_document` (cpu)              | Writes the final markdown to the plans directory.         |

## Why a graph beats the markdown

- `decompose_tasks` is the only GPU-heavy node; gating it behind
  `scope_check` and `map_file_structure` means a misframed spec fails
  cheaply instead of burning synthesis tokens on a bad decomposition.
- `validate_self_review` becomes a runtime gate rather than a prose
  reminder, so a plan with "TBD" or "implement later" cannot reach the
  persist step.
- The reuse group on `decompose_tasks` lets the runtime fold repeated
  invocations against the prefix cache when the agent iterates on the
  same spec.

## Open questions

- Does `scope_check` benefit from being its own fan-out across each
  spec section, or is a single planner call enough? Default is single.
- Should `persist_plan_document` be a capability gate so untrusted
  callers cannot write to the plans directory? v1 leaves it ungated.

## Verification

The port is behaviorally equivalent when running the same spec through
`dekk apxm execute skill.apxmobj` and through a host agent following
`upstream/SKILL.md` produces a plan document of the same shape (header
+ task list + execution handoff) modulo phrasing. Manual diff is the
v1 acceptance criterion.
