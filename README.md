# Skills

One skill per branch. Each branch holds a single, self-contained skill at the repo root (`SKILL.md` + `references/` + `assets/`), so checking out that branch gives you exactly that skill and nothing else.

| Branch | Skill | What it does |
|---|---|---|
| `WebgameSkill` | `webgame` | Builds genuinely fun, polished browser games — game feel, pacing, input, audio, performance, and verification. Ships a working starter game. |
| `RobloxBuildSkill` | `roblox-build` | Builds and polishes beautiful Roblox environments in Studio through the Studio MCP server — blockout, kit, lighting, composition, set dressing, performance, visual verification. Ships build helpers, lighting presets and a style-bible template. |
| `RobloxGameDevSkill` | `roblox-game-dev` | Builds Roblox gameplay: server-authoritative architecture, Luau patterns, remotes, DataStores, economy, UI, monetization, testing and shipping. Ships a Rojo starter project. |

## Using a skill

Copy the branch's contents into your skills directory:

```bash
git clone --branch RobloxGameDevSkill --single-branch <repo-url> roblox-game-dev
cp -R roblox-game-dev/* ~/.claude/skills/roblox-game-dev/    # or your agent's skills folder
```

The folder name and the `name:` field in `SKILL.md` must match (`roblox-game-dev`).

## Adding a new skill

```bash
git checkout main
git checkout -b MySkillName        # one branch per skill, named after the skill
# write SKILL.md, references/, assets/, evals/
git add -A && git commit -m "Add MySkillName skill"
git push -u origin MySkillName
```
