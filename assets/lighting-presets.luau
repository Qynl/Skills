--!nolint
--!nocheck
--[[
	lighting-presets.luau — complete, idempotent lighting presets.

	Usage (Edit mode, via execute_luau). Either paste the whole file in, or install
	it as a ModuleScript next to build-utils and require it:

		local LightingPresets = require(game.ServerStorage.AgentTools.LightingPresets)
		LightingPresets.apply("goldenHour")
		print(LightingPresets.summary())

	Re-applying a preset updates the existing Atmosphere/effects instead of
	stacking duplicates, so it's safe to tweak and re-run.

	IMPORTANT: Lighting.Technology / LightingStyle are capability-gated in some
	Studio versions. This file attempts them under pcall and reports what worked —
	if it fails, set the property in the Properties panel (it's a build-time
	decision, not a runtime one).
]]

local Lighting = game:GetService("Lighting")

local PRESETS = {
	goldenHour = {
		ambience = "warm, low sun, long shadows",
		props = {
			ClockTime = 17.4,
			Brightness = 2.4,
			Ambient = Color3.fromRGB(58, 46, 39),
			OutdoorAmbient = Color3.fromRGB(107, 92, 84),
			ExposureCompensation = 0.15,
			EnvironmentDiffuseScale = 0.35,
			EnvironmentSpecularScale = 0.55,
			ShadowSoftness = 0.35,
			GlobalShadows = true,
			GeographicLatitude = 25,
		},
		atmosphere = { Density = 0.32, Offset = 0.15, Haze = 1.6, Glare = 0.25, Color = Color3.fromRGB(214, 168, 128), Decay = Color3.fromRGB(106, 112, 125) },
		effects = {
			BloomEffect = { Intensity = 0.45, Size = 26, Threshold = 0.95 },
			ColorCorrectionEffect = { Brightness = 0.02, Contrast = 0.12, Saturation = 0.08, TintColor = Color3.fromRGB(255, 246, 235) },
			SunRaysEffect = { Intensity = 0.12, Spread = 0.6 },
			DepthOfFieldEffect = { FarIntensity = 0.1, FocusDistance = 60, InFocusRadius = 90, NearIntensity = 0.05 },
		},
	},
	overcast = {
		ambience = "soft grey sky, flattest light, needs composition to carry it",
		props = {
			ClockTime = 13,
			Brightness = 1.2,
			Ambient = Color3.fromRGB(72, 76, 84),
			OutdoorAmbient = Color3.fromRGB(124, 130, 140),
			ExposureCompensation = 0,
			EnvironmentDiffuseScale = 0.5,
			EnvironmentSpecularScale = 0.3,
			ShadowSoftness = 0.6,
			GlobalShadows = true,
			GeographicLatitude = 45,
		},
		atmosphere = { Density = 0.4, Offset = 0.1, Haze = 0.4, Glare = 0, Color = Color3.fromRGB(178, 186, 198), Decay = Color3.fromRGB(96, 104, 116) },
		effects = {
			BloomEffect = { Intensity = 0.2, Size = 20, Threshold = 1 },
			ColorCorrectionEffect = { Brightness = 0, Contrast = 0.06, Saturation = -0.05, TintColor = Color3.fromRGB(236, 240, 245) },
			DepthOfFieldEffect = { FarIntensity = 0.08, FocusDistance = 70, InFocusRadius = 110, NearIntensity = 0.04 },
		},
	},
	interiorWarm = {
		ambience = "indoors, local lights do the work, dark neutral fill",
		props = {
			ClockTime = 15,
			Brightness = 0.8,
			Ambient = Color3.fromRGB(24, 21, 19),
			OutdoorAmbient = Color3.fromRGB(46, 40, 36),
			ExposureCompensation = 0.1,
			EnvironmentDiffuseScale = 0.2,
			EnvironmentSpecularScale = 0.4,
			ShadowSoftness = 0.2,
			GlobalShadows = true,
		},
		atmosphere = { Density = 0.08, Offset = 0.25, Haze = 0.2, Glare = 0, Color = Color3.fromRGB(198, 180, 160), Decay = Color3.fromRGB(70, 62, 56) },
		effects = {
			BloomEffect = { Intensity = 0.35, Size = 22, Threshold = 0.9 },
			ColorCorrectionEffect = { Brightness = 0, Contrast = 0.1, Saturation = 0.04, TintColor = Color3.fromRGB(255, 244, 228) },
			DepthOfFieldEffect = { FarIntensity = 0.12, FocusDistance = 30, InFocusRadius = 50, NearIntensity = 0.06 },
		},
	},
	nightNeon = {
		ambience = "night, cool ambient, emissive signs bloom",
		props = {
			ClockTime = 0,
			Brightness = 0.4,
			Ambient = Color3.fromRGB(18, 20, 34),
			OutdoorAmbient = Color3.fromRGB(40, 46, 70),
			ExposureCompensation = 0.2,
			EnvironmentDiffuseScale = 0.25,
			EnvironmentSpecularScale = 0.7,
			ShadowSoftness = 0.25,
			GlobalShadows = true,
		},
		atmosphere = { Density = 0.45, Offset = 0.2, Haze = 0.8, Glare = 0.3, Color = Color3.fromRGB(72, 96, 148), Decay = Color3.fromRGB(24, 26, 44) },
		effects = {
			BloomEffect = { Intensity = 1.1, Size = 30, Threshold = 0.75 },
			ColorCorrectionEffect = { Brightness = -0.02, Contrast = 0.18, Saturation = 0.1, TintColor = Color3.fromRGB(226, 236, 255) },
			DepthOfFieldEffect = { FarIntensity = 0.1, FocusDistance = 55, InFocusRadius = 80, NearIntensity = 0.05 },
			SunRaysEffect = { Intensity = 0.05, Spread = 0.4 },
		},
	},
	storm = {
		ambience = "cold blue-grey, heavy haze, low contrast",
		props = {
			ClockTime = 8,
			Brightness = 1.6,
			Ambient = Color3.fromRGB(52, 58, 66),
			OutdoorAmbient = Color3.fromRGB(96, 104, 116),
			ExposureCompensation = 0.05,
			EnvironmentDiffuseScale = 0.4,
			EnvironmentSpecularScale = 0.35,
			ShadowSoftness = 0.7,
			GlobalShadows = true,
			GeographicLatitude = 55,
		},
		atmosphere = { Density = 0.5, Offset = 0.08, Haze = 2, Glare = 0.1, Color = Color3.fromRGB(112, 124, 140), Decay = Color3.fromRGB(64, 72, 84) },
		effects = {
			BloomEffect = { Intensity = 0.25, Size = 24, Threshold = 1 },
			ColorCorrectionEffect = { Brightness = -0.02, Contrast = 0.04, Saturation = -0.12, TintColor = Color3.fromRGB(224, 232, 244) },
			DepthOfFieldEffect = { FarIntensity = 0.16, FocusDistance = 45, InFocusRadius = 70, NearIntensity = 0.06 },
		},
	},
}

local function findEffect(className: string, name: string): Instance
	for _, child in ipairs(Lighting:GetChildren()) do
		if child.ClassName == className and child.Name == name then
			return child
		end
	end
	for _, child in ipairs(Lighting:GetChildren()) do
		if child.ClassName == className then
			return child
		end
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = Lighting
	return created
end

local function setProps(inst: Instance, props: table)
	for key, value in pairs(props) do
		pcall(function()
			inst[key] = value
		end)
	end
end

local LightingPresets = {}

-- Which lighting mode actually applied (report this to the user).
local lightingMode = "unchanged"

function LightingPresets.apply(presetName: string?): table
	local name = presetName or "goldenHour"
	local preset = PRESETS[name]
	if not preset then
		error(("unknown preset %q; available: %s"):format(name, table.concat((function()
			local keys = {}
			for k in pairs(PRESETS) do
				table.insert(keys, k)
			end
			table.sort(keys)
			return keys
		end)(), ", ")))
	end

	-- Build-time lighting mode. Capability-gated on some versions; report honestly.
	local okRealistic = pcall(function()
		Lighting.LightingStyle = Enum.LightingStyle.Realistic
	end)
	local okTech = pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	if okRealistic then
		lightingMode = "LightingStyle.Realistic"
	elseif okTech then
		lightingMode = "Technology.Future"
	else
		lightingMode = "UNSET — set Technology/LightingStyle in the Properties panel"
	end

	setProps(Lighting, preset.props)

	local atmosphere = findEffect("Atmosphere", "Atmosphere") :: Atmosphere
	setProps(atmosphere, preset.atmosphere)

	for className, props in pairs(preset.effects) do
		local effect = findEffect(className, className:gsub("Effect$", ""))
		setProps(effect, props)
	end

	-- Remove post effects of the same class that the preset didn't specify? No:
	-- leave user-authored extras alone. Just report.
	print(("[lighting] applied %q (%s) | clock %s | atmosphere density %s"):format(
		name,
		lightingMode,
		tostring(preset.props.ClockTime),
		tostring(preset.atmosphere.Density)
	))
	return preset
end

function LightingPresets.summary(): string
	local effects = {}
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") then
			table.insert(effects, child.ClassName)
		end
	end
	table.sort(effects)
	return ("mode %s | clock %s | ambient %s | effects: %s"):format(
		lightingMode,
		tostring(Lighting.ClockTime),
		tostring(Lighting.Ambient),
		table.concat(effects, ", ")
	)
end

function LightingPresets.names(): { string }
	local keys = {}
	for k in pairs(PRESETS) do
		table.insert(keys, k)
	end
	table.sort(keys)
	return keys
end

return LightingPresets
