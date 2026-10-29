# Salary man: Nightmare

Horror Comedy · Workplace Survival · 3D. Godot 4.7, first-person. CP410844 group 2.

**Branch `claude/hd-3d-remaster`: the HD 3D remaster.** The game was always 3D, but it rendered at 320x240 with wobbly PSX polygons and a VHS filter. Here it renders at full resolution with real lighting: filmic tonemapping, glow on the ceiling panels, the nearest ceiling lights casting shadows, ambient occlusion and volumetric fog that the flashlight cuts a beam through (the last ones on desktop / Forward+; the web build keeps the cheaper ones), HD textures on every surface (carpet tiles, painted walls with a skirting board, acoustic ceiling tiles, hospital vinyl, stairwell concrete, wood and plastic on the furniture), characters with rounded edges and smooth shading, sharp portraits, and a film-grain post-process that frays as Social Battery falls. **Realistic people and offices:** in the HD look every character is a life-like skinned human built from the CC0 MakeHuman base mesh (`tools/blender/build_humans.py`: age, build, clothes, hair, props per character, day and night versions), and the Kenney furniture is swapped at load time for modelled office furniture (`tools/blender/build_props.py`: desks with drawer pedestals, task chairs, monitors, keyboards and mice, credenzas, coffee makers, a steel cupboard, a hospital bed...) fitted to the same boxes, with recessed fluorescent fittings, air vents, smoke detectors, sprinklers, sockets, notice boards, extinguishers and exit signs dressed onto the walls and ceilings. **Sound:** a synthesized night-office bed (air conditioning, building rumble, mains hum), a slow dread drone, a chase cue built on a heartbeat and an endlessly rising Shepard tone, every tube buzzing faintly over your head and clunking off when the power dies, footsteps that change with the floor and a reverb that fits the room (`tools/synth_horror.py`). **The ghosts (plan v9):** the people have knees, elbows and a back (a 12-bone rig) and each ghost moves wrong in its own way (the manager stiff with his head following you, Pa Porn dragging a leg, Tae on all fours, HR in quick heel steps, the doctor bent and slow, the guard in stop-motion); one patrolling with its back to you stops dead when you watch it and turns its head round further than a neck goes. At night their faces are torn into wide grins or hanging jaws with sunken eyes; the death slam is a white flash into black, the face lit from below in stutters and torn by a glitch shader. You hear them before you see them (a pen clicking, heels, a keyring, a wet mop, knuckles on the floor), sounds behind walls come through muffled, and the music moves between calm, unease (near but unseen), the chase and the breather after, with a sting the first time you see one in a chapter. The office changes when you are not looking (a chair rolled into the aisle, a screen turned to face you, the lights behind you dying, papers on the floor, a phone ringing out of sight), and at low Social Battery you hear its steps come up behind you to nobody, or a text on the phone says something else for a moment. **Plan v10 (from a review):** the night catch lines are cold, not jokes; the full face-slam comes once a chapter (and for the catch that ends it), other catches are quick and dark, and from the second catch each costs something for the chapter (the hide spot wrecked, the torch knocked down 30 %, the ghost faster); chapters open with the ghost heard but kept away, then shown to you once on purpose; half-way through, the floor's power dies once; hide in the same spot a third time and it comes to check; four landmarks per chapter on the walls (the founder's portrait, a poster, a fire hose cabinet, a TV left on, a clock stopped at 02:14); chapter 3's lift pass is locked in a drawer whose code is the time Tong collapsed; past chapter 1 the how-to tips stay quiet unless you seem stuck; and every ghost whispers Tong's name (Thai speech via espeak-ng, processed). Settings: **คุณภาพกราฟิก** low / medium / high, **ความละเอียด 3D** (FSR upscaling below 100 %), and **ภาพย้อนยุค (PSX 320x240)** brings the original look back.

## Run
- Play: `build/SalarymanNightmare.exe` (after export), or open the folder in `Godot_v4.7-stable_win64.exe` and press F5.
- Tests: `Godot_v4.7-stable_win64.exe --path . res://tests/tests.tscn` → prints PASS/FAIL, exit code 0 = OK, screenshots to `%APPDATA%/Godot/app_userdata/Salary man- Nightmare/`. Uses its own save/settings files.
- Export: `Godot_v4.7-stable_win64.exe --headless --path . --export-release "Windows Desktop" build/SalarymanNightmare.exe`

## Play in the browser (GitHub Pages)
The web build is in `docs/` (`index.html` + `index.wasm`/`index.pck`/`index.js`).
1. Push this repo to GitHub.
2. Repo **Settings → Pages → Build and deployment: Deploy from a branch → `main` / `/docs` → Save**.
3. After about a minute it's live at `https://<your-user>.github.io/<repo-name>/`.

Re-export after changes: `Godot_v4.7-stable_win64.exe --headless --path . --export-release "Web" docs/index.html`
(needs the Web export templates, same as the editor's Project → Export → Web).
It's the no-threads build, so it runs on GitHub Pages without special server headers. The first stage takes about 10 s to load in the browser (shader compile).
Web uses the Compatibility renderer; the game was tested under it (full test suite + in Chrome).

## Controls
WASD move · Shift sprint (uses stamina) · C / Ctrl crouch (toggle, silent) · E interact / hide / come out · Space (hold, while hidden) hold breath · Q or right-click throw · Tab phone · F flashlight (phone battery) · O objective note open/folded · Esc pause · F3 FPS counter · hold Space 3 s to skip a cutscene

## How it plays
- **Stage 0 (intro / tutorial):** New Game opens on a bright Friday afternoon with everyone at work. An unknown number texts you, and nothing works until you open the phone (Tab) and read it: the texts are the controls. Walk round and talk to the four coworkers (E); then the daylight goes, they leave one by one, and the stranger texts the night-shift rumour. It ends at the washroom mirror. Skip it from the pause menu (Esc).
- **Social Battery:** getting caught drains it and sends you back to the stage start (or the last checkpoint). At 0 it's Game Over. Coffee gives +40. As it drops, the screen breaks down (VHS tearing, colour bleed, vignette), and below 50 Tong starts seeing coworkers who aren't there.
- **The night's rhythm (fear director, `scripts/director.gd`):** nobody is on you all the time. It stays quiet for a while; then a coworker comes to look round somewhere near you that you can't see; if it sees you, a chase; break line of sight for ~3 s (2 s on Easy, 4.5 s on Hard) and it searches where it last saw you, then **withdraws to the far side of the floor** for half a minute (it does the same after catching you, and if it has been close to you for too long). There is no "!" over their heads except on Easy: you hear them instead.
- **Psychological horror:** between the chases, things that can't hurt you: footsteps a few steps behind that stop when you stop (and when you turn round, nothing), your name whispered behind you, the lights dying one by one toward you, someone at the edge of your eye who isn't there when you look, words on a dead screen ahead, total silence and then a breath at your neck, the clock jumping to 02:14, a text from your own number, a call from Mum that is only breathing. The stranger texts what you are doing right now (hiding, standing still, flashlight on, running, crouching, turning round, reading a note). More often as Social Battery falls; stranger ones later in the night.
- **Stealth:** coworkers see you in a vision cone. Partitions, desks and walls block their sight when you crouch. Running is loud, walking is a little loud, and crouching is silent. **In the dark they only see you at about half range, but a lit flashlight is a beacon: they spot it from farther than in normal light.**
- **Hiding:** use lockers (H), toilet stalls (W) and the space under desks. If a coworker saw you get in, they come and open it. If one stands right next to your hiding spot, hold your breath (Space) until your stamina runs out.
- **Distractions:** pick up a mug or stapler and throw it. Coworkers go to check the noise.
- **Notes (E to read):** every note has a real use. It can mark the stage's goals (yellow arrows, visible through walls), show hide spots (green boxes), or show where the coworker is (red dot). Notes about พี่สมชาย count as **evidence** for Ending A.
- **Scripted scares:** lights dying, someone standing at the end of a corridor, someone right behind you, knocking from inside a toilet stall, someone sprinting at your face (`rush`), a face slammed full screen (`face`), a head round a corner (`peek`), something scuttling past on all fours (`crawl`). Placed per stage as `Scares` nodes, plus `goal_scares` (the n-th goal) in `story.gd`.
- **Story cutscenes mid-stage:** brewing ป้าพร's coffee, flipping the breaker, putting the fuse in: each plays a short scene (the coworker turns on you, Tong runs) and play picks up where he ran to.
- **Night faces:** after dark every coworker has a night model (glowing eyes, the grin torn to the ears, hair over the face...). By day, in the intro, they look like themselves.
- **Phone:** chats from แม่, หัวหน้าธนา, the IT group and an unknown number tell the story. The flashlight drains phone battery, and power banks refill it.
- **Jobs ("งาน"):** people text Tong jobs during a chapter (13 in all). Each is 2 steps: go somewhere and use the purple-glowing thing (on a little side table), with a note, a line, a scare or a short scene on every step and a payoff when it's done (Social Battery, phone battery, evidence against พี่สมชาย, or the goals marked on screen). Side jobs are optional; a **required job** (★, chapters 1 and 3) keeps the exit shut until it's done and becomes the objective. Three threads: **ฝน** (6 jobs from the unknown number: the night-shift accountant before Tong, who "resigned"; finishing her story adds an epilogue to every ending), **แม่** (3) and **เต้ / IT** (2). Phone app 5 lists the jobs under way and the case file of finished ones. Side jobs count on the performance review.

## Stages (each ~30x22 cells = 60x44 m, multi-room)
| # | Place | Coworker | Goal | Core mechanic |
|---|---|---|---|---|
| 0 | บทนำ: เย็นวันศุกร์ (the office by day) | all four, friendly | read the texts, talk to everyone, go to the mirror | Day turns to night; nobody hunts you yet |
| 1 | แผนกบัญชี | หัวหน้าธนา | 3 เอกสารงบดุล | Classic stealth: squeaky shoes = he's close, he stretches his neck over partitions |
| 2 | โถงทางเดิน & โซนพัก | ป้าพร | กาแฟ 1 แก้ว | Don't step on the wet trail. **The coffee was hers:** her head turns all the way round, then she chases you to the elevator (cutscene, checkpoint) |
| 3 | ฝ่ายบุคคล & ห้องประชุม (new) | พี่แหม่ม HR | แฟ้มประวัติ · รายงานประชุม · บัตรลิฟต์ | **PA roll call:** the chime, then she calls Tong's name. Not hidden when it ends = she knows where you are. Your HR file says you've been on sick leave for 3 days |
| 4 | ห้องเซิร์ฟเวอร์ | เต้ | breaker + 3 post-its + PC | **Whole floor blacked out**, only red emergency lights. Flip the breaker (loud, and he's in the doorway), collect 3 post-its whose digits make the code, type it on the PC keypad |
| 5 | บันไดหนีไฟ (new) | nobody... | 8 laps | **The corridor loops.** Something wrong this time round (18 kinds: a faceless man at the end, red lights, a poster that changed, the clock at 04:44, a door left open...) = turn back; nothing wrong = go on. 8 right in a row. Some of them come at you |
| 6 | ตึกผู้ป่วย 7 (new, the dream) | หมอ | 3 แฟ้มผู้ป่วย → bed 4 | **The doctor hears your heart.** Running and fear make it pound (♥ BPM on the HUD); creep, hide and hold your breath to calm it |
| 7 | ออกจากบริษัท | พี่สมชาย | fuse → panel → scanner | He only moves when you're not looking, and **the lights die at random**. **Finale:** holding the scanner brings everyone down the elevator after you |

Rough first-play time: about 2–3 h (the stairs alone take 20–40 min); playing on for all four endings: around 5 h.

## Endings (how to reach each)
- **Evidence = noticing พี่สมชาย:** answer a ringing desk phone (one per stage), spot him standing far away in stages 1–3 and keep looking until he vanishes, or read notes about him (building notice, IT ticket, repair log, Admin log, guard log, CCTV log).
- **Dream clues:** one per stage. Listen for a heart-monitor beep: a hospital wristband, an IV bag, a monitor hidden in a server rack, a get-well card.
- **D, True End:** every dream clue (one per stage, 7) + พี่สมชาย's phone + **at least 6 evidence**. Tong really wakes up, the police already have him, and Tong quits.
- **B, Dream End:** every dream clue + do NOT take the guard's phone. You wake up in hospital... and the boss is there.
- **A, Good End:** take พี่สมชาย's phone from his booth in the last stage + **at least 6 evidence**. You report him to the police.
- **C, Bad End:** anything else, and he follows you home (door viewer, then he's behind you).
- **Game Over:** Social Battery reaches 0.

## Menus & UI
- **Look:** someone is watching. Chapter cards are a CCTV feed (REC, CAM, timestamp, typewriter), results are company paperwork: a performance review with a grade stamp (S–D) when a chapter is cleared, an HR warning letter on Game Over, a certificate at an ending. Fonts: Kanit (titles/UI), Sriracha (handwriting), Sarabun (body).
- **Main menu:** the office lives behind it (a 3D camera pans, lights flicker, a coworker appears and vanishes), glitching title, Tong's staff ID with your progress, menu music. Continue names the saved chapter.
- **Profile** (`user://profile.cfg`, kept across runs): chapter select (chapters you reached), document archive (every note you read), endings gallery, best grade per chapter.
- **HUD:** battery widget with Tong's face, stamina, phone battery while the flashlight is on, objective sticky note (folds to a tab; opens by itself for a few seconds when it changes; O or the setting keeps it open), coloured speaker names in subtitles, key-cap prompts, first-time tips, low-battery vignette, chase music while hunted.
- **Phone (Tab):** home screen with apps: 1 chat (avatars, times), 2 GPS, 3 documents, 4 map (rooms you walked through), 5 jobs (under way + case file).
- **Pause = coffee break:** objective, collectibles, controls; resume, settings, restart chapter, main menu.
- **Settings:** difficulty (easy/normal/hard: battery drain and coworker speed), mouse sensitivity, volume (all/music), brightness, FOV, VHS strength, subtitle size, invert Y, fullscreen, skip cutscenes.

## Editing (no code needed) → **[EDITING.md](EDITING.md)** (Thai, step by step)
| Scene / file | What's in it |
|---|---|
| `scenes/main.tscn` | Menu/HUD/flow (built by `scripts/main.gd`), loads the stages below |
| `scenes/player.tscn` | ต๋อง: CharacterBody3D + Camera3D + InteractRay + Flashlight |
| `scenes/mobs/*.tscn` | One scene per coworker (+ practice mannequin). Speed, rage speed, vision, battery drain and lines are in the Inspector |
| `scenes/stages/tutorial.tscn`, `stage_1/2/hr/3/stairs/hospital/4.tscn` | The maps (order = `STAGES` in story.gd, each names its `scene`). Select the root for the stage mechanics (dark start, rage, flicker, finale) |
| `scenes/endings/ending_A/B/C/D.tscn` | The 3D ending rooms |
| `assets/characters/*.blend` → `.glb` | Character models (Blender). Export over the `.glb` and Godot reimports it |

Inside a stage scene:
- **NavRegion:** everything solid. **After moving anything solid:** select NavRegion → **Bake NavigationMesh**, then save.
- **Items:** goals, notes (Title/Text/Reveal/Evidence in the Inspector), coffee, phones, hide spots, breaker, scanner.
- **Triggers** (story moments), **Scares** (kind, who, sound, how long, chance; drag the child `At` to set where it happens), **Coworkers** (tutorial: the friendly daytime four, with their lines), **Tutorial** (the stranger's texts, day/night timing, the mirror).
- **Lights / Emergency / Signs / Cameos / Markers** (PlayerSpawn, Route/1..n patrol).

Cutscenes, timed phone texts, objectives and endings live in `scripts/story.gd`. Its ASCII maps only **generate** the scenes (`tools/bake_stages.tscn`); `-- --force` overwrites editor changes.

## Code map
- `scripts/story.gd`: data the scenes were generated from (ASCII maps, notes, triggers, scares, the tutorial's coworkers and texts) + what still lives in code: intro cutscenes, timed phone texts, objectives, ending scenes, character presets (`BODIES`)
- `scripts/game.gd`: autoload with run state, rules, ending resolver, audio buses, save/settings
- `scripts/stage.gd`: runtime of a stage scene (spawn, exit, wet floor, cameos, photo, distant sounds, blackouts/power, note reveals, scares, hallucinations, rage chase, finale scanner)
- `scripts/story_trigger.gd`, `scripts/scare.gd`: the editor-placed story / scare nodes
- `scripts/tutorial.gd` (stage 0's sequence: texts that lock you, day to night, mirror ending) + `scripts/coworker.gd` (friendly daytime coworker)
- `scripts/npc.gd` + `scripts/mobs/*.gd`: base coworker AI (patrol, investigate noise, search hide spot, chase, catch; NavigationAgent3D) + the coworkers (manager, sweeper, goblin, guard, hr, doctor) + a practice mannequin (`dummy.gd`)
- `scripts/loop.gd`: the fire-stairs loop (laps, anomalies)
- `scripts/hd.gd`: the HD look (surface textures, furniture surfaces, environment, lights, torch, quality levels) · `shaders/psx.gdshader` has both looks (global `retro_look`) · `shaders/film.gdshader`: HD post-process · `tools/make_hd_textures.py`: generates `assets/textures/hd/` (numpy) · `tools/blender/build_humans.py` / `build_props.py`: the realistic people / furniture (Blender or `pip install bpy`) · `tools/synth_horror.py`: the sound bed, music and floor footsteps
- `scripts/director.gd`: the fear director (stalk / relief rhythm, psychological events, the stranger's reactive texts): every time and line is at the top of the file
- `scripts/ui/kit.gd` (colours, fonts, button/panel styles, UI sounds: change the look here), `scripts/ui/menu_bg.gd` (live office behind the menu), `scripts/ui/phone_map.gd` (map app), `scripts/ui/app_icon.gd`, `shaders/crt.gdshader` (screen overlay)
- `scripts/player.gd`, `scripts/pickup.gd`, `scripts/body.gd` (@tool, loads the Blender model parts), `scripts/cutscene.gd`, `scripts/main.gd`
- `scripts/stage_builder.gd` + `tools/bake_stages.tscn`: one-time generator of the stage scenes
- `tools/blender/build_characters.py`: generates every character .blend/.glb in Blender (or with the `bpy` pip module: `python tools/blender/build_characters.py -- guard_night`) · `shaders/vhs.gdshader`: fear post-process
- Assets and licenses: `ASSETS.md` · sounds: `tools/fetch_freesound.py` (CC0), `tools/synth_sfx.py`, `tools/synth_ui.py` (UI sounds, menu and chase music)
