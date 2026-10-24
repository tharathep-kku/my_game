# Plan v3: real character models, more horror, tutorial, useful notes, distinct stages

v2 archived in `tasks/archive/`. Baseline before v3: 187 tests PASS.

## Decisions (confirmed with user, 2026-10-01)
- **Characters:** remodel all of them in Blender (Tong, Thana, Pa Porn, Tae, Somchai, doctor + tutorial mannequin), following the pitch-deck art. No more face photo pasted on a box.
- **Horror:** scripted scares + hallucinations tied to Social Battery + blackout/flashlight + chase sequences.
- **Tutorial:** stage 0 that plays before stage 1 (skippable).
- **Notes:** give a real hint inside the stage + count as evidence toward Ending A.
- **Stages:** each stage gets its own core mechanic.
- **Editing:** editable in the Godot editor (Inspector) + a step-by-step guide.

## Root causes found
- Notes showed nothing: `Game.note_opened` is emitted, but no UI is connected to it.

## Tasks
- [x] T1 Blender: `tools/blender/build_characters.py` → `assets/characters/<name>.blend` + `.glb`; segmented PSX model with parts LegL/LegR/ArmL/ArmR/Torso/Neck(NeckMesh, Head) so the existing animations/jumpscares keep working; `body.gd` loads the glb
- [x] T2 Notes: reading UI + `title/text/reveal/evidence` in the Inspector + reveal (goals/hides/npc) + evidence → Ending A
- [x] T3 Editable nodes: `story_trigger.gd` (monologue/chat/sound) + `scare.gd` (lights_out / figure / behind / sound), placed in scenes
- [x] T4 Horror systems: VHS/hallucination shader by battery, phantom coworkers when battery is low, NPCs see the flashlight / dark hides you
- [x] T5 Stages: 1 stealth + scares · 2 coffee → chased by ป้าพร to the elevator · 3 floor blackout, breaker, post-it codes → keypad · 4 flickering lights let พี่สมชาย move + finale where everyone chases you while you hold the fingerprint scan
- [x] T6 Stage 0 tutorial (mannequin NPC; walk, sprint, crouch, read, phone/flashlight, throw, hide/hold breath)
- [x] T7 `EDITING.md` (Thai), README/report/ASSETS, tests (259 PASS)
- [x] T8 web export to `docs/` (tested in headless Chrome: menu, tutorial, stage 4). Exe: only web templates are installed
- [x] T9 Stage 0 redone as a half-cutscene intro: bright afternoon with the four coworkers at work and chatting -> texts from the unknown number that lock you until read (controls, then the night-shift rumour) -> day turns to night -> mirror ending (`tutorial.gd`, `coworker.gd`). Replaces the T6 mannequin course. `docs/` web build not re-exported yet
