# Integration with Codex (and other coding agents)

This page describes how Codex (and similar coding agents — Claude
Code, Aider, Cursor) become APXM-aware, the conversion pipeline that
turns a `SKILL.md` into a pack, and the initial APXM-development pack
set shipped by this repo. The server-side surface those packs are
loaded into lives in [`integration-server.md`](integration-server.md);
the MCP tools those agents call lives in
[`integration-mcp.md`](integration-mcp.md).

## The "wrap, don't rewrite" path

Codex (and the other agents) does not need to be rewritten to become
APXM-aware. The first integration layer is additive — five rings, from
outermost to innermost:

1. **Repo-root conventions.** APXM's repo-root `CLAUDE.md`/`AGENTS.md`
   teach the host agent the local conventions: prefer `dekk apxm ...`,
   ignore `external/vllm` unless asked, use sessions and metrics for
   debugging, prefer compile-only checks when no live backend is
   reachable.
2. **Repo-local skills.** `.agents/skills/` packages encode the
   APXM-specific workflows the host agent should follow: build, test,
   debug, benchmark, compiler-pass work, server/MCP work, quality
   evaluation.
3. **Node workspaces.** APXM-generated node workspaces provide
   task-specific `AGENTS.md` and copied skills for spawned Codex
   nodes; the host doesn't have to plumb context through itself.
4. **MCP tools.** APXM MCP tools let Codex validate AIR, inspect the
   AIS contract, compile graphs, and query the skill library by
   manifest identity.
5. **APXM execution.** When the task needs orchestration, evidence,
   replay, or optimization, APXM executes the compiled skill graph
   directly; Codex consumes the structured result rather than
   re-deriving it from prose.

Codex stays the shell; APXM is the execution substrate. That matches
the APXM vision's "wrap, do not rewrite" path.

## Discovery surfaces that already exist in apxm core

| Surface | Role |
| --- | --- |
| `.agents/skills` | `SkillResolver` scans repo-local skill directories containing `SKILL.md`. |
| Generated `AGENTS.md` | `ContextAssembler` renders Codex node context and references available skills, so Codex can be made APXM-aware per node without rewriting Codex. |
| ACP profiles | `apxm-acp` profile templates include `codex`, permissions, env, and capability servers. APXM can spawn Codex as a subprocess and provision capabilities. |
| `apxm-server` | HTTP gateway for execution, capabilities, agents, tasks, checkpoints, MCP, and A2A. Source of truth for the shared skill-library API. |
| `apxm-mcp-server` | Stdio MCP server exposes APXM compiler/runtime tools and `skill://` resources. External agents call APXM tools and discover packs without shelling out or copying per-agent skill directories. |
| Session artifacts | Execute/run paths emit session directories, metrics, traces, and node outputs — the evidence layer for evaluation and debugging. |
| Quality/eval tools | `quality_eval`, `ablation`, `trace_diff`, and `benchmark_e2e.py` measure pack runs. |

The important architectural decision: skill libraries are served by
`apxm-server`, not by the GUI. The GUI can display and manage packs,
but the server owns discovery, metadata, compilation status,
capability checks, and (eventually) dynamic loading. Codex and MCP
clients consume that same server surface so there is one inventory,
not three.

## Skill conversion pipeline

A source skill (`SKILL.md` plus support files) is converted into an
APXM pack by a `skill-to-air` frontend. The conversion can be
agent-assisted, but the load-bearing output must be structured and
auditable — never "trust the LLM, it compiled."

Recommended pipeline:

1. **Parse.** `SKILL.md` frontmatter and markdown are parsed with
   structured parsers, not free-form regex.
2. **Normalize to `SkillSpec`.** Name, triggers, anti-triggers,
   prerequisites, ordered steps, decision points, resources, scripts,
   expected outputs, verification steps.
3. **Map to AIS.** Instructions become reasoning nodes, scripts become
   registered capabilities, references become explicit resource reads,
   checks become verification/tool nodes, branches become typed
   control flow, joins become explicit synchronization.
4. **Emit `skill.air` and `skill.toml`.** The `skill.toml` conforms to
   the `SkillManifest` schema from apxm core's `apxm-skill` crate
   (`crates/core/apxm-skill/src/lib.rs`).
5. **Validate.** Round-trip checks: O0 compile, O2 compile, decompile,
   compare. Use the apxm core compiler (`dekk apxm compile`,
   `dekk apxm validate`).
6. **Write `conversion-report.json`.** Unmapped sections, inferred
   decisions, assumptions, missing capabilities, risk flags. The
   converter must not silently turn vague prose into production AIR.
   Any LLM-inferred graph structure is **provisional** until
   validation and tests approve it.

For port packs, the pipeline additionally pins
`upstream`, `upstream_path`, `upstream_commit`, and `upstream_license`
in `pack.toml [source]`, keeps the original `SKILL.md` verbatim under
`skills/<skill-id>/upstream/`, and writes a `notes.md` describing the
markdown → AIR translation choices.

## Codex node integration ring-by-ring

### Ring 1: repo-root conventions

Already in place. Codex picks up `CLAUDE.md`/`AGENTS.md` from the
repo it's working in. APXM's root files teach the agent how to use
`dekk apxm ...` and how to read sessions/metrics.

### Ring 2: repo-local skills

Already in place. APXM's `.agents/skills/` ships the workflow
skills. The packs `apxm-libs` exports (see "Initial APXM skill pack"
below) are a superset of these, intended to also work in repos that
are *not* the apxm core repo (for example, working on a downstream
project that depends on `apxm`).

### Ring 3: per-node workspaces

`ContextAssembler` in apxm core renders task-specific `AGENTS.md` and
copies resolved source skills into per-node session directories. This
is the bridge that lets a spawned Codex subprocess see the right
skills without the parent agent having to assemble context manually.

### Ring 4: MCP tools

`apxm-mcp-server` exposes:

- `apxm_skills_list`
- `apxm_skill_get`
- `apxm_skill_validate`
- `apxm_skill_call`
- `apxm_skill_explain`
- (future) `apxm_skill_compile`

…plus `skill://` resources for `SKILL.md`, `_manifest`, `prompt.md`,
`schema.json`, and `examples/*`. Codex calls these to discover and
invoke packs by manifest identity instead of copying prose into each
host. The full tool surface is documented in
[`integration-mcp.md`](integration-mcp.md).

### Ring 5: APXM execution

When the task benefits from orchestration, evidence, replay, or
optimization, Codex invokes a pack through `apxm-server`. The
execution sequence, the rejected inputs, and the streaming events are
documented in [`integration-server.md`](integration-server.md).

## Initial APXM skill pack

The first repo-local APXM-aware pack set focuses on workflows that
currently require local project knowledge. Each pack is a singleton:
one skill, one entry flow.

| Pack | Purpose |
| --- | --- |
| `apxm-orient` | Read the right docs and crate boundaries before changing code. Deterministic, no LLM calls. |
| `apxm-author-python` | Author Python frontend workflows and inspect emitted AIR. |
| `apxm-compiler-pass` | Develop or debug AIS/MLIR compiler passes. |
| `apxm-runtime-backends` | Work on runtime scheduling, backend routing, and vLLM hints. |
| `apxm-server-mcp` | Modify REST/MCP/A2A server surfaces coherently. |
| `apxm-quality-eval` | Run quality fixtures, budgets, judges, and claim checks. |
| `apxm-demos-benchmarks` | Work on demos, benchmark harnesses, and reports. |
| `apxm-design-docs` | Update conceptual docs without overclaiming implementation state. |
| `apxm-plan-as-graph` | Plan-as-graph dispatcher (the existing flagship pack). |

All nine ship in this repo under `packs/`. The first batch to lift
from scaffold to fully compiled is `apxm-orient`,
`apxm-demos-benchmarks`, `apxm-plan-as-graph` (already shipped),
`apxm-server-mcp`, `apxm-quality-eval`, and `apxm-compiler-pass`.

In parallel, the catalog ships 14 obra/superpowers port packs (MIT,
from `github.com/obra/superpowers`) re-expressed as typed AIR graphs;
see the repo `README.md` for the current list and per-pack status.

## Why these workflows first

The APXM-development packs cover the slice of work where the failure
mode of "ask Codex to do it from cold context" is most costly:

- **Orientation** is repeatable and load-bearing — the same doctor
  output, the same crate map, the same recent-commits scan should
  happen at the start of every nontrivial session. Encoding it as a
  pack avoids one-off agent improvisation.
- **Compiler pass work** has hard rules (canonical pass list, build +
  codegen cadence, `apxm-core` as the only AIS owner) that are easy
  to violate; the pack encodes the rules.
- **Server/MCP work** spans multiple coupled crates and is one of the
  easiest places to forget a route registration or contract constant.
- **Quality eval and demos/benchmarks** are evidence-bearing surfaces
  where a missed step (preregistration, artifact placement, lint
  pass) silently invalidates the run.
- **Design docs** are the easiest place to overclaim implementation
  state; the pack enforces the "what shipped" vs "what's planned"
  separation.

The port packs cover the orthogonal axis: general agent practice
(brainstorming, TDD, systematic debugging, code review, plan
authoring, worktree discipline) that any team running coding agents
benefits from, re-expressed as typed graphs so APXM can fold redundant
LLM calls and replay from intermediates.

## What Codex should not do

- Do not rewrite Codex. Wrap.
- Do not make dynamic execution the first milestone. Static
  precompiled artifacts first; dynamic loading is gated.
- Do not treat generated AIR as correct because it compiles. The
  validator and tests are the source of truth.
- Do not duplicate large docs into every pack. Cross-link instead.
- Do not make the GUI the source of truth for skill discovery.
  `apxm-server` is.
- Do not infer ACP subprocess token/cost from elapsed wall time.
  Report token/cost only when the ACP adapter or provider reports
  usage into APXM token accounting.
- Do not scan or import `external/vllm` as an ordinary APXM skill
  source.
