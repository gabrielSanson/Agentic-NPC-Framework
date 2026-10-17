# Debugging: traces, call records, the CLI trace and the knowledge audit

## NPC traces

`NpcfTraceService.trace(world, npc)` (core, read-only) explains one NPC. It returns `{}` when the ID is not an NPC.
Fields:

- `npc`, `tick`, `time`
- `config`: display name, archetype, personalities, decision period, goal IDs, planner script path, schedule ID
- `needs` (sorted by ID), `location`, `tags`
- `goal`, `action` (also as `running`), `action_elapsed`, `plan`
- `beliefs`: every belief with its `source`, `confidence`, teller chain and tick
- `directives`: active directives that target this NPC
- `decisions`: decision records, oldest first
- `outcomes`: action outcomes
- `dialogue`: the last 10 turn records of this NPC (intent, addressee reason, outcome, LLM status, latency, failures)
- `hook_failures`: failure counters by hook script path, plus `total`

`NpcfRuntime.trace(npc)` returns the same dictionary plus `providers`, the last 10 provider call records.

## Provider call records

`NpcfProviderGateway.calls` keeps the last 32 requests (`NpcfProviderCallRecord`): provider, kind, status, latency,
`fell_back` (status is not `ok`) and `prompt`. Immediate `down`, `busy` and `dropped` answers are recorded too.
Headers are never recorded, so keys never appear in a record.

The prompt text is recorded only for GENERATE and CHOOSE providers, only when the project setting
`npcf/debug/trace_prompts` is true (off by default), and cut to 4000 characters. Audio bodies are never recorded.

## Command line trace

```text
godot --headless --path . -s res://addons/npcf/tools/npcf_cli.gd -- trace \
    --manifest res://packs/toy/pack.tres --scenario res://packs/toy/scenarios/basic.tres \
    --seed 1 --tick 200 --npc toy.ana
```

Steps a headless world `--tick` ticks and prints the NPC's trace as JSON. Exit codes: 0 success, 1 unknown NPC or
errors found, 2 usage.

## Knowledge-boundary audit

`NpcfKnowledgeAudit` is a debug recorder (R6.6). Set `world.audit = NpcfKnowledgeAudit.new()` to turn it on; it never
changes results and is off in normal runs.

It records every fact read made while an NPC decides (goal scoring, conditions, intent outcomes) or while a dialogue
prompt is built, and every fact handed to a belief store. `violations(world)` reports:

- a belief read of another entity's non-public fact when no earlier delivery of that fact to that NPC exists;
- any truth-view read of such a fact during a decision or prompt.

Tests: `tests/audit/test_knowledge_boundary.gd` runs three in-game days of dialogue and expects no violations, and
injects an undelivered belief to check that it is caught.

## Debug overlay

`NpcfDebugOverlay` (`addons/npcf/debug/npcf_debug_overlay.gd`) is a panel that shows `Npcf.trace(npc)` for one NPC
while the game runs. The runtime adds it as a child named `NpcfDebugOverlay` in `start()` and `load_game()`, and
removes it in `stop()`. It is added only in debug builds, or in release builds when the project setting
`npcf/debug/overlay_in_release` is true.

- F9 shows or hides the panel (hidden at first).
- F10 selects the next NPC in ID order, wrapping.
- A left click selects the nearest registered NPC within 48 px. The click still reaches the game.
- The tree has one item per top-level trace key; sections start collapsed and stay as the user left them. The
  panel refreshes every 0.5 s while visible.

The overlay is built in code (no `.tscn`) and never changes the world.
