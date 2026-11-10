# Lighting, atmosphere and materials

## Why lighting first

Lighting changes the perceived quality of every asset in the scene at zero modelling cost. Two places with identical geometry can look like a 2012 obby or a showcase, and the difference is almost entirely `Lighting`. So: geometry pass, then lighting pass, then judge the whole build. Doing it in the other order means you detail things the lighting will never show.

## Set the mode

- **`Lighting.LightingStyle = Enum.LightingStyle.Realistic`** on current Studio. `Soft` is the deliberately flat, retro look — fine as a style choice, wrong as a default. Realistic gives local lights real shadows and materials real specular.
- On older places the equivalent is **`Lighting.Technology = Enum.Technology.Future`** (per-light shadows, reflections). `ShadowMap` is a cheaper middle ground; `Voxel` is the cheap blocky fallback.
- This is a capability-gated, build-time property and writing it from a script can fail with a `RobloxScript` capability error. If it errors: set it in the Properties panel, tell the user in one line, and continue. Never silently skip it and then wonder why the scene is flat.
- **Cost**: Future/Realistic is noticeably heavier on phones. A large share of Roblox players are on low-end mobile, so test and consider `ShadowMap` for big outdoor maps with many players.

## Core properties

| Property | Daylight range | What it does |
|---|---|---|
| `ClockTime` | 6–18 (17.4 = golden hour) | Sun angle; the fastest way to change mood |
| `Brightness` | 2–3 | Sun intensity; >4 blows out highlights |
| `Ambient` | RGB 20–70, tinted | Shadow fill. Pure black kills all readability |
| `OutdoorAmbient` | RGB 60–120 | Fill for outdoor shadows; keep it tinted by sky color |
| `ExposureCompensation` | −0.3–0.3 | Global exposure; tiny values only |
| `EnvironmentDiffuseScale` | 0.3–0.6 | How much sky light fills shadows |
| `EnvironmentSpecularScale` | 0.3–0.7 | Sky reflections on smooth surfaces |
| `ShadowSoftness` | 0.2–0.5 | Blur (Realistic only) |
| `GlobalShadows` | true | Non-negotiable outside of stylized looks |
| `GeographicLatitude` | 20–40 | Sun color/angle character |

Then the effects, each with **one job**:

```lua
local Lighting = game:GetService("Lighting")

local atm = Instance.new("Atmosphere")
atm.Density = 0.34          -- 0.2-0.4: how much air is in the scene
atm.Offset = 0.15           -- low = distant things merge into sky, high = crisp horizon
atm.Haze = 1.4              -- 0.5-2: glow around the sun
atm.Color = Color3.fromRGB(214, 168, 128)   -- the average tint of your scene
atm.Decay = Color3.fromRGB(106, 112, 125)
atm.Glare = 0.2
atm.Parent = Lighting

local bloom = Instance.new("BloomEffect")     -- only genuinely bright pixels
bloom.Intensity = 0.45
bloom.Size = 26
bloom.Threshold = 0.95
bloom.Parent = Lighting

local cc = Instance.new("ColorCorrectionEffect")  -- contrast, not "make it pop"
cc.Brightness = 0.02
cc.Contrast = 0.12
cc.Saturation = 0.06
cc.TintColor = Color3.fromRGB(255, 246, 235)
cc.Parent = Lighting

local dof = Instance.new("DepthOfFieldEffect")    -- subtle; focus far
dof.FarIntensity = 0.1
dof.FocusDistance = 60
dof.InFocusRadius = 90
dof.Parent = Lighting
```

Atmosphere is the single most under-used property in Roblox building: it's what makes distance *read* as distance. If your map looks flat and toy-like, raise `Density` and lower `Offset` before adding anything else.

## Mood presets (starting points to tune)

| Mood | ClockTime | Brightness | Ambient | Atmosphere | Notes |
|---|---|---|---|---|---|
| Golden hour | 17.4 | 2.4 | warm dark brown | Density 0.32, Haze 1.6, warm color | Long shadows; best default for hero shots |
| Overcast | 13 | 1.2 | grey-blue | Density 0.4, Haze 0.4, desaturated | Flattest light; needs composition to carry it |
| Bright noon | 12 | 3 | neutral | Density 0.2, Haze 0.2 | Harsh; only with strong shadow shapes |
| Interior warm | any | 0.8 | very dark | Density 0.1 (or no Atmosphere) | Local lights do the work |
| Night neon | 0 | 0.4 | deep blue | Density 0.45, Haze 0.8, cool | `Bloom` up, `SunRays` off, emissive signs |
| Storm | 8 | 1.6 | cold grey | Density 0.5, Haze 2, dark blue | Blue-grey `ColorCorrection`, low contrast |

`assets/lighting-presets.luau` applies these completely (including `Sky`, `Atmosphere`, post effects) and is idempotent — re-applying updates rather than duplicating.

## Local light

- `PointLight`: `Range` 8–20, `Brightness` 1–3, `Shadows` on for the few lights near the hero shot. More than ~10 shadowed dynamic lights in view is wasted frame time.
- `SurfaceLight`: `Face` matters (`Front`/`Bottom`), `Angle` 90–120; the workhorse for ceilings, signs, and shop windows.
- `SpotLight`: `Angle` 30–60, `Range` 20–40 for cones, street lamps, theatrical beams.
- Warm interior light (RGB 255, 190, 130) + cool exterior fill (RGB 150, 190, 255) is the classic complementary pair that makes interiors feel deep.
- Emissive: `Neon` material or `Material = Neon` + `Color` reads as "light source" and is cheap. Use for signage, screens, lamps — not for whole floors.

## Materials and texture craft

- **Pick materials for meaning**, then stay consistent: `WoodPlanks` structure, `Concrete` civic, `Metal`/`CorrugatedMetal` industrial, `Brick` old-town, `Slate`/`Cobblestone` ground, `Fabric` soft.
- Built-in materials are PBR already: they have metalness/roughness and respond to lighting. Large flat `SmoothPlastic` surfaces are the reason builds look like placeholder geometry — give them a material, or a `SurfaceAppearance`.
- **Texture scale is the most common amateur tell.** A brick texture stretched across a 40-stud wall reads as a smeared blur. Split big walls into panels sized to the texture (4–8 studs per brick tile, 8–16 for stone/concrete), or use a smaller part with a correctly scaled texture and hide the seam with trim.
- `SurfaceAppearance` (PBR: Albedo, Normal, Roughness, Metalness; 1024×1024 is usually enough) **only works on `MeshPart`s**. `MaterialVariant` applies PBR to regular `Part`s.
- Normal maps need tangents — very low-poly meshes can show normal artefacts; prefer flatter normal influence or fewer normal-mapped surfaces.
- Glass: `Glass` material with `Transparency` 0.5–0.8, and keep glass **flush or recessed**; floating panes read as errors. Avoid stacking transparent surfaces — overdraw is expensive and it looks muddy.
- Decals/textures: `Texture` with `StudsPerTileU/V` aligned to the object; `Decal` for labels and posters (small, deliberate, rotated slightly off-axis so walls look used).
- Trim, edging and bevels in a different material from the wall do more for realism than any texture: a 0.25-stud lip catches a highlight and defines the corner.

## A cheap, reliable look

If the user wants "good" without an art budget:

1. Realistic lighting, golden hour or overcast.
2. Atmosphere with density 0.3 and a mid-tone color sampled from the build.
3. Four materials total, each used consistently.
4. Two accent lights on the hero shot (one warm, one cool).
5. Trim on every opening and every roof edge.
6. A ground material that is *not* Plastic, and no pure grey anywhere.

That combination looks intentional in almost any genre, which is the actual goal.
