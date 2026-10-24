# Plan v2: Story, cutscenes, bigger maps, hide spots, horror sound, extras

v1 (done, archived in `tasks/archive/`): 4 stages, 4 coworkers, Social Battery, endings A/B/C, Windows export, 51 passing tests.

## Decisions (confirmed with user)
- Cutscenes: **in-engine 3D** (camera moves through the PSX world, characters act, Thai subtitles, skippable)
- Maps: **~2x, multi-room**, still 4 separate stages
- Sound: **freesound.org CC0 via Chrome** (+ synth fallback)
- Extras: **Tong's phone** (chat story + flashlight), **stamina + throw distraction**, **dream clues → Ending B**
- My additions (please review): **guard cameos** in stages 1–3, **creepy photo message** from the unknown number, **readable notes**, **hold-breath** while hiding, **save/continue**

## Assumptions to review
1. **New Ending B rules:** found all 4 dream clues + did NOT take the guard's phone. "Never caught" is dropped because it's too harsh on 2x maps. A = phone + noticed ≥2 hints. C = everything else.
2. **"Noticed hints" now counts:** answering a ringing desk phone, AND looking at a guard cameo before it vanishes. Up to 7 in total; A needs 2+.
3. **Hiding:** coworkers can't see you in a hide spot, unless one saw you get in. Then it walks over and searches it (you're caught). Hold **Space** to hold your breath when one is within 3m. It uses stamina, and running out = gasp = found.
4. **Hide spots:** เต้ checks *under-desk* spots (his gimmick from the doc: "มุดใต้โต๊ะแข่งกับเต้"), so in stage 3 only lockers are safe.
5. **freesound:** CC0-filtered search in Chrome, download the public HQ preview (`.ogg`). No account needed for previews. If a login wall appears, I'll ask you.

## Architecture changes (keep the "data in game.gd/story.gd, builder in level.gd" pattern)
- `scripts/story.gd` (new): all narrative data: cutscene step lists, phone chats, notes, triggers, clues, ending scenes. Pure data, no logic.
- `scripts/cutscene.gd` (new): step runner (`cam`, `look`, `say`, `sfx`, `wait`, `act`, `flash`) on its own Camera3D; letterbox bars; skip with E/Space.
- `level.gd`: new map letters (see below), **wall-run merging** (one collider/mesh per row of `#` instead of per cell, required for 2x maps), room signs, story trigger areas.
- `player.gd`: stamina, hide state, throw, flashlight (SpotLight3D).
- `npc.gd`: `hear(pos)` → `investigate` state; `search(spot)`; hidden-player rule.
- `main.gd`: phone overlay UI, note reader, stamina bar, letterbox, clock card, settings/continue.
- Audio: bus layout `Master > SFX (reverb) / Amb / Tension`; low-pass on SFX while hiding; tension layer (heartbeat + chase loop) driven by the nearest coworker's distance and state.

### New map letters
`H` locker (hide) · `D` desk: crouch + E = crawl under (hide) · `W` toilet stall (hide) · `s` throwable (stapler/mug) · `e` readable note/email · `Z` dream clue · `g` guard cameo spot · `!` story trigger (monologue/chat) · `z` power bank (phone battery) · `r` room sign (text from the stage's `signs` list)

## Dependency graph
```
T1 wall-merge + map letters ─┬─────────────────────────────────┐
T2 cutscene runner + story.gd ┤                                 │
T3 stamina + hide spots ──────┤ (hold-breath needs stamina)     │
T4 noise + throw + investigate┤                                 ├─ T7 STAGE 1 big map (vertical slice) ◄ checkpoint
T5 phone: chat + flashlight ──┤                                 │
T6 horror sound pass ─────────┘ (freesound via Chrome, buses)   │
T7 ── T8 stage 2 ── T9 stage 3 ── T10 stage 4                   │
T5+T2 ── T11 guard cameos + creepy photo message                │
T2+T7..T10 ── T12 intro + clock cards + 3D ending cutscenes + new B rule
all ── T13 tension mix, settings, save/continue, balance ── T14 export + report
```

## Phases and checkpoints
- **Phase 1: Systems (T1–T6)**, each proven in a small test map. *Checkpoint 1:* tests green; hide/throw/phone/cutscene visible in screenshots.
- **Phase 2: Stage 1 slice (T7)**: the big accounting floor with everything (rooms, hides, notes, clue, stage-intro cutscene, new sounds). *Checkpoint 2:* **you play stage 1** and confirm feel before I redo stages 2–4.
- **Phase 3: Stages 2–4 + cameos (T8–T11)**. *Checkpoint 3:* full run 1→4.
- **Phase 4: Story wrap + polish (T12–T14)**. *Checkpoint 4:* all endings reachable through cutscenes, export runs.

## Risks
- **2x maps:** performance with per-cell nodes. T1 merges walls first; keep lights ≤ ~14 per stage with shadows off.
- **freesound:** if Chrome/site access fails, fall back to synth (drone, heartbeat, breathing are easy) and tell you.
- **Cutscenes vs. timing tests:** cutscenes get a `skip_all` flag so automated tests aren't slowed.
- **Scope:** 14 tasks is about 2x v1. Checkpoint 2 is the go/no-go on feel before content scales up.
