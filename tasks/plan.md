# Plan v6: longer, with more story (side jobs, a story arc, a case file)

v5 archived in `tasks/archive/`. Baseline: 443 checks pass (only fps checks fail on a software renderer).

## Request (2026-10-25)
"The game is quite short. Improve what you think is interesting, add story systems."

## Assessment
- Walking every chapter's goals straight to the exit takes 0.5-1.5 min per chapter (BFS over the
  maps); with stealth and hiding, the whole game is roughly 40-60 min.
- The story is strong but thin on the ground: told in phone texts, notes and the chapter cards.
  There is little to do off the main path, and nothing that pays off across chapters except the
  evidence/clue counts for the endings.

## Idea
A data-driven job system ("งาน"): characters text Tong a job; each job is a few steps (go to a room,
pick something up / put it somewhere), with story on every step (a note, a line, a scare, a short
scene) and a payoff (Social Battery, phone battery, evidence, a case-file entry).
- Side jobs: optional, 1-2 per chapter, across three arcs:
  - ฝน: the night-shift accountant before Tong, who "resigned" last year. Six jobs uncover what the
    guard did to her. Completing the arc adds an epilogue to the endings.
  - แม่: small jobs that are echoes of what Mum is doing at Tong's hospital bed. Heal.
  - เต้ / กลุ่ม IT: comic errands with useful rewards (phone battery, reveal goals).
- Main jobs: one required job in the shortest chapters (the exit stays shut until it's done).
- Phone app 5 "งาน": jobs in progress, and the case file of finished ones (the story so far).

## Steps
- [x] J1 Engine: quests in story.gd, Game state (save, retry snapshot), runtime items, objective,
      rewards, exit gating, GPS, tests
- [x] J2 UI: HUD side-job line, phone app "งาน", pause sheet, review row + grade bonus, archive
- [x] J3 Content: ~12 jobs over chapters 1-4, 6, 7 (Thai), epilogue on the endings
- [ ] J4 Checks: reachability test for every job cell, full suite, visual pass, docs, web build, push

## Done (v6)
- 13 jobs: ฝน ×6 (chapters 1, 2, 3, 4, 6, 7, chained), แม่ ×3, เต้/IT ×2, required ×2 (chapters 1, 3).
- Endings: ฝน's epilogue panel per ending (or a nudge if her story was started but not finished).
- Review: side jobs done x/y, +5 score each (and 4 more minutes allowed before the time penalty).
- Tests: t_quests (engine), t_reach (every job step reachable from the spawn).
