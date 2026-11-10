# Web game tech reference

Everything here is for games you can open in a browser without a build step. Read the section you need — you rarely need all of it.

## File layout

**Single game, single file** (default): one `index.html` with inline CSS and JS. Ship it as-is.

**When it outgrows ~1500 lines**, split by concern but keep it esm-native so it still opens from a static server:

```
game/
├── index.html
├── style.css
└── src/
    ├── main.js        // boot, loop, state machine
    ├── input.js
    ├── audio.js       // synth + mute
    ├── entities.js
    ├── particles.js
    └── ui.js
```

Use `<script type="module" src="src/main.js">`. Modules require `http://` (not `file://`), so tell the user to run `python3 -m http.server 8000` — and keep the game playable that way rather than adding a bundler.

## Canvas setup, DPR, and resize

A canvas with CSS size `W×H` and no DPR scaling looks blurry on phones. Size the backing store by DPR and draw in CSS pixels:

```js
const canvas = document.getElementById('game');
const ctx = canvas.getContext('2d', { alpha: false });  // opaque canvas is faster
let W = 0, H = 0, DPR = 1;

function resize() {
  DPR = Math.min(window.devicePixelRatio || 1, 2);       // cap at 2: 3x costs 2.25x pixels for no gain
  W = canvas.clientWidth;
  H = canvas.clientHeight;
  canvas.width  = Math.round(W * DPR);
  canvas.height = Math.round(H * DPR);
  ctx.setTransform(DPR, 0, 0, DPR, 0, 0);                // draw in CSS px from here on
  onResize();                                            // clamp entities, rebuild cached background
}

addEventListener('resize', resize);
resize();
```

CSS: `html,body{margin:0;height:100%;overflow:hidden} canvas{display:block;width:100vw;height:100vh}`. Add `touch-action:none` on the canvas, `-webkit-user-select:none`, and `-webkit-tap-highlight-color:transparent`.

Don't hardcode a 800×600 world unless the game genuinely needs a fixed aspect. Fit to the window and scale entity sizes from `Math.min(W, H)` so feel is identical on a phone.

## The loop: fixed timestep + interpolated render

Physics must be deterministic per step, otherwise jump heights and collision results change with refresh rate. Accumulate real time and consume it in fixed 1/60 s steps:

```js
const STEP = 1 / 60;
let acc = 0, last = performance.now();

function frame(now) {
  acc += Math.min((now - last) / 1000, 0.25);  // clamp: tab-switch must not fast-forward the game
  last = now;
  let guard = 0;
  while (acc >= STEP && guard++ < 8) { update(STEP); acc -= STEP; }
  render(acc / STEP);                          // alpha for interpolation if you use it
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
```

Pass `dt` into `update` and use it for everything (`x += vx * dt`). Never multiply by a hardcoded `0.016` — that's the same as assuming 60fps and breaks on 120Hz displays.

Interpolation is optional for pixel-art or grid games (just snap). For smooth movement, store `prevX/prevY` before each update and draw at `prev + (cur - prev) * alpha`. Skip it rather than adding complexity if you can't see a difference.

## Input

Keyboard as state, actions as buffered events:

```js
const keys = new Set();
addEventListener('keydown', e => {
  if (['ArrowUp','ArrowDown','ArrowLeft','ArrowRight','Space'].includes(e.code)) e.preventDefault();
  keys.add(e.code);
});
addEventListener('keyup', e => keys.delete(e.code));
addEventListener('blur', () => keys.clear());  // otherwise a key "sticks" after alt-tab
```

Use `e.code` (physical key) not `e.key` so WASD works on AZERTY layouts. Support WASD **and** arrows, always.

### Touch

Pointer Events cover mouse, pen, and touch in one path; multi-touch via `pointerId`.

```js
canvas.addEventListener('pointerdown', e => {
  canvas.setPointerCapture(e.pointerId);
  pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
});
canvas.addEventListener('pointermove', e => {
  if (pointers.has(e.pointerId)) { const p = pointers.get(e.pointerId); p.x = e.clientX; p.y = e.clientY; }
});
const drop = e => pointers.delete(e.pointerId);
canvas.addEventListener('pointerup', drop);
canvas.addEventListener('pointercancel', drop);
```

Steering toward the finger is more forgiving than a virtual joystick and needs no art. If the game needs discrete buttons, make them DOM elements (not canvas) so they're accessible and have ≥44px hit areas, and handle `pointerdown` rather than `click` (a 300 ms click delay feels broken).

### Gamepad (optional)

Poll, don't listen: `navigator.getGamepads()[0]` each update, read `axes`/`buttons`, apply a 0.2 deadzone.

## Collisions

Start with the simplest thing that works.

```js
const circlesHit = (a, b) => {
  const dx = a.x - b.x, dy = a.y - b.y, r = a.r + b.r;
  return dx * dx + dy * dy < r * r;             // squared: no sqrt needed
};

const aabbHit = (a, b) =>
  a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
```

For platformers, resolve axes separately (move X, resolve X; move Y, resolve Y) — this prevents the classic "stuck in the wall" corner bug. For fast projectiles, do a swept test or step the bullet in sub-steps, otherwise it tunnels through thin walls.

Above ~200 bodies, use a uniform grid:

```js
const CELL = 96;
function buildGrid(list) {
  const grid = new Map();
  for (const e of list) {
    const k = ((e.x / CELL) | 0) + ',' + ((e.y / CELL) | 0);
    (grid.get(k) ?? grid.set(k, []).get(k)).push(e);
  }
  return grid;
}
// then compare only against neighbours in the 3x3 cells around each entity
```

## Pooling (no per-frame allocation)

```js
function Pool(n, make) {
  const items = Array.from({ length: n }, make);
  return {
    items,
    spawn(fn) { const it = items.find(i => i.life <= 0); if (it) fn(it); },
  };
}
```

`Array.prototype.find` over 400 items is fine; a free-list index is faster if you push past a few thousand. Never `new Vector()` in `update`.

## Persistence

`localStorage` throws in private mode and when full — always wrap it:

```js
const store = {
  get(key, fallback) { try { const v = localStorage.getItem(key); return v === null ? fallback : JSON.parse(v); } catch { return fallback; } },
  set(key, value)  { try { localStorage.setItem(key, JSON.stringify(value)); } catch {} },
};
```

Store keys namespaced (`"myslug.best"`). For bigger saves, `JSON.stringify` the whole state object once on `visibilitychange`. Never store a save on every frame.

## Audio without assets

WebAudio synthesis covers most arcade needs and keeps the game a single file:

```js
let ac, master;
let muted = store.get('game.muted', false);

function initAudio() {                       // MUST run inside a user gesture
  if (ac) return;
  ac = new (window.AudioContext || window.webkitAudioContext)();
  master = ac.createGain();
  master.gain.value = muted ? 0 : 0.22;
  master.connect(ac.destination);
}

function tone(freq, dur = 0.08, type = 'square', gain = 0.5, slideTo = 0) {
  if (!ac || muted) return;
  const t0 = ac.currentTime;
  const o = ac.createOscillator(), g = ac.createGain();
  o.type = type;
  o.frequency.setValueAtTime(freq, t0);
  if (slideTo) o.frequency.exponentialRampToValueAtTime(slideTo, t0 + dur);
  g.gain.setValueAtTime(0.0001, t0);
  g.gain.exponentialRampToValueAtTime(gain, t0 + 0.008);
  g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
  o.connect(g); g.connect(master);
  o.start(t0); o.stop(t0 + dur + 0.02);
}
```

Pitfalls: creating an `AudioContext` before a gesture leaves it `suspended` (call `ac.resume()` on the first input too); `exponentialRampToValueAtTime` cannot take 0; more than ~20 simultaneous voices gets muddy — throttle per-sound with a cooldown.

## Rendering cost

- Cache static backgrounds (grid, stars, gradients) into an offscreen canvas and `drawImage` it once per frame.
- Avoid `shadowBlur` and `ctx.filter` in the loop — they're single-digit-millisecond costs per draw on some GPUs.
- Batch same-color shapes: set `fillStyle` once, then loop `fillRect`/`path()`, one `fill()`.
- Draw squares instead of arcs for particles.
- Text: setting `ctx.font` every frame is fine; `measureText` in a loop is not.
- At most a couple of full-screen composites per frame.

Perf check:

```js
let frames = 0, t = performance.now();
// inside frame():
if (++frames % 120 === 0) {
  console.log('fps', (frames / ((performance.now() - t) / 1000)).toFixed(1));
  t = performance.now(); frames = 0;
}
```

## DOM games vs canvas

Canvas is the default for action games. Use DOM when the game *is* UI: card games, word puzzles, idle/clickers, board games, anything where text and tap targets dominate. Then animate only `transform` and `opacity` (compositor-friendly), use CSS transitions for 120–180 ms pops, and never read layout (`offsetWidth`) inside a loop.

## Libraries (only when they pay)

| Need | Reach for |
|---|---|
| Sprites, tilemaps, atlases, scenes | Phaser 3 |
| Fast 2D renderer, custom loop | PixiJS |
| Real 3D | Three.js (then Babylon if you need physics/editor) |
| Rigid-body physics as the game | matter.js (2D), Rapier (2D/3D, WASM) |
| Sound effects/music files | howler.js |
| Byte-size jam constraint (≤13 KB) | vanilla + a tiny helper, no libraries |

Adding a library is fine when the user asked for it or the feature is the heart of the game. Adding a bundler just to import one library is not — load it from a local vendored `vendor/` file or an ESM CDN and keep it simple.

## Shipping

- A single `index.html` can be opened by double-click, emailed, and hosted anywhere.
- For a real deployment, static files behind any web server is enough; no server code is needed for a single-player game.
- If there's a build step, commit the built output there too — a jam game should never depend on `npm install` to play.
- Add `<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">` and test at 360×640.
- Keep a short controls line on screen and in the page `<title>`/description.
- Respect `prefers-reduced-motion` for shake and flashes; that's an accessibility requirement, not a nicety.
