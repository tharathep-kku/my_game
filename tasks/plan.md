# Plan v4: longer story, more stages, scarier, ending fixes

v3 archived in `tasks/archive/`. Baseline before v4: the v3 suite (259 checks).

## Request (2026-10-24)
More story, gameplay that doesn't get boring, aim for a ~5 hour game, story cutscenes where Tong runs
from the ghosts, real jump scares, scarier models, and fix the ending cutscenes that look wrong.

## Root causes found (ending cutscenes)
- After every ending vignette the cutscene camera was freed before the fade-out. Endings have no
  player camera to fall back to, so the screen went grey and the HUD (battery bar, phone hint)
  popped back up for a second before the ending card.
- Ending C: the camera started on the dividing wall, the guard stood facing away from the camera
  (he faced into his own room), and there was no door: the "peephole" shot (fov 130) showed the
  side of his head from 1 m away.
- Ending B: "turn left" swung the camera past the doctor into the wall.

## Steps
- [x] S1 Endings: keep the last shot until the fade is done, HUD stays hidden; restage A/B/C (door +
      peephole in C, B camera framing, A police lights); ending D (true end)
- [x] S2 Scarier models (Blender script, run with the `bpy` module): night versions of the four
      coworkers + doctor + faceless night staff, glowing eyes through the PSX shader; the tutorial's
      daytime coworkers keep the normal models (`*_day` presets)
- [x] S3 Cutscene steps for chases: `run`, `move`, `turn`, `gone`, `neck`, `part`, `shake`, `scare`
      (face slam), `fade`, `peephole`, `tint`, `warp`; scare kinds `rush`, `face`, `peek`, `crawl`;
      mid-stage cutscenes (`item_scenes`, `rage_scene`, `goal_scares`)
- [x] S4 New stages (each with its own mechanic, intro chase cutscene, notes, scares, clue):
      - HR & meeting room: พี่แหม่ม HR calls Tong's name over the PA; when the chime ends she knows
        where you are unless you are hidden
      - Fire stairs: the corridor loops; spot what changed, turn back if anything is wrong, 8 clean
        loops to get out (anomalies, some of them come at you)
      - Hospital (the dream): the doctor hears your heartbeat; running and fear make it louder,
        hiding and holding your breath calm it
- [x] S5 Story: more texts/notes/triggers/scares in the old stages, clue/evidence totals follow the
      stage list, endings text, true ending D
- [ ] S6 Tests green, README / EDITING / ASSETS, web build in `docs/`, commit + push

## Notes
- Tests run headless need a renderer for screenshots: `xvfb-run ... --rendering-driver opengl3`. The
  "runs at N fps" checks fail on a software renderer only.
- New models were built with the `bpy` pip module (Blender 5.2) from `tools/blender/build_characters.py`.

## Stage order (v4)
0 บทนำ · 1 แผนกบัญชี · 2 โถงทางเดิน · 3 ฝ่ายบุคคล & ห้องประชุม (new) · 4 ห้องเซิร์ฟเวอร์ ·
5 บันไดหนีไฟ (new) · 6 โรงพยาบาล (new) · 7 ออกจากบริษัท

Old stage scenes keep their file names (stage_1..4.tscn); each stage entry in story.gd says which
scene it uses (`scene`), so editor edits in them are kept.
