# Todo v2: Salary man: Nightmare

Verify: `Godot_v4.7-stable_win64.exe --path . res://tests/tests.tscn` (exit 0) + screenshots in `%APPDATA%/Godot/app_userdata/Salary man- Nightmare/`.

## Phase 1: Systems
- [x] **T1 Map builder v2**: merge `#` runs into one box per run; new letters `H W s e Z g ! z r`; room signs (Label3D). *AC:* stage-1 v1 map builds with ≥60% fewer wall nodes; all v1 tests still pass.
- [x] **T2 Cutscene runner + story.gd**: steps `cam/look/say/sfx/wait/act/flash`, letterbox, skip (E/Space), `Game.skip_cutscenes` for tests. *AC:* test cutscene runs start→end and emits `finished`; skip ends it immediately; player input frozen during it.
- [x] **T3 Stamina + hide spots**: sprint drains stamina (HUD bar); E at locker/stall/desk (crouched) = hide, peek-slit view + muffled audio; hold Space = hold breath (stamina). NPC seen-you-enter → search → caught. *AC tests:* hidden player not seen at 2m; NPC that saw entry searches and catches; breath runs out → found.
- [x] **T4 Noise + throw + investigate**: pick up `s`, Q/right-click throws (RigidBody3D); impact noise radius 10m; sprint steps radius 5m; NPC `investigate` state (walk to noise, look around 3s, return). *AC tests:* throw lands → patrolling NPC walks to it; crouch-walking makes no noise.
- [x] **T5 Phone (Tab)**: overlay with chat threads (แม่, หัวหน้าธนา, กลุ่ม IT, เบอร์ไม่รู้จัก), messages pushed by story triggers with a vibrate sound + HUD toast; F = flashlight (SpotLight3D), drains phone battery, `z` power bank refills. *AC tests:* trigger adds message to the right thread; flashlight drains and turns off at 0.
- [x] **T6 Horror sound pass**: freesound CC0 (via Chrome, HQ previews): HVAC room tone, fluorescent buzz, heartbeat, breathing, distant elevator ding, door slam, knock, chair creak, printer, whisper, mop squelch, phone vibrate. Audio buses + reverb, hide low-pass, random distant-event scheduler, heartbeat by nearest NPC distance, chase loop. Update `ASSETS.md` with each sound's URL + author + CC0. *AC:* every new sfx listed with license; test asserts bus layout + heartbeat volume rises as NPC approaches.
- [~] **CHECKPOINT 1** (skipped at user request: review at final): tests green, screenshots of hide view / phone / cutscene letterbox

## Phase 2: Stage 1 vertical slice
- [x] **T7 Stage 1 "แผนกบัญชี" v2** (~30x22 cells): open-plan cubicles + meeting room + pantry (coffee) + manager's glass office + filing room; 3 docs spread across rooms, 2 lockers + desks to hide, 2 throwables, 3 notes (building memo, manager's calendar "ประชุมกับต๋อง 3 ชม.", IT ticket about CCTV), dream clue #1 (hospital wristband in lost & found), power bank, 1 ringing phone, stage-intro cutscene (manager reveal: neck stretches over a partition, squeak). *AC:* stage builds, all goals reachable (A* path from spawn to every goal + exit), intro cutscene plays then control returns.
- [~] **CHECKPOINT 2** (skipped at user request: review at final): **user plays stage 1**, tune before scaling content

## Phase 3: Stages 2–4 + cameos
- [x] **T8 Stage 2 "โถงทางเดิน & โซนพัก" v2**: long L-shaped hallway, lounge, toilets (stalls = hides), elevator lobby, storage; ป้าพร's wet trail; clue #2 (IV drip bag in storage); intro cutscene (ป้าพร sprinkling holy water, off-key hum). *AC:* as T7.
- [x] **T9 Stage 3 "ห้องเซิร์ฟเวอร์" v2**: server aisles, IT storage, cable crawlspace, PC room; 3 password notes + PC; เต้ checks under-desk hides; clue #3 (heart-monitor beeping from a rack); intro cutscene (เต้ popping up from under a desk). *AC:* as T7 + test: เต้ searches an occupied desk hide.
- [x] **T10 Stage 4 "ออกจากบริษัท" v2**: lobby, guard booth, CCTV room (monitors show Tong's desk), mailroom, fingerprint scanner at exit; clue #4 (get-well card at reception); intro cutscene (guard standing still, head turns only when the camera cuts). *AC:* as T7.
- [x] **T11 Guard cameos + creepy photo**: `g` spots in stages 1–3: guard stands at the end of a corridor, vanishes when looked at for 1s or when the camera looks away (looked-at = hint noticed). Mid-stage 3, the unknown number sends a photo rendered from a camera behind the player at that moment. *AC tests:* looking at a cameo increments hints and removes it; photo message contains a non-empty texture.
- [~] **CHECKPOINT 3** (skipped at user request: review at final): full run 1→4

## Phase 4: Story wrap + polish
- [x] **T12 Story + endings**: intro cutscene (Friday 23:47, Tong at desk, mom and boss chats, lights flicker, distant squeak); clock cards between stages (23:47 / 00:31 / 01:12 / 01:58); 3D ending scenes: A outside the building (police lights, guard's phone photos), B hospital room (doctor left, หัวหน้าธนา right with stretched neck), C apartment door (knock, peephole = guard's face); new B rule (4 clues + no phone). *AC tests:* resolver table updated; each ending cutscene builds and finishes; README recipes updated.
- [x] **T13 Polish**: settings (mouse sensitivity, volume, skip cutscenes), save/continue per stage (`user://save.cfg`), difficulty balance pass (speeds, drains, stamina), performance check (≥60 fps on the 4 stages, GTX 1650).
- [x] **T14 Export + report**: rebuild the exe, refresh screenshots, update `รายงานออกแบบเกม 3D.md` and `ASSETS.md`.
- [ ] **CHECKPOINT 4**: final review
