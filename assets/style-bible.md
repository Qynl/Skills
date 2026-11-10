# Style bible — <build name>

Fill this in before the first part. Every later pass refers back to it, so the build stays one place instead of six ideas. Keep it short enough to re-read at the start of each `execute_luau` call.

## Mood

Three adjectives, specific enough that they imply decisions:

- e.g. `weathered Nordic fishing village`
- e.g. `neon-lit cyberpunk night market`
- e.g. `sun-bleached desert outpost`

**Hero shot** (what the player sees first, and from where):

> Standing at the south gate looking north across the plaza at the lighthouse.

## Palette

| Role | Color | RGB / hex | Used on |
|---|---|---|---|
| Dominant (60%) | | | |
| Secondary (30%) | | | |
| Accent (10%) | | | interactables only |
| Shadow/dark | | | |
| Highlight | | | |

Rule: no more than 6 colors. Variation comes from value and material, not new hues.

## Materials

| Material | Means | Used on |
|---|---|---|
| e.g. `WoodPlanks` | structure, old | walls, beams, crates |
| e.g. `Slate` | wet, cold | roofs, plinths |
| e.g. `CorrugatedMetal` | industrial | sheds, signage |
| e.g. `Concrete` | civic | plaza, walls |
| e.g. `Fabric` | soft | awnings, banners |

Four to six. Anything not in this table needs a reason.

## Scale and grid

- Module: `16` studs (buildings) / `4` (interiors)
- Alignment: 0.5-stud grid, part positions are centers
- Character reference: ~5 studs tall, steps up to 2
- Doors: 7–8 × 4–5 · Ceiling: 12 · Wall: 0.75 · Stairs: rise 1.0, run 1.2

## Lighting

- Preset: `goldenHour` / `overcast` / `interiorWarm` / `nightNeon` / `storm`
- Tweaks from the preset:
- Local lights: where, what color, how many shadowed
- Time of day the build must also work at (if any):

## Silhouette rule

What makes this recognizable from 100 studs away:

> A leaning lighthouse with a broken lamp room, visible over the roofline.

## Kit list

Pieces to build once and clone (name → size):

- `Wall_Straight_16` — 16 × 12 × 0.75
- `Wall_Window_16` — 16 × 12 × 0.75 with a 4 × 4 recessed opening
- `Wall_Door_16` — 16 × 12 × 0.75 with a 5 × 8 opening
- `Floor_16` — 16 × 1 × 16
- `Roof_Slope_16` — 16 × 1 × 9 at 35°
- `Trim_Base_16` — 16 × 0.4 × 0.3
- `Stair_8x12` — steps of rise 1.0 / run 1.2

## Do / don't

- DO: recess every opening; trim every edge; cluster props in threes
- DO: vary rotation and small offsets so nothing lines up perfectly
- DON'T: tile flat floors; stack transparent parts; add a seventh material
- DON'T: put detail only above head height

## Pass log

| Pass | What | Verified (capture?) | Notes |
|---|---|---|---|
| A massing | | | |
| B architecture | | | |
| C lighting | | | |
| D dressing | | | |
