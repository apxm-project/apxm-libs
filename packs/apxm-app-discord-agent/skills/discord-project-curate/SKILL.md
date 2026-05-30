---
name: discord-project-curate
description: on_event curation contract for the always-listening Discord project agent — turns each channel message into project belief writes + an episode for the answer skill to draw on.
fallback: native curation
---

# Discord Project Curate

The `on_event` skill for an apxm-os agent listening to a Discord project channel.
Each message arrives as a `{ event, agent_context }` envelope; this skill must
extract durable project facts into `belief_writes` and log the message as an
`episode_append`.

## Input
JSON `{ event, agent_context }`:
```
{ "event": { "kind": "channel", "subject": "<channel_id>",
             "payload": { "message": { "content": "...", "author": {...} } } },
  "agent_context": { "belief_scope": "project.<name>.*", "beliefs": { ... } } }
```

## Required output — `results["curation"]`
```
{ "belief_writes":  [ { "key": "project.<name>.<slug>", "value": <json> } ],
  "episode_appends":[ { "event_type": "discord.message", "payload": <message> } ] }
```
Rules: write a belief only for durable facts (decisions, owners, deadlines,
status, links); keys MUST start with the agent's `belief_scope`; merge rather
than duplicate; always append one episode for the raw message.

## ⚠ Compile requirement
apxm-os applies belief writes only from the structured `curation` output token,
which requires a **compiled flow** — apxm-server's prompt-only path returns
`content`, not `results["curation"]`. The apxm compiler ingests **canonical AIR**
or a **Python frontend source** that emits AIR (the readable `flow … { }` DSL is
not accepted directly). So this skill ships as the authored contract/prompt; its
compiled flow (one LLM role producing the `curation` JSON above) is the remaining
step. The companion `discord-project-answer` skill runs prompt-only today.
