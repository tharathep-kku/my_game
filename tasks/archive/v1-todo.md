# Todo — Salary man: Nightmare

Verify each task by running the scene with `Godot_v4.7-stable_win64.exe --path . ` (and `--headless --quit` for script errors).

## Phase 1 — Foundation
- [x] **T1 Project + PSX look**: `project.godot`, low-res SubViewport, nearest filter, vertex-snap shader. *AC:* test room renders pixelated, no console errors.
- [x] **T2 Player**: first-person walk/look/crouch (collision height change). *AC:* can't walk through walls; crouched player fits under desk gap.
- [x] **T3 Game autoload + HUD**: battery 0–100, doc counter, `damage()/heal()`, signal `battery_empty`. *AC:* HUD updates; battery 0 emits signal.
- [x] **T4 Menu + Game Over**: Press Start → stage1; Game Over → retry. *AC:* full loop menu→play→die→retry works.
- [x] **T5 Interact**: raycast E to pick up docs / use coffee / take phone. *AC:* pickup increments counter and removes prop.
- [x] **T6 Asset fetch** (Chrome, parallel): office props, desk, printer, PC, coffee machine, humanoid, footstep/squeak/hum/phone SFX, Thai font; write `ASSETS.md` with source+license. *AC:* files under `assets/`, every one listed with CC0/OFL license.
- [~] **CHECKPOINT 1** (skipped, user reviews at final) — human review

## Phase 2 — Stage 1 slice
- [x] **T7 Stage 1 accounting + หัวหน้าธนา**: office layout with cubicle walls, 3 balance-sheet docs, Manager patrols in circles with squeaky-shoe sound (louder = closer), neck-stretch peek over partitions asking "งานคืบหน้ากี่เปอร์เซ็นต์แล้วจ๊ะ?". Caught (seen while not crouched in his view) → drain battery + lecture. *AC:* collect 3 docs → exit door unlocks → Stage 2 loads; being caught 3× drains to Game Over; hiding avoids drain.
- [~] **CHECKPOINT 2** (skipped, user reviews at final) — human playtest, adjust difficulty/feel before continuing

## Phase 3 — Stages 2–4
- [x] **T8 Stage 2 hallway + ป้าพร**: sliding mop-cleaner leaves wet-floor decals, holy-water spray, chases if player steps on wet decal; coffee machine at end heals battery. *AC:* stepping on wet → chase + drain; reaching coffee heals; stage advances.
- [x] **T9 Stage 3 server room + เต้**: desks with under-space, Goblin crawls/pops out from under desk, find password fragments (printer → PC) then open PC. *AC:* password collected and PC unlocked; Goblin ambush chat drains battery.
- [x] **T10 Stage 4 exit + พี่สมชาย**: lobby, guard frozen while in view, phone rings with creepy dialogue hints, guard booth has phone to steal (optional), exit door. *AC:* guard moves only when unseen; reaching exit ends stage.
- [~] **CHECKPOINT 3** (skipped, user reviews at final) — play stages 1→4 back-to-back

## Phase 4 — Endings + polish
- [x] **T11 Endings**: Game.gd tracks `docs_all, times_caught, phone_taken, hints_noticed`; resolver per plan precedence; one Ending scene (A good, B hospital doctor/left-right, C guard follows home). *AC:* each of A/B/C reachable by a documented playthrough recipe.
- [x] **T12 Polish**: Foley/hum/mutter audio, 12fps jitter NPC anim, Thai dialogue text, difficulty tune.
- [x] **T13 Export + docs**: Windows export, fill report sections (Template, ASSET list, scene screenshots). *AC:* exported .exe runs full game.
- [ ] **CHECKPOINT 4**: final review by user (checkpoints 1-3 skipped at user request: "review on final")
