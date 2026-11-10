# Genre recipes

Each recipe gives: the core verb, the loop, what to polish first, starting numbers, and the failure mode that makes these games boring. Copy the numbers, then tune by feel — they're calibrated for a ~1000-unit-wide arena at 60fps.

## Choosing a genre

Pick by what the user asked for, and if they didn't say, pick by these rules:

- Want it playable in 5 minutes and fun in 30 seconds → **arcade / endless**.
- Want depth and replayability → **roguelike-lite** or **tower defense**.
- Want a chill toy or something to leave running → **idle/clicker** or **sandbox**.
- Want to show off a mechanic → **puzzle**.
- Landing page embed → arcade, one-screen, die-and-retry, with a "play" that starts instantly.

Avoid open-world, RPG-with-story, or multiplayer as a first build in a single HTML file. They need content or servers, not polish.

---

## Arcade: dodge & collect / arena survivor

- **Verb**: move (and optionally shoot). **Loop**: avoid threats, collect rewards, survive as score climbs.
- **Polish first**: the hit reaction (particles + hitstop + shake), the pickup chime and combo pulse, the spawn telegraph.
- **Numbers**: player accel 2600, max 430, radius 14. Enemy speed 78–120 and scaling +4%/min. Spawn every 1.6 s, −0.05 s per 10 points, floor 0.45 s. 3 lives, 1.2 s invulnerability, blink at 8 Hz.
- **Failure mode**: threats that spawn on the player or drift in off-screen. Always spawn outside the view and telegraph entry.

## Arcade shooter / bullet-hell lite

- **Verb**: aim/shoot while dodging. **Loop**: clear waves, chain kills, survive patterns.
- **Polish first**: muzzle flash + recoil, bullet impact hitstop, enemy death burst, screen-edge warning before a dense pattern.
- **Numbers**: player speed 300. Bullet speed 700–900, cooldown 0.12 s, spread ±0.02 rad. Enemy bullets 180–260 (readable, not fast). Fire-rate power-up 20% per pickup, cap +80%.
- **Readability rule**: player bullets one hue (cyan/yellow), enemy bullets another (magenta/red), and use shape too — circles for the player, diamonds for danger.
- **Failure mode**: bullets too fast to read. If you can't dodge by watching, lower speed before adding enemies.

## Platformer

- **Verb**: jump (then dash, wall-jump, shoot). **Loop**: traverse, collect, reach the goal without dying.
- **Polish first**: the jump arc itself — coyote time (100 ms), input buffer (120 ms), variable height, landing squash, dust puff on landing and takeoff.
- **Numbers**: 64px character, jump 620, gravity 2100 (falling 1.3×), run 320 with 0.1 s to speed, air control 65%, max fall 1400.
- **Level design**: teach a mechanic in a safe room, test it with a risk, then combine it. One screen ≈ one idea.
- **Failure mode**: bottomless pits with no visible edge, or levels that need pixel-perfect inputs. Checkpoints for anything longer than ~60 s.

## Endless runner

- **Verb**: one-button jump (or lane switch). **Loop**: distance as score, speed ramps, near-miss bonus.
- **Polish first**: the landing and the near-miss. Near-miss = slow-mo 0.85× for 150 ms + a "+5 close!" popup. That's what makes it addictive.
- **Numbers**: start speed 300, +8/s up to 900. Gap between obstacles ≥ `speed * 0.55` so it's always physically clearable. Gravity 2600, jump 780 for a snappy one-button feel.
- **Failure mode**: obstacles generated without regard to jump distance. Derive gaps from the jump arc, never from random pixels.

## Roguelike-lite (survivors style)

- **Verb**: move + auto-attack. **Loop**: 5-minute run, kill for XP, pick one of three upgrades every level.
- **Polish first**: the level-up choice (pause the world, cards pop with `easeOutBack`) and the crowd of enemies dying in bursts.
- **Numbers**: XP curve `need = 8 + level * 6`. 3 upgrade choices from a pool of ~10 with real tradeoffs (damage vs area vs speed). Enemy count cap ~150 with a spatial grid.
- **Failure mode**: upgrades that are strictly better (+5% damage three times). Every card should change how the game is played, not just its numbers.

## Tower defense

- **Verb**: place towers on a path. **Loop**: build, survive a wave, upgrade, repeat.
- **Polish first**: placement feedback (grid snap, range preview ring, invalid-placement red), projectile impact, wave-start banner and countdown.
- **Numbers**: wave 1 = 6 enemies at 60 hp, +12% hp and +1 enemy per wave. Starting gold 150, tower cost 50, kill reward 5–12. Placements on a grid of 40–48px.
- **Failure mode**: the optimal strategy is one tower type. Give each tower a distinct enemy it counters (fast, armoured, flying, swarm).

## Idle / clicker

- **Verb**: click once, then buy — **the game plays itself while you watch the numbers grow**.
- **Polish first**: the number tween, the satisfying click (scale punch + sound), milestone bursts ("1000/s!") and the moment a new tier unlocks.
- **Numbers**: cost growth 1.15× per level; income 1.05–1.2× so progress accelerates; first prestige at ~10 minutes of play. Offline earnings capped at 8 h.
- **Failure mode**: waiting with nothing to click. Always leave an active lever (a manual boost with a cooldown) so idle is a choice, not a wall.

## Puzzle (match-3, merge, sokoban, 2048-like)

- **Verb**: place / swap / push. **Loop**: constrained moves, a board state that resolves, a visible goal.
- **Polish first**: the transition — tiles sliding with `easeOutCubic` over 120 ms, pops bursting, a satisfying cascade, and *undo*.
- **Numbers**: animation 120–180 ms per move, never over 250 ms or it feels like molasses. Board 6×6 to 8×8 for match games; 5×5 for merge.
- **Failure mode**: no feedback that a move was illegal. Shake the tile 6px and play a dull thud — that's the whole UX.

## Physics sandbox / toy

- **Verb**: spawn and throw. **Loop**: no fail state, just play and discover.
- **Polish first**: contacts (dust, sound with pitch by impact speed), trails for fast objects, and a "clear" button. Camera zoom-out as the pile grows.
- **Numbers**: gravity 1400, restitution 0.35–0.55, friction 0.02/0.1, max 250 bodies.
- **Failure mode**: no goal at all. Add a soft objective (stack 5, keep the ball alive 10 s) so players have a reason to stay 30 more seconds.

## Card / deckbuilder

- **Verb**: play a card. **Loop**: spend energy, manage a hand, resolve enemies, pick a new card.
- **Polish first**: the card leaving the hand (lift, tilt, fly to the target), the damage number, the shuffle sound.
- **Numbers**: hand 5, energy 3, deck 12–15 cards, 2–3 enemies per fight, fights 4–8 turns.
- **Failure mode**: cards that are unreadable at a glance. Art + big cost number + one-line rule text, max.

## Rhythm / reflex

- **Verb**: hit on the beat. **Loop**: notes approach, timing windows score you, a combo builds.
- **Polish first**: latency calibration, hit windows, and a combo meter that shakes on a miss.
- **Numbers**: perfect ±45 ms, good ±90 ms, miss beyond ±140 ms. Notes approach over 1.5–2 s.
- **Failure mode**: uncalibrated audio latency makes it feel broken. Offer an offset slider and offset your note times by it.

---

## Universal tuning table

| Thing | Comfortable range |
|---|---|
| Time to max speed (player) | 0.10–0.20 s |
| Jump arc (platformer) | 0.55–0.75 s airtime |
| Hitstop | 40–120 ms |
| Camera follow smoothing | `1 - exp(-6*dt)` |
| Pickup/increment animation | 120–180 ms |
| Enemy telegraph | 300–500 ms |
| Death → retry | < 1 s |
| First win for a new player | < 10 s |
| Screen shake | ≤ 3% of the short side |
| Text on screen at once | 1 line (plus HUD) |
