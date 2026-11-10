---
name: webgame
description: Builds genuinely fun, polished browser games — HTML5 canvas or DOM games that feel good in the first five seconds and still feel good twenty minutes in. Use this skill whenever the user wants to make a game that runs in a browser: web game, browser game, HTML5/canvas game, arcade clone, jam entry, endless runner, platformer, roguelike, tower defense, idle/clicker, bullet-hell, physics toy, "something small I can play", or a game embedded in a landing page — even if they never say the word "game genre" and just describe a mechanic. Also use it when improving an existing web game's game feel, juice, difficulty curve, performance, or mobile controls, and when asked why a prototype "runs but isn't fun".
---

# Web games that are actually good

The difference between a prototype that runs and a game someone plays twice is rarely the code. It's **game feel** (does the input feel connected to the world?), **the first ten seconds** (do I understand and win something immediately?), and **retry friction** (can I be playing again in under a second?). This skill is a process for getting all three right fast, plus a starter that already has the plumbing.

Most people asking for a web game want something playable today, not an engine. So default to the smallest thing that could be fun, get it playable early, then spend your remaining effort on the two or three interactions the player does a thousand times. Polish per mechanic is what makes games good; every extra mechanic divides that polish.

## 1. Decide the shape before writing code

Answer these three in one sentence each. Don't workshop them — commit, and be willing to change after it's playable.

- **Core verb**: the thing the player does constantly (jump, dash, shoot, place, merge, dodge, aim).
- **Failure and retry**: what ends a run, and how many inputs it takes to be back in it (target: one).
- **Session length**: 90-second arcade loop, a 5-minute roguelike run, or endless.

If a proposed feature doesn't sharpen the core verb, cut it. A jam-sized game is one screen of rules; the depth comes from combinations, timing, and escalation, not from a feature list.

**Stack.** Default to one self-contained `index.html` — inline CSS, inline JS, zero dependencies, zero build step. It loads instantly, works from `file://`, drops into any host, and is trivial to test. Reach for tooling only when it pays for itself:

- **Vite + TS** when the game will grow past ~1500 lines or is team-owned.
- **Three.js / Babylon** only for real 3D. Don't fake 3D with CSS transforms for a game.
- **matter.js / planck.js** when physics *is* the game (stacking, ragdolls, vehicles). For bouncing balls and circle collisions, hand-rolled math is smaller and more predictable.
- **Phaser / PixiJS** when the user already knows them or needs sprites/atlases at scale. A custom loop is more direct for small games.

Never require a build step just to see the game. `python3 -m http.server` or a static file is enough to play it.

## 2. Build the core loop, then play it

Get a gray-box version playable — rectangles, no art — before any polish. If the loop isn't fun as colored boxes, art won't save it; if it is, art multiplies it.

Use a **fixed timestep** so physics is identical on a 60Hz laptop and a 120Hz phone, with an accumulator and an interpolated draw. See `assets/skeleton.html` for the working pattern, and `references/tech.md` for the reasoning and the variants.

Then actually run it. Load the page, check the console, play for 60 seconds. Ask two questions:

1. In the first 5 seconds, did I do the core verb and get a win?
2. When I lost, did I know exactly what I did wrong, and want to go again?

If either answer is no, fix that before adding content.

## 3. The feel pass — the part that makes it "really good"

This is where most of the quality lives, and it's cheap: each item is a few lines.

- **Every input gets an answer within one frame.** A pressed key must produce visible motion, a muzzle flash, a squash — something — on the same frame.
- **Every contact gets a reaction.** A hit with no particles, no sound, no shake reads as "nothing happened." Hit something: 6–14 particles, 40–90 ms hitstop, a small shake, a sound, a number that pops.
- **Nothing moves linearly forever.** Ease movement, add acceleration and drag, gravity, overshoot. Velocities that snap on and off feel like a spreadsheet; ramps feel like matter.
- **The player must always know why they died.** Telegraph attacks (a 300–500 ms wind-up, a color change), keep hazards on screen, never kill from an unexplained edge of the screen.
- **Shake, flash, and slow-mo are spice, not the meal.** Use trauma that decays and squares (so it's subtle until it's big), and don't shake the camera on every frame of a continuous event.

`references/game-feel.md` has the catalogue with tuning numbers and canvas snippets: hitstop, trauma shake, squash & stretch, coyote time, jump buffering, easing, camera lead, afterimages, number pop-ups, telegraphs, and how to respect `prefers-reduced-motion`.

## 4. Difficulty and pacing

- **Start trivially easy.** The first spawn should be a guaranteed win so the player learns the verb with no risk.
- **Escalate in waves**: tension, then a breath, then more. Constant intensity becomes noise; players need a release to feel the spike.
- **Difficulty from combinations, not stat inflation.** One more enemy type interacting with an existing one is more interesting than +10% speed.
- **Give the score a story.** Combo multipliers, near-miss bonuses, and "you were 40 points from the best" all make a run feel authored rather than random.

Read `references/genres.md` for the numbers that ship: spawn rates, jump arcs, bullet speeds, economy curves for the genre you're building.

## 5. Session design (the invisible UX)

- **Five-second rule.** The goal is learned by playing, not reading. At most one line of text on screen at a time, and only when the player needs it.
- **Restart is one key or one tap**, and it happens instantly — no logo, no menu bounce. Also allow `R`.
- **Pause on blur / tab hide** (`visibilitychange`), and never let a hidden tab drain a run. Resume with a clear "paused — click to resume".
- **Persist the record** (`localStorage` in a `try/catch`) and show it on the title screen; beating it should visibly celebrate.
- **Sound on by default, mute one click away**, and remember the choice.
- **Respect `prefers-reduced-motion`**: drop shake and flashing (keep the gameplay identical), since screen shake and strobing are real accessibility problems.
- **Resize gracefully.** The game should fit a phone in portrait and a 4K window without letterboxing weirdness; recompute the world bounds on resize and clamp entities inside them.

## 6. Input

Treat input as **state**, not events, for continuous actions, and as **buffered events** for discrete ones.

- Keyboard: WASD *and* arrows, plus `Space`/`Enter` to act, `P`/`Esc` pause, `R` restart. `preventDefault` on arrows/space so the page doesn't scroll.
- Mouse: only if aiming is the verb. Otherwise keep the game keyboard/touch-first.
- Touch: this is where web games usually fail. Pick one: direct drag/steer toward the finger, or on-screen buttons with ≥44px hit areas. Use Pointer Events, support multi-touch, never rely on hover, and set `touch-action: none` on the canvas.
- Buffer intent: if a jump is pressed 100 ms before landing, it should still fire (input buffering). If the player leaves a ledge 100 ms ago, they should still get the jump (coyote time). Both feel like "the game is responsive"; their absence feels like "the game is broken."
- Gamepad via the Gamepad API is a nice bonus when the genre implies it; poll it in the loop, don't wire events.

## 7. Audio

Synthesize with WebAudio instead of shipping assets — a `beep(freq, duration, type)` helper covers hits, pickups, jumps, and UI. Create the `AudioContext` on the **first user gesture** (browsers block it otherwise), route everything through one master gain around 0.2–0.3, and pitch the pickup sound up with the combo so the score is audible. Mute must stop it instantly.

## 8. Performance budget

- 60 fps at 1080p is the bar. Cap device pixel ratio at 2 — a 3× retina canvas is 9× the pixels for no visible gain.
- **Allocate nothing per frame.** Pool particles, bullets, and pop-ups in preallocated arrays with a `life` field.
- Avoid `shadowBlur` in hot loops (it's extremely slow on some GPUs), and avoid setting `ctx.filter`. Fake glow with a second translucent draw or a radial gradient baked once.
- For DOM games, animate only `transform`/`opacity`; never touch layout in a loop.
- Above ~200 interacting entities, add a spatial grid for collisions instead of the naive O(n²). Below that, the naive loop is faster and simpler.
- Measure: log `performance.now()` deltas for 5 seconds before claiming 60 fps.

## 9. Verify before you say it's good

Run this on the actual artifact, not in your head:

- [ ] Page loads with no console errors or 404s.
- [ ] The core verb works with keyboard *and* touch (or the device you claim to support).
- [ ] You lost, restarted, and lost again three times without a stuck state.
- [ ] Resizing and rotating the window doesn't break layout or spawn positions.
- [ ] Arrows/space don't scroll the page; blur pauses the run; mute works.
- [ ] High score survives a reload.
- [ ] Frame time stays under 16 ms on the busiest moment (many enemies + particles).

Then answer honestly: **did it feel good when you played it?** If you couldn't play it — no display, no browser — say exactly that and describe what you verified (loads, syntax, tests) instead of claiming it feels good. "It compiles" is not "it's fun."

## What's in this skill

| Path | Read it when |
|---|---|
| `assets/skeleton.html` | **Start here for any new game.** A complete, fun little arcade game (dodge & collect) with fixed timestep, DPR handling, trauma shake, hitstop, pooled particles, combo scoring, synthesized audio, touch steering, pause-on-blur, and persisted high score. Copy the plumbing, replace the verb and the content. |
| `references/game-feel.md` | You're in the feel pass, or the user says it "feels stiff/floaty/not satisfying". |
| `references/genres.md` | You're picking numbers for a specific genre, or choosing what to build next. |
| `references/tech.md` | Loop, DPR/resize, collisions, pooling, save data, audio, mobile quirks, or which library to use. |
| `evals/evals.json` | You want to test whether this skill is actually producing good games. |

Build order that works: skeleton → change the verb and the failure state → playable gray-box in one sitting → feel pass on the two most frequent interactions → one session of pacing tuning → verify checklist → ship.

## Anti-patterns (the "soulless prototype" tells)

- A text tutorial or several screens of instructions before the player can act.
- A menu, settings page, or save system built before the verb is fun.
- Movement that snaps to max speed instantly with no easing, drag, or weight.
- Hits with no visual, no sound, and no number — the classic "does it even connect?" feeling.
- Random unfairness: enemies spawning on top of the player, offscreen projectiles, invisible timers.
- A single global best score with no per-run feedback, so a decent run feels like nothing.
- Screen shake, flashing, and particle storms on everything, which reads as noise and can make players motion-sick.
- Adding a second and third mechanic when the first one still feels bad.
- Claiming the game is fun, polished, or working on mobile without having played it there.
