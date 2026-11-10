# Skills

One skill per branch. Each branch holds a single, self-contained skill at the repo root (`SKILL.md` + `references/` + `assets/`), so checking out that branch gives you exactly that skill and nothing else.

| Branch | Skill | What it does |
|---|---|---|
| `WebgameSkill` | `webgame` | Builds genuinely fun, polished browser games — game feel, pacing, input, audio, performance, and verification. Ships a working starter game. |

## Using a skill

Copy the branch's contents into your skills directory:

```bash
git clone --branch WebgameSkill --single-branch <repo-url> webgame-skill
cp -R webgame-skill/* ~/.claude/skills/webgame/    # or your agent's skills folder
```

The folder name and the `name:` field in `SKILL.md` must match (`webgame`).

## Adding a new skill

```bash
git checkout main
git checkout -b MySkillName        # one branch per skill, named after the skill
# write SKILL.md, references/, assets/, evals/
git add -A && git commit -m "Add MySkillName skill"
git push -u origin MySkillName
```
