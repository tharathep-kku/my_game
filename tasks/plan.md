# Plan v5: from "works" to "feels finished" (UI, presentation, replay value)

v4 archived in `tasks/archive/`. Baseline before v5: 436 checks pass (only the fps checks fail on a
software renderer).

## Request (2026-10-24)
The user rates the game 20/100: the UI is plain. Goal: 80/100. Free hand.

## Identity
"Someone is watching": CCTV on-screen text (REC, CAM, timestamp) frames the transitions, and the
company's paperwork frames the results (performance review, HR warning letter, certificate).
Fonts: Kanit (titles, UI), Sriracha (handwriting on notes and sticky notes), Sarabun (body).

## Steps
- [x] U1 UI kit (`scripts/ui/kit.gd`): theme, fonts, colours, panel/button styles, sounds
- [x] U2 Profile (`Game`): chapters reached, endings seen, documents found, best grade per chapter
- [x] U3 Main menu: live 3D office behind it, glitch title, Tong's ID badge with progress, chapter
      select, document archive, endings gallery, credits, menu music
- [x] U4 HUD: battery widget, stamina, phone battery while the flashlight is on, objective sticky
      note, subtitles with the speaker's name in colour, key-cap prompt, low-battery vignette,
      first-time tips
- [x] U5 Phone: smartphone frame, home screen icons, chat with avatars + times, map app (rooms you
      have walked through), docs
- [x] U6 Screens: chapter card as a CCTV feed (typewriter), stage clear = performance review with a
      grade stamp, game over = HR warning letter, ending = certificate + endings gallery, pause =
      coffee break (objective, clues, evidence, settings)
- [x] U7 Settings: difficulty, brightness, FOV, VHS strength, subtitle size, invert Y, fullscreen
- [x] U8 Audio: menu music box, UI hover/click/typewriter/stamp sounds
- [x] U9 Tests green, docs, web build, push

## Done (v5)
- Extra polish: chase music while hunted, "checkpoint saved" note, restart chapter from pause,
  Continue names the saved chapter, credits roll, a random HR tip on the warning letter.
- Stage titles now read "บทที่ N : ..." everywhere.
