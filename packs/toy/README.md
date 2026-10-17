# Toy pack

A small test pack (namespace `toy`, framework 0.2.0 to 0.3.0) used by the framework tests and as an
example of the pack layout. Every file is listed once below.

- `pack.tres`: the manifest; lists every definition the pack contributes.
- `sim.tres`: simulation settings; sets the player entity to `toy.player`.
- `facts/discoveries.tres`: `toy.discoveries`, a bounded global counter of discoveries.
- `facts/safe.tres`: `toy.safe`, a public location fact saying whether a place is safe.
- `facts/sighting.tres`: `toy.sighting`, a private, shareable location fact saying a sighting happened there.
- `needs/energy.tres`: `toy.energy`, drains by 1 per tick and has a `toy.tired` threshold at 200.
- `needs/curiosity.tres`: `toy.curiosity`, grows by 1 per tick.
- `social/trust.tres`: `toy.trust`, a directed relationship dimension from -100 to 100 with bands wary, neutral and trusting.
- `social/liking.tres`: `toy.liking`, a directed relationship dimension from -100 to 100 with bands cold, neutral and warm.
- `social/social.tres`: the social definition: witnesses of `toy.chatted` gain 2 liking toward the speaker; the tag transitions `toy.tire_out` (energy below 200 adds `toy.weary`) and `toy.recover` (energy at least 500 removes it).
- `director/idle_pressure.tres`: `toy.idle_pressure`, a 0 to 100 macro variable that rises by 10 for every `toy.chatted`.
- `director/director.tres`: the Director: one rule, `toy.back_to_work`, checked every 30 ticks, emits a `toy.work` directive (priority 0.5, 60 ticks) for NPCs without `toy.weary` once the pressure is at least 30.
- `events/chatted.tres`: `toy.chatted`, a local event with no payload.
- `events/spotted.tres`: `toy.spotted`, a local event, salience 60, that tells witnesses a sighting at the location. Nothing in the toy day emits it.
- `locations/graph.tres`: the location graph and its three bidirectional edges.
- `locations/home_a.tres`: location `toy.home_a`, tagged `toy.home`.
- `locations/home_b.tres`: location `toy.home_b`, tagged `toy.home`.
- `locations/yard.tres`: location `toy.yard`, tagged `toy.outdoors`.
- `locations/workshop.tres`: location `toy.workshop`, tagged `toy.work_place`.
- `actions/rest.tres`: `toy.rest`, restores energy at home over 60 ticks.
- `actions/explore.tres`: `toy.explore`, drains curiosity outdoors over 30 ticks and records a discovery.
- `actions/chat.tres`: `toy.chat`, talks outdoors in daytime over 10 ticks, emits `toy.chatted` and shares beliefs with the NPCs present.
- `actions/work.tres`: `toy.work`, works at the workshop over 60 ticks.
- `goals/rest.tres`: `toy.rest` goal, scored from low energy.
- `goals/explore.tres`: `toy.explore` goal, scored from curiosity and energy.
- `goals/chat.tres`: `toy.chat` goal, scored by the `sociable.gd` hook.
- `goals/work.tres`: `toy.work` goal, weight 3, scored only during the work schedule.
- `schedules/work_day.tres`: `toy.work_day`, work at the workshop from 09:00 to 17:00 every day.
- `archetypes/villager.tres`: `toy.villager`, the base layer for the basic cast (decides every 5 ticks).
- `archetypes/drifter.tres`: `toy.drifter`, a schedule-free archetype (decides every 7 ticks).
- `personalities/lazy.tres`: `toy.lazy`, multiplies the rest goal by 1.5.
- `personalities/diligent.tres`: `toy.diligent`, multiplies rest by 0.8 and work by 1.2.
- `characters/ana.tres`: `toy.ana`, a villager with the lazy and diligent personalities.
- `characters/bo.tres`: `toy.bo`, a villager with the diligent personality.
- `characters/cy.tres`: `toy.cy`, a villager with the lazy personality.
- `scenarios/basic.tres`: `toy.basic`, the starting scenario at 08:00 with the three villagers and the player in the yard.
- `invariants/discoveries.tres`: `toy.inv.discoveries`, checks that the discovery count is not negative.
- `hooks/sociable.gd`: consideration hook that scores chatting by curiosity, scaled by a parameter.
- `hooks/is_daytime.gd`: condition hook that holds between 06:00 and 22:00.
- `hooks/explore_find.gd`: effect hook that adds one discovery.
- `hooks/discoveries_non_negative.gd`: invariant hook behind `toy.inv.discoveries`.
- `actions/wave.tres`: `toy.wave`, a dialogue-tier action (a one-tick wave); no goal chooses it, only a dialogue reply may.
- `dialogue/dialogue.tres`: the toy dialogue: four intents (`toy.greet`, `toy.ask_news`, `toy.insult`, `toy.smalltalk`), their line sets, two presentation questions and `trust` as the band dimension.
- `dialogue/hooks/news.gd`: intent hook for `toy.ask_news`; reveals the first sighting the NPC believes in, by location ID.
