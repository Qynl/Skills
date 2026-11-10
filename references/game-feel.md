# Game feel catalogue

Every technique here is small. The point is sequencing: the player does something (input) → the world answers (motion) → the world reacts (impact) → the world tells them how it went (score/state). Games that feel bad are missing steps 3 and 4.

Numbers below are starting points tuned for a 60fps canvas game with a world roughly 1000 units wide. Scale shake and particle speed with `min(width, height)` so the feel survives on a phone.

## 1. Hitstop (freeze frames)

On impact, pause the *world* for 1–4 frames while the screen keeps drawing. This is the single highest-value juice trick: it makes a hit feel like it has mass.

```js
let hitstop = 0;                 // seconds remaining

function impact(strength = 1) {  // 0.5 = light tap, 2 = heavy
  hitstop = Math.max(hitstop, 0.045 * strength);
  shake(0.18 * strength);
}

function update(dt) {
  if (hitstop > 0) { hitstop -= dt; return; }  // world frozen, particles too
  // ...normal update
}
```

Light hits: 40–60 ms. Heavy/melee: 80–120 ms. Never above ~150 ms or the game reads as a stutter. Still render during hitstop, and let UI/camera shake keep animating so it feels intentional.

## 2. Trauma-based screen shake

Do not use `Math.random() * amount` per frame — it looks like a broken camera. Use trauma that decays, squared for a soft falloff:

```js
let trauma = 0;                                   // 0..1
const addTrauma = t => { trauma = Math.min(1, trauma + t); };

function updateShake(dt) {
  trauma = Math.max(0, trauma - dt * 1.6);         // ~0.6s to settle
  const s = trauma * trauma;                       // squared: subtle until big
  const amp = s * Math.min(W, H) * 0.03;
  shakeX = (Math.random() * 2 - 1) * amp;
  shakeY = (Math.random() * 2 - 1) * amp;
  shakeAngle = (Math.random() * 2 - 1) * s * 0.02; // radians, keep tiny
}

// render
ctx.save();
ctx.translate(W / 2 + shakeX, H / 2 + shakeY);
ctx.rotate(shakeAngle);
ctx.translate(-W / 2, -H / 2);
// draw world
ctx.restore();
```

Budget: pickup 0.08, hit taken 0.5, big explosion 0.8. If everything shakes, nothing does — reserve the strong values for real events. Set it to zero and drop flashing when `prefers-reduced-motion: reduce` matches.

## 3. Squash & stretch

Scale an entity opposite on each axis to sell velocity and impact. One line each:

```js
// when moving fast horizontally, stretch along the motion
const speed = Math.hypot(vx, vy);
const stretch = Math.min(0.35, speed / maxSpeed * 0.3);
const ang = Math.atan2(vy, vx);
ctx.rotate(ang);
ctx.scale(1 + stretch, 1 - stretch * 0.6);
ctx.rotate(-ang);

// on landing/hit, set a spring value and let it settle
p.squash = 0.4;                       // set on impact
p.squash *= Math.pow(0.001, dt);      // fast decay (~0.15s)
const s = p.squash;
ctx.scale(1 + s, 1 - s);
```

## 4. Easing

Linear motion is the number one cause of "floaty". Keep a tiny toolbox instead of reaching for a library:

```js
const easeOutCubic = t => 1 - Math.pow(1 - t, 3);   // enters fast, settles
const easeInCubic  = t => t * t * t;                // for wind-ups
const easeOutBack  = t => 1 + 2.2 * Math.pow(t - 1, 3) + 1.2 * Math.pow(t - 1, 2); // overshoot pop
const easeInOutQuad = t => t < 0.5 ? 2*t*t : 1 - Math.pow(-2*t + 2, 2) / 2;
```

Use `easeOutBack` for UI that pops in, `easeOutCubic` for camera moves and score counters, `easeInCubic` for a charge-up before release.

## 5. Movement weight (acceleration + drag)

Snap-on velocity feels like a cursor. Give acceleration and friction, then clamp:

```js
const ACCEL = 2600, MAX_SPEED = 430, FRICTION = 9;

function move(p, ix, iy, dt) {            // ix, iy in [-1, 1]
  p.vx += ix * ACCEL * dt;
  p.vy += iy * ACCEL * dt;
  const drag = Math.exp(-FRICTION * dt);  // frame-rate independent
  p.vx *= drag; p.vy *= drag;
  const sp = Math.hypot(p.vx, p.vy);
  if (sp > MAX_SPEED) { p.vx *= MAX_SPEED / sp; p.vy *= MAX_SPEED / sp; }
  p.x += p.vx * dt; p.y += p.vy * dt;
}
```

Time-to-max with those numbers ≈ 0.18 s: responsive but not instant. For platformers, keep horizontal accel quick (~0.1 s to speed) and make *air control* weaker (~60–70%) — that difference is what makes a jump arc feel physical.

## 6. Jump: variable height, coyote time, buffering

These three turn a jump from "technically works" into "feels great". Together they're ~15 lines.

```js
const COYOTE = 0.10;      // grace after leaving ground
const BUFFER = 0.12;      // grace for pressing before landing

let coyote = 0, buffered = 0, jumpHeld = false;

// keydown(jump): buffered = BUFFER
// keyup(jump):   jumpHeld = false
// on ground:     coyote = COYOTE

if (buffered > 0 && coyote > 0) {
  vy = -JUMP_SPEED; buffered = 0; coyote = 0;
}
// variable height: cut the rise when the button is released
if (!jumpHeld && vy < 0) vy += GRAVITY * 2.2 * dt;
```

Numbers for a platformer with a 64px character: `JUMP_SPEED ≈ 620`, `GRAVITY ≈ 2100`, and give falling ~1.3× gravity so the arc doesn't feel like the moon.

## 7. Particles (pooled, cheap)

Preallocate, never `new` per frame. Burst on every hit and pickup:

```js
const pool = Array.from({ length: 400 }, () => ({ life: 0, x:0, y:0, vx:0, vy:0, size:2, hue:0 }));

function burst(x, y, n, hue, speed = 180) {
  for (let i = 0; i < n; i++) {
    const p = pool.find(q => q.life <= 0); if (!p) return;
    const a = Math.random() * Math.PI * 2, s = speed * (0.35 + Math.random());
    p.x = x; p.y = y; p.vx = Math.cos(a) * s; p.vy = Math.sin(a) * s;
    p.life = 0.25 + Math.random() * 0.3; p.maxLife = p.life;
    p.size = 1.5 + Math.random() * 2.5; p.hue = hue;
  }
}

function updateParticles(dt) {
  for (const p of pool) {
    if (p.life <= 0) continue;
    p.life -= dt; p.x += p.vx * dt; p.y += p.vy * dt;
    p.vx *= Math.exp(-4 * dt); p.vy *= Math.exp(-4 * dt);
  }
}

function drawParticles(ctx) {
  for (const p of pool) {
    if (p.life <= 0) continue;
    ctx.globalAlpha = Math.max(0, p.life / p.maxLife);
    ctx.fillStyle = `hsl(${p.hue} 90% 65%)`;
    const s = p.size * (0.4 + 0.6 * p.life / p.maxLife);
    ctx.fillRect(p.x - s / 2, p.y - s / 2, s, s);
  }
  ctx.globalAlpha = 1;
}
```

Counts: 6–10 for a small pickup, 12–20 for a kill, 30+ only for a genuine explosion. Draw squares, not arcs — `fillRect` is far cheaper.

## 8. Telegraphs and anticipation

Before a threat becomes dangerous, show it: 300–500 ms wind-up with a color shift, growing outline, or pull-back. In a shoot-'em-up, a flash before a shot; in a platformer, a crouch before a leap. This is the difference between "unfair" and "hard but fair". Pair the wind-up with `easeInCubic` scaling (slow, then fast) and a rising sound.

## 9. Camera

- **Follow with lead**: offset the camera toward the velocity (`cam += (target + vel * 0.25 - cam) * (1 - exp(-6*dt))`), so the player sees where they're going.
- **Clamp to world bounds** so you never show void.
- **Do not rotate** unless 3D. Rotating cameras in 2D arcade games make players sick.
- Snap-to-target during respawn so the player never starts off-screen.

## 10. Number and score feedback

The score should *move*, not jump:

```js
displayed += (score - displayed) * (1 - Math.exp(-12 * dt));  // tween, draw Math.round
```

Floating text on pickups: `+25` rising 40px over 0.6 s with `easeOutCubic`, fading in the last third, and scaled up 1.2× if the combo is above 3. Combo UI should pulse (scale 1.15 → 1 over 120 ms with `easeOutCubic`) whenever it increments — that pulse is the reward.

## 11. Afterimages, trails, and flashes

- Afterimage: every 40 ms push `{x, y, alpha: 0.5}` and fade out over 150 ms. Great for dashes.
- Dash/impact flash: draw the entity again with `globalCompositeOperation = 'lighter'` and a slightly larger radius for 80 ms.
- Screen flash: fill the canvas with a color at alpha 0.12–0.25 for 60–90 ms max. Full-screen white at high alpha is a photosensitivity hazard.

## 12. Readability (feel is also legibility)

- One accent color for the player, one for danger, one for reward. If the player can't parse the screen in 100 ms, the game feels chaotic no matter how smooth it is.
- Enemy and pickup silhouettes must differ (diamond vs circle), not just their hue — this keeps the game playable for color-blind players.
- Keep the background low-contrast and desaturated so foreground action pops.
- Draw the player last, and give them a subtle outline or glow so they're locatable in a crowd.
- Health, combo, and ammo go near where the eyes already are — usually under the score, top-left, or attached to the player.

## 13. The one-screen test

Squint at a screenshot of your game. Within a second you should be able to point at: the player, the threat, the goal, and the score. If you can't, fix contrast and layout before adding any more juice.
