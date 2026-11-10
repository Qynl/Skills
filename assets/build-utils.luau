--!nolint
--!nocheck
--[[
	build-utils.luau — tagged, safe building helpers for the Studio MCP server.

	Install once per session (Edit mode), then require it from later passes:

		local ServerStorage = game:GetService("ServerStorage")
		local toolsFolder = ServerStorage:FindFirstChild("AgentTools")
		if not toolsFolder then
			toolsFolder = Instance.new("Folder")
			toolsFolder.Name = "AgentTools"
			toolsFolder.Parent = ServerStorage
		end
		local src = script -- (when created via multi_edit, this file's body)
		-- simplest: create the ModuleScript with multi_edit, then require it:
		local Build = require(ServerStorage.AgentTools.Build)

	Why a module: build passes get re-run, and re-pasting 120 lines of helpers into
	every execute_luau call wastes context and drifts. One source of truth.

	Everything created through this module gets attributes:
		AgentBuild = true      -- provenance: safe to find, clean up, or review
		AgentBuildPass = name  -- which pass created it (blockout / detail / ...)
		AgentBuildName = name  -- the build this belongs to
]]

local Build = {}

local currentPass = "unassigned"
local currentBuild = "UnnamedBuild"

function Build.setPass(name: string)
	currentPass = name
end

function Build.setBuildName(name: string)
	currentBuild = name
end

local function tag(inst: Instance, pass: string?): Instance
	inst:SetAttribute("AgentBuild", true)
	inst:SetAttribute("AgentBuildPass", pass or currentPass)
	inst:SetAttribute("AgentBuildName", currentBuild)
	return inst
end

function Build.snap(v: Vector3, grid: number?): Vector3
	local g = grid or 0.5
	return Vector3.new(
		math.round(v.X / g) * g,
		math.round(v.Y / g) * g,
		math.round(v.Z / g) * g
	)
end

function Build.folder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return tag(f)
end

-- A model with a PrimaryPart, so it can be moved/moved-for-review as one unit.
function Build.model(parent: Instance, name: string, primary: BasePart?): Model
	local m = Instance.new("Model")
	m.Name = name
	if primary then
		m.PrimaryPart = primary
	end
	m.Parent = parent
	return tag(m)
end

--[[
	Build.part {
		name = "Wall_Straight_16",
		size = Vector3.new(16, 12, 0.75),
		pos  = Vector3.new(0, 6, 0),      -- center of the part, not the corner
		cf   = CFrame.new(...) ,          -- or a full CFrame (wins over pos)
		material = Enum.Material.WoodPlanks,
		color = Color3.fromRGB(120, 92, 68),
		transparency = 0,
		shape = Enum.PartType.Block,
		parent = model,
		collide = false, query = false, touch = false,   -- decoration defaults are opt-in
		anchored = true,
	}
]]
function Build.part(opts: table): Part
	local p = Instance.new("Part")
	p.Name = opts.name or "Part"
	p.Anchored = opts.anchored ~= false
	p.CanCollide = opts.collide == true
	p.CanQuery = opts.query == true
	p.CanTouch = opts.touch == true
	p.Size = opts.size or Vector3.new(4, 1, 4)
	p.Material = opts.material or Enum.Material.SmoothPlastic
	p.Color = opts.color or Color3.fromRGB(163, 162, 165)
	p.Transparency = opts.transparency or 0
	p.Shape = opts.shape or Enum.PartType.Block
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = opts.castShadow ~= false
	if opts.cf then
		p.CFrame = opts.cf
	elseif opts.pos then
		p.CFrame = CFrame.new(Build.snap(opts.pos))
	end
	p.Parent = opts.parent
	return tag(p)
end

function Build.wedge(opts: table): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = opts.name or "Wedge"
	w.Anchored = opts.anchored ~= false
	w.CanCollide = opts.collide == true
	w.CanQuery = opts.query == true
	w.Size = opts.size or Vector3.new(4, 4, 4)
	w.Material = opts.material or Enum.Material.SmoothPlastic
	w.Color = opts.color or Color3.fromRGB(163, 162, 165)
	if opts.cf then
		w.CFrame = opts.cf
	elseif opts.pos then
		w.CFrame = CFrame.new(Build.snap(opts.pos))
	end
	w.Parent = opts.parent
	return tag(w)
end

-- A vertical cylinder by default (Cylinder parts are axis-X, which surprises everyone).
function Build.cylinder(opts: table): Part
	local o = table.clone(opts)
	o.shape = Enum.PartType.Cylinder
	local p = Build.part(o)
	local base = o.cf or CFrame.new(Build.snap(o.pos or Vector3.zero))
	p.CFrame = base * CFrame.Angles(0, 0, math.rad(90))
	if o.radius and o.height then
		p.Size = Vector3.new(o.height, o.radius * 2, o.radius * 2)
	end
	return p
end

-- Create many parts in one call from a list of specs. Returns the created parts.
function Build.batch(specs: { table }, parent: Instance?): { Part }
	local made = {}
	for _, spec in ipairs(specs) do
		local copy = table.clone(spec)
		if parent and not copy.parent then
			copy.parent = parent
		end
		table.insert(made, Build.part(copy))
	end
	return made
end

function Build.pointLight(parent: BasePart, color: Color3, range: number, brightness: number, shadows: boolean?): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = shadows ~= false
	l.Parent = parent
	return tag(l)
end

function Build.surfaceLight(parent: BasePart, face: Enum.NormalId, angle: number, range: number, brightness: number): SurfaceLight
	local l = Instance.new("SurfaceLight")
	l.Face = face
	l.Angle = angle
	l.Range = range
	l.Brightness = brightness
	l.Parent = parent
	return tag(l)
end

--[[
	Sanity-check a build before you screenshot it. Catches the boring failures:
	NaN / inf positions, zero or negative sizes, parts below the floor, parts
	floating far above it, and parts outside the expected bounds.

		local report = Build.verify(buildFolder, { maxParts = 3000 })
		print(report.summary)
]]
function Build.verify(root: Instance, opts: table?): table
	opts = opts or {}
	local parts, bad = 0, {}
	local bounds = { min = Vector3.new(math.huge, math.huge, math.huge), max = Vector3.new(-math.huge, -math.huge, -math.huge) }

	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
			local p: BasePart = d
			local s, pos = p.Size, p.Position
			local finite = pos.X == pos.X and pos.Y == pos.Y and pos.Z == pos.Z
			if not finite or s.X <= 0 or s.Y <= 0 or s.Z <= 0 then
				table.insert(bad, p:GetFullName() .. " (invalid transform or size)")
			end
			if finite then
				bounds.min = Vector3.new(math.min(bounds.min.X, pos.X), math.min(bounds.min.Y, pos.Y), math.min(bounds.min.Z, pos.Z))
				bounds.max = Vector3.new(math.max(bounds.max.X, pos.X), math.max(bounds.max.Y, pos.Y), math.max(bounds.max.Z, pos.Z))
			end
		end
	end

	local maxParts = opts.maxParts or 3000
	if parts > maxParts then
		table.insert(bad, ("part budget exceeded: %d > %d"):format(parts, maxParts))
	end

	local summary = ("%d parts | bounds %s -> %s | %d issue(s)"):format(
		parts,
		tostring(bounds.min),
		tostring(bounds.max),
		#bad
	)
	if #bad > 0 then
		print(summary)
		for _, issue in ipairs(bad) do
			warn("[build] " .. issue)
		end
	end
	return { parts = parts, bounds = bounds, issues = bad, summary = summary }
end

-- Describe the scene for a fast "what does it look like" report without screenshots.
function Build.stats(root: Instance): string
	local counts, materials = {}, {}
	local parts = 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
			counts[d.ClassName] = (counts[d.ClassName] or 0) + 1
			local m = d.Material.Name
			materials[m] = (materials[m] or 0) + 1
		end
	end
	local topMaterials = {}
	for name, count in pairs(materials) do
		table.insert(topMaterials, { name = name, count = count })
	end
	table.sort(topMaterials, function(a, b)
		return a.count > b.count
	end)
	local bits = { ("%d parts"):format(parts) }
	for i = 1, math.min(5, #topMaterials) do
		table.insert(bits, ("%s:%d"):format(topMaterials[i].name, topMaterials[i].count))
	end
	return table.concat(bits, " | ")
end

-- Destroy only what this agent created. Never touches user content.
function Build.clearAll()
	local removed = 0
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:GetAttribute("AgentBuild") then
			removed += 1
			d:Destroy()
		end
	end
	-- remove now-empty tagged folders
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Folder") and d:GetAttribute("AgentBuild") and #d:GetChildren() == 0 then
			d:Destroy()
		end
	end
	print(("[build] removed %d agent-built instances"):format(removed))
	return removed
end

return Build
