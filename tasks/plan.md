# Plan v8 (branch claude/hd-3d-remaster): HD 3D remaster

v7 archived in `tasks/archive/`. Baseline: 470 checks pass (only fps checks fail on a software renderer).

## Request (2026-10-25)
"Make a new branch and turn the game into 3D. Look at examples online and make it complete."
The game is already 3D; what reads as "not 3D" is the 320x240 PSX render, wobbly polygons, 16x16
nearest textures, flat lighting and the VHS filter. The remaster keeps every mechanic and scene file,
and changes how it is drawn. The PSX look stays as a setting.

## Steps
- [x] R1 Render core: dual-look psx shader (global retro_look), HD textures (generated), surface
      kinds detected from the builder's 16x16 textures (no re-bake: editor edits are kept),
      environment (ACES, glow, SSAO, SSIL, volumetric fog), film post-process, full-res view, MSAA,
      FSR render scale, graphics settings
- [x] R2 Tuning: light pools + nearest-light shadows, skirting + contact shading on walls,
      furniture surfaces by colour, rounded characters (Blender bevel), two-light torch, sharp
      portraits
- [ ] R3 Tests, docs, web build, push the branch

## References
- Godot docs: volumetric fog (Forward+ only), resolution scaling (FSR 1/2), environment and
  post-processing.
