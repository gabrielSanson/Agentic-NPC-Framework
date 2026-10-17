# Voice: microphone in, NPC voices out

Two nodes in `addons/npcf/voice/` add push-to-talk and spoken NPC lines. Both are optional. The simulation never
depends on them.

## The nodes

- **`NpcfMicCapture`** goes once in the level. Hold the push-to-talk key (default V, action `npcf_push_to_talk`)
  to record. On release the audio goes to `Npcf.transcribe` and the text goes to `Npcf.player_say`.
  `transcript_ready` fires before the NPC answers.
- **`NpcfVoicePlayer2D`** goes as a child of each NPC body, next to its `NpcfAgent2D`. It speaks that NPC's lines
  from where the NPC stands. Set `npc_id` or leave it empty to take the sibling agent's ID.

## Project setup

- Set `audio/driver/enable_input = true` in the project settings. Without it the microphone records silence and
  the node warns once.
- Desktop systems may ask for microphone permission.
- Export to macOS needs the microphone entitlement. Android needs `RECORD_AUDIO`.

## Pack fields

Speech has its own fields. They are separate from the prompt `voice` text, which stays how the NPC talks.

| Where | Field | Meaning |
| --- | --- | --- |
| personality | `speech_instruction` | How the trait sounds, for example "Slow, low, drowsy voice." |
| character | `speech_instruction` | Appended to the personalities' text, for example a fixed accent. |
| character | `speech_voice_id` | A fixed Breeze voice. Empty means the server designs a voice from the text. |
| dialogue | `default_speech_instruction` | Used when the NPC's layers give no speech text. |
| dialogue | `default_speech_voice_id` | Used when the character sets no voice. Empty means none. |
| dialogue | `delivery_question` | The presentation question whose answer shapes the delivery, for example `toy.emotion`. |
| dialogue | `delivery_instructions` | Answer to delivery text, for example `toy.annoyed` gives "Clipped and irritated.". |

The speech instruction is the NPC's layer texts (or the dialogue default), then the delivery text for the answer
to `delivery_question`, joined with one space. Example: a personality text "Slow, low, drowsy voice." with the
answer `toy.annoyed` gives "Slow, low, drowsy voice. Clipped and irritated.".

## Behaviour

- **Subtitles come first.** Every line emits `subtitle` before any speech request. With no voice provider the
  game gets subtitles only, and `speech_finished` reports `&"off"`.
- **Out of earshot.** Audio is dropped when the player is farther than `earshot_px` from the NPC (0 or less means
  always audible). The subtitle still shows, and `speech_finished` reports `&"out_of_earshot"`.
- **Interruption.** A new line from the same NPC interrupts the one playing (`&"interrupted"`). Lines are not
  queued.
- **Push-to-talk limits.** Recordings shorter than `min_seconds` are dropped (`too_short`). Recordings stop at
  `max_seconds`.

## Non-commercial note

The demo's speech uses Breeze, which is gated as non-commercial. See `docs/providers.md`.
