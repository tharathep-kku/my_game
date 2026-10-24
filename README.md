# Salary man: Nightmare

Horror Comedy · Workplace Survival · Low-Poly PSX. Godot 4.7, first-person. CP410844 group 2.

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
WASD move · Shift sprint (uses stamina) · C / Ctrl crouch (toggle, silent) · E interact / hide / come out · Space (hold, while hidden) hold breath · Q or right-click throw · Tab phone · F flashlight (phone battery) · Esc pause · F3 FPS counter · hold Space 3 s to skip a cutscene

## How it plays
- **Stage 0 (intro / tutorial):** New Game opens on a bright Friday afternoon with everyone at work. An unknown number texts you, and nothing works until you open the phone (Tab) and read it: the texts are the controls. Walk round and talk to the four coworkers (E); then the daylight goes, they leave one by one, and the stranger texts the night-shift rumour. It ends at the washroom mirror. Skip it from the pause menu (Esc).
- **Social Battery:** getting caught drains it and sends you back to the stage start (or the last checkpoint). At 0 it's Game Over. Coffee gives +40. As it drops, the screen breaks down (VHS tearing, colour bleed, vignette), and below 50 Tong starts seeing coworkers who aren't there.
- **Stealth:** coworkers see you in a vision cone. Partitions, desks and walls block their sight when you crouch. Running is loud, walking is a little loud, and crouching is silent. **In the dark they only see you at about half range, but a lit flashlight is a beacon: they spot it from farther than in normal light.**
- **Hiding:** use lockers (H), toilet stalls (W) and the space under desks. If a coworker saw you get in, they come and open it. If one stands right next to your hiding spot, hold your breath (Space) until your stamina runs out.
- **Distractions:** pick up a mug or stapler and throw it. Coworkers go to check the noise.
- **Notes (E to read):** every note has a real use. It can mark the stage's goals (yellow arrows, visible through walls), show hide spots (green boxes), or show where the coworker is (red dot). Notes about พี่สมชาย count as **evidence** for Ending A.
- **Scripted scares:** lights dying, someone standing at the end of a corridor, someone right behind you, knocking from inside a toilet stall. Placed per stage as `Scares` nodes.
- **Phone:** chats from แม่, หัวหน้าธนา, the IT group and an unknown number tell the story. The flashlight drains phone battery, and power banks refill it.

## Stages (each ~30x22 cells = 60x44 m, multi-room)
| # | Place | Coworker | Goal | Core mechanic |
|---|---|---|---|---|
| 0 | บทนำ: เย็นวันศุกร์ (the office by day) | all four, friendly | read the texts, talk to everyone, go to the mirror | Day turns to night; nobody hunts you yet |
| 1 | แผนกบัญชี | หัวหน้าธนา | 3 เอกสารงบดุล | Classic stealth: squeaky shoes = he's close, he stretches his neck over partitions |
| 2 | โถงทางเดิน & โซนพัก | ป้าพร | กาแฟ 1 แก้ว | Don't step on the wet trail. **The coffee was hers:** once you brew it she chases you, and you run for the elevator (checkpoint at the coffee) |
| 3 | ห้องเซิร์ฟเวอร์ | เต้ | breaker + 3 post-its + PC | **Whole floor blacked out**, only red emergency lights. Flip the breaker (loud), collect 3 post-its whose digits make the code, type it on the PC keypad. A wrong code sets off an alarm |
| 4 | ออกจากบริษัท | พี่สมชาย | hold the fingerprint scanner | He only moves when you're not looking, and **the lights die at random** (keep your flashlight on him). **Finale:** holding the scanner (3 s, you have to look away from him) brings everyone down the elevator after you |

## Endings (how to reach each)
- **Evidence = noticing พี่สมชาย:** answer a ringing desk phone (one per stage), spot him standing far away in stages 1–3 and keep looking until he vanishes, or read notes about him (building notice, IT ticket, repair log, Admin log, guard log, CCTV log).
- **Dream clues:** one per stage. Listen for a heart-monitor beep: a hospital wristband, an IV bag, a monitor hidden in a server rack, a get-well card.
- **B, Dream End:** all 4 dream clues + do NOT take the guard's phone. You wake up in hospital.
- **A, Good End:** take พี่สมชาย's phone from his booth in stage 4 + **at least 4 evidence**. You report him to the police.
- **C, Bad End:** anything else, and he follows you home.
- **Game Over:** Social Battery reaches 0.

## Editing (no code needed) → **[EDITING.md](EDITING.md)** (Thai, step by step)
| Scene / file | What's in it |
|---|---|
| `scenes/main.tscn` | Menu/HUD/flow (built by `scripts/main.gd`), loads the stages below |
| `scenes/player.tscn` | ต๋อง: CharacterBody3D + Camera3D + InteractRay + Flashlight |
| `scenes/mobs/*.tscn` | One scene per coworker (+ practice mannequin). Speed, rage speed, vision, battery drain and lines are in the Inspector |
| `scenes/stages/tutorial.tscn`, `stage_1..4.tscn` | The maps. Select the root for the stage mechanics (dark start, rage, flicker, finale) |
| `scenes/endings/ending_A/B/C.tscn` | The 3D ending rooms |
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
- `scripts/npc.gd` + `scripts/mobs/*.gd`: base coworker AI (patrol, investigate noise, search hide spot, chase, catch; NavigationAgent3D) + the 4 coworkers + a practice mannequin (`dummy.gd`)
- `scripts/player.gd`, `scripts/pickup.gd`, `scripts/body.gd` (@tool, loads the Blender model parts), `scripts/cutscene.gd`, `scripts/main.gd`
- `scripts/stage_builder.gd` + `tools/bake_stages.tscn`: one-time generator of the stage scenes
- `tools/blender/build_characters.py`: generates every character .blend/.glb in Blender · `shaders/vhs.gdshader`: fear post-process
- Assets and licenses: `ASSETS.md` · sounds: `tools/fetch_freesound.py` (CC0), `tools/synth_sfx.py`
