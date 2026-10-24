# Plan: Salary man: Nightmare (Godot 4.7, 3D first-person)

Sources: `รายงานออกแบบเกม 3D.md`, `Salaryman_Nightmare_Pitch.pdf`. Engine: `Godot_v4.7-stable_win64.exe` (in project root).

## Decisions (confirmed with user)
- Scope: all 4 stages + endings A/B/C + Game Over
- First-person camera, WASD + mouse look, crouch (hide behind desks)
- Assets: CC0 free (Kenney / Quaternius / Poly Haven / freesound CC0) fetched via Chrome, else primitive placeholders. Record every source in `ASSETS.md` (report has an "ASSET ที่ใช้" section to fill).
- Style: low-poly PSX (low-res SubViewport 320x240; characters = blocky boxes + face crops from the pitch PDF, nearest filter, vertex-snap/affine shader, jittery 12fps NPC animation)
- Language: Thai UI/dialogue

## Assumptions to review
1. **Ending rules (as built; stage goals are mandatory, so "collect all docs" could not be a rule):**
   - B (dream): never caught + answered all 4 guard phone calls + did NOT take the guard's phone
   - A (good): took the guard's phone + answered >= 2 calls (noticed he's creepy, reports him)
   - C (bad): everything else (the guard follows you home). Game Over (battery 0) overrides all.
2. Each stage has one ringing phone = one creepy call from the guard (hint). Retries can't double-count a call.
3. The report calls the player "นนท์" once; character is "ต๋อง". Using ต๋อง.
4. Stage 4 rule "must keep guard in sight": guard freezes only while in camera view (weeping-angel style); looking away lets him advance. Battery drains if he reaches you.
5. Social Battery: 100 max, drains on catch/chat, refills at coffee machine, 0 → Game Over.

## Architecture (minimal, fewest files)
- `project.godot`, autoload `Game.gd` (battery, docs, flags, stage switching, ending resolver)
- `Player.tscn/gd` (CharacterBody3D, look, walk, crouch, interact ray)
- `Npc.gd` base (states + FSM inline) → `Manager.gd`, `Sweeper.gd`, `Goblin.gd`, `Guard.gd` extend it
- `Stage1..4.tscn` built with CSG/GridMap + CC0 props; `HUD.tscn`; `Menu.tscn`; `Ending.tscn` (one scene, text/pic by ending id)
- `Audio` via AudioStreamPlayer3D on NPCs (footsteps are the gameplay cue)

## Dependency graph
```
T1 project+PSX look ─┬─ T2 Player ─┬─ T3 Game state/HUD ── T4 Menu/GameOver
                     │             └─ T5 Interact/pickup
T1 ── T6 Asset fetch (parallel, feeds all stage art)
T2+T3+T5 ── T7 Stage1 + Manager (hear→crouch→hide)   ◄ first playable
T7 ── T8 Stage2 + Sweeper (wet-floor zones, chase)
T7 ── T9 Stage3 + Goblin (under-desk pop-out, password hunt)
T7 ── T10 Stage4 + Guard (look-to-freeze)
T7..T10 ── T11 Endings + resolver
T11 ── T12 Polish (audio/Foley, jitter anim, text, balance) ── T13 Export
```

## Phases and checkpoints
**Phase 1 – Foundation (T1–T6)** → *Checkpoint 1:* empty room, PSX look, walk/crouch/look works, HUD shows battery, menu → play → game over loop.
**Phase 2 – Stage 1 vertical slice (T7)** → *Checkpoint 2 (review):* fully playable stage 1 end-to-end: collect 3 docs, hear Manager shoes, hide, win/lose. Human plays and signs off feel before building more.
**Phase 3 – Stages 2–4 (T8–T10)** → *Checkpoint 3:* each stage playable start→finish in sequence, each with its unique enemy mechanic.
**Phase 4 – Endings and polish (T11–T13)** → *Checkpoint 4:* all 3 endings + game over reachable; Windows export runs.

## Risks
- Free rigged/animated human models are scarce → NPCs as low-poly humanoid built from primitives/Quaternius, "jitter" animation via stepped transforms (fits the uncanny style, cheap).
- Thai font rendering: bundle a free Thai font (Noto Sans Thai / Sarabun, OFL).
- Godot 4.7 is newer than my reference knowledge → verify APIs against the running editor (`--headless --check-only` and run scenes) rather than assuming.
- Scope: 4 stages is large; Checkpoint 2 is the go/no-go for pacing.
