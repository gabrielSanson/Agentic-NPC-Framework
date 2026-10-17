# Benchmarks

Machine: CI container, headless, debug build (Godot 4.7.2 stable, `/usr/local/bin/godot`).
The reference-machine figure from the spec is still to be measured on a release export.

## Headless bench (CLI)

Command, run from the repo root:

```bash
godot --headless --path . -s res://addons/npcf/tools/npcf_cli.gd -- bench \
	--manifest res://packs/toy/pack.tres --scenario res://packs/toy/scenarios/basic.tres \
	--npcs 50 --ticks 1440 --seed 7
```

Output of one run (50 NPCs, 1,440 ticks, toy pack, `basic` scenario):

```
bench: 50 npcs, 1440 ticks, seed 7
median_ms=1.5650
p99_ms=43.0670
max_ms=75.3060
capped_frames_at_speed_16=0 of 3600 frames at 60 fps
```

Each sample is one `world.step()` measured with `Time.get_ticks_usec()`. The first ticks include the
decision and delivery work of a fresh population; p99 and max are dominated by the busiest decision ticks.
`capped_frames_at_speed_16` simulates 3,600 frames at 60 fps and 16x speed against `max_ticks_per_frame`.

## Before and after the delivery and need changes

Same command, same machine, three runs each. Figures are the median of the three runs' medians and the
ranges across runs.

| Metric | Before (`origin/main`) | After (`perf-ticks`) |
| --- | --- | --- |
| median_ms | 1.46 to 1.58 | 0.94 to 1.09 |
| p99_ms | 41.996 to 44.100 | 17.029 to 17.964 |
| max_ms | 57.081 to 113.128 | 26.478 to 30.917 |

Per-phase totals over the 1,440-tick run, from the throwaway profiler (ms, one run each):

| Phase | Before | After |
| --- | --- | --- |
| clock | 13.6 | 12.0 |
| inputs | 3.2 | 3.8 |
| director | 5.1 | 4.8 |
| needs | 1,787.4 | 873.9 |
| actions | 356.0 | 328.2 |
| delivery | 1,710.8 | 417.5 |
| decisions | 492.1 | 488.0 |
| checks | 388.5 | 391.0 |

The p99 target (4 ms) is not met. On spike ticks the remaining cost is spread across delivery (belief
writes for every witness), the decision phase (about 33 NPC decisions per spike tick) and the actions phase.
The median target (2 ms) is met.

## Round 2: behaviour-preserving speedups (perf-ticks-2)

Cloud sandbox, headless, debug build (Godot 4.7.2). Same command as above. Each row is the median of three runs of
the bench's `median_ms`, `p99_ms` and `max_ms`. The sandbox drifts by about 1 ms between sessions, so the last
table is the reliable comparison: `origin/main` and the branch, interleaved in one session, three runs each.

| Step (cumulative) | Median (ms) | p99 (ms) | Max (ms) |
| --- | --- | --- | --- |
| Before (`origin/main`, 1e9ccdb) | 6.04 | 24.9 | 44.2 |
| a. invariant checks read beliefs in place | 3.29 | 23.0 | 40.9 |
| c. belief key built once per event | 2.98 | 20.1 | 32.3 |
| d. location-index lookup caches | 3.81 (same-session `HEAD` before d: 3.8 to 4.1) | 20.9 | 32.6 |
| e. `take_due` sorts by integer key | 2.88 | 20.1 | 32.2 |

Interleaved A/B, three runs each, same session (median of the three runs' values, range of the medians):

| Build | Median (ms) | p99 (ms) | Max (ms) |
| --- | --- | --- | --- |
| `origin/main` | 5.98 (5.72 to 6.16) | 24.57 | 40.45 |
| `perf-ticks-2` (a, c, d, e) | 3.18 (2.65 to 3.51) | 20.21 | 32.32 |

Not kept: fix b (per-recipient allocations). Memory records cannot be shared between recipients because
`NpcfMemoryLog.append` assigns each record its own `id`, and a recipient-only iteration measured no gain. Fix f
is in a separate branch.

The p99 target (4 ms) is still not met in a debug build. See `slow-ticks-findings.md`.

## Bench scene (runtime, 2D)

`samples/toy_room/bench.tscn` runs the same population through the `Npcf` runtime, one 60 fps frame at a time,
with a readout. Run with `--quit-after-bench` to exit when the run finishes:

```bash
godot --headless --path . res://samples/toy_room/bench.tscn -- --quit-after-bench
```

Output of one run:

```
bench done: 50 NPCs, 1440 ticks, median 1.318 ms, p99 18.199 ms, max 119.166 ms, capped 0
```

The scene's samples are the time of each frame that ran a tick, divided by the ticks it ran. It includes the
runtime's signal emission and the 2D adapters, so it is slower than the bare step.

## CakeWorks starter (acceptance suite, C6b)

Wall time of one seed in `examples/cakeworks/tests/test_starter_acceptance.gd`: world build plus 4,320 ticks (3 days)
of the `cw.starter` scenario, headless, no providers. Measured with `Time.get_ticks_msec()` inside the suite; one run.
The whole example suite (8 cases) takes about 5 s.

| Seed | Wall ms | Events logged | Complaints |
| --- | --- | --- | --- |
| 1 | 886 | 727 | 53 |
| 2 | 996 | 754 | 46 |
| 3 | 1,013 | 747 | 44 |
| 5 | 882 | 756 | 46 |
| 8 | 893 | 720 | 51 |
