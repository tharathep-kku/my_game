# Plan v7: psychological horror, an AI that isn't annoying, a quieter HUD

v6 archived in `tasks/archive/`. Baseline: 457 checks pass (only fps checks fail on a software renderer).

## Request (2026-10-25)
"The sticky note top right is cluttered: can it open/close? The AI is annoying. I want psychological,
haunting horror. Think it through."

## Why the AI is annoying (code review)
- Leash: when a coworker is more than half the map away, its patrol drifts toward Tong: always near.
- A chase never ends until Tong is in a hide spot ("keeps coming no matter what breaks sight").
- Hunch: every 10-20 s a coworker may "get a hunch" and walk to where Tong is.
- +5 % speed per goal on top of +20 %.
- หัวหน้าธนา peeks every 7-11 s and says the same line each time.
- "!"/"?" over heads: a game UI, not dread.
Result: constant pressure with no rhythm. Horror needs quiet, a slow build, a peak, then relief.

## Design
1. HUD: the objective note folds to a small tab; it opens by itself for a few seconds when the
   objective changes, O pins it open (setting: always open). Head marks only on Easy.
2. AI: no leash, no hunch, no speed creep. A chase ends when Tong breaks line of sight for a few
   seconds (it searches where it last saw him, then goes). After a chase or a catch the coworker
   withdraws to the far side of the floor for a while (relief).
3. Director (scripts/director.gd), one per chapter, runs the rhythm:
   - calm -> stalk (the coworker comes to somewhere near but out of view, lingers, leaves)
     -> chase if it sees him -> relief. Menace builds while it is close.
   - Psychological events, no damage, never during a chase: footsteps behind that stop when he
     stops, his name whispered behind him, lights dying one by one toward him, a figure at the edge
     of vision that is gone when he looks, words glowing on a dead monitor, total silence and then
     a breath at his neck, the HUD clock jumping to 02:14, a text from his own number, a call from
     Mum that is only breathing.
   - The stranger texts what Tong is doing right now: hiding, standing still, flashlight on,
     running, crouching, turning round, just read a note.
   - More often and stranger as Social Battery falls and the night goes on.

## Steps
- [x] H1 HUD: foldable objective note, marks only on Easy
- [x] H2 AI: drop leash/hunch/speed creep, chase gives up, retreat state, quieter boss
- [x] H3 Director: rhythm (stalk/relief) + psychological events + reactive texts
- [ ] H4 Tests, docs, web build, push
