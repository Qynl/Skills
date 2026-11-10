--!strict
-- Client entry point: build the HUD once, then mutate it from state.
-- Never trust this file for authority — it only displays and sends intent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RoundState = Remotes.get("RoundState") :: RemoteEvent
local PlayerDataChanged = Remotes.get("PlayerDataChanged") :: RemoteEvent
local ShopPurchase = Remotes.get("ShopPurchase") :: RemoteFunction

-- ------------------------------------------------------------------ UI kit

local function make(className: string, props: { [string]: any }, parent: Instance?): Instance
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		(instance :: any)[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local gui = make("ScreenGui", {
	Name = "GameHud",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui) :: ScreenGui

-- Top bar: coins + round phase/timer. Scale-based so it survives phones.
local topBar = make("Frame", {
	Name = "TopBar",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.02),
	Size = UDim2.fromScale(0.5, 0.07),
	BackgroundColor3 = Color3.fromRGB(16, 18, 26),
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
}, gui) :: Frame
make("UICorner", { CornerRadius = UDim.new(0, 10) }, topBar)
make("UIStroke", { Color = Color3.fromRGB(80, 96, 130), Thickness = 1, Transparency = 0.4 }, topBar)

local coinLabel = make("TextLabel", {
	Name = "Coins",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.fromScale(0.04, 0.5),
	Size = UDim2.fromScale(0.4, 0.6),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextColor3 = Color3.fromRGB(255, 214, 102),
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "0 coins",
}, topBar) :: TextLabel

local phaseLabel = make("TextLabel", {
	Name = "Phase",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.fromScale(0.96, 0.5),
	Size = UDim2.fromScale(0.5, 0.6),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextColor3 = Color3.fromRGB(214, 226, 255),
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Right,
	Text = "Intermission 0s",
}, topBar) :: TextLabel

-- Shop button (bottom right), big enough for a thumb.
local shopButton = make("TextButton", {
	Name = "ShopButton",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.fromScale(0.96, 0.94),
	Size = UDim2.fromScale(0.22, 0.09),
	BackgroundColor3 = Color3.fromRGB(88, 196, 255),
	TextColor3 = Color3.fromRGB(8, 14, 22),
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	Text = "SHOP",
	AutoButtonColor = true,
}, gui) :: TextButton
make("UICorner", { CornerRadius = UDim.new(0, 8) }, shopButton)
make("UIAspectRatioConstraint", { AspectRatio = 3.2, DominantAxis = Enum.DominantAxis.Width }, shopButton)

-- Shop panel, hidden by default.
local panel = make("Frame", {
	Name = "ShopPanel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.34, 0.5),
	BackgroundColor3 = Color3.fromRGB(18, 20, 30),
	Visible = false,
}, gui) :: Frame
make("UICorner", { CornerRadius = UDim.new(0, 12) }, panel)
make("UIStroke", { Color = Color3.fromRGB(96, 112, 150), Thickness = 1 }, panel)

local panelTitle = make("TextLabel", {
	Size = UDim2.fromScale(1, 0.12),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextColor3 = Color3.fromRGB(236, 242, 255),
	TextScaled = true,
	Text = "SHOP",
}, panel) :: TextLabel

local list = make("Frame", {
	Position = UDim2.fromScale(0.04, 0.14),
	Size = UDim2.fromScale(0.92, 0.7),
	BackgroundTransparency = 1,
}, panel) :: Frame
make("UIListLayout", {
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, list)

local statusLabel = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 0.98),
	Size = UDim2.fromScale(0.9, 0.12),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextColor3 = Color3.fromRGB(160, 176, 208),
	TextScaled = true,
	Text = "",
}, panel) :: TextLabel

-- ------------------------------------------------------------------ state

local state = {
	coins = 0,
	phase = "Intermission",
	timeLeft = 0,
}

local function renderCoins()
	coinLabel.Text = ("%d coins"):format(state.coins)
end

local function renderPhase()
	phaseLabel.Text = ("%s  %ds"):format(state.phase, math.max(0, state.timeLeft))
end

-- ------------------------------------------------------------------ shop

local function buildShop()
	for _, item in ipairs(Config.Shop) do
		local row = make("TextButton", {
			Size = UDim2.fromScale(1, 0.28),
			BackgroundColor3 = Color3.fromRGB(32, 36, 50),
			Text = "",
			AutoButtonColor = true,
			LayoutOrder = item.price,
		}, list) :: TextButton
		make("UICorner", { CornerRadius = UDim.new(0, 8) }, row)

		make("TextLabel", {
			Position = UDim2.fromScale(0.04, 0.1),
			Size = UDim2.fromScale(0.66, 0.4),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextColor3 = Color3.fromRGB(236, 242, 255),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = item.name,
		}, row)

		make("TextLabel", {
			Position = UDim2.fromScale(0.04, 0.52),
			Size = UDim2.fromScale(0.66, 0.34),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextColor3 = Color3.fromRGB(158, 176, 208),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = item.description,
		}, row)

		make("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(0.96, 0.5),
			Size = UDim2.fromScale(0.26, 0.5),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			TextColor3 = Color3.fromRGB(255, 214, 102),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = ("%d"):format(item.price),
		}, row)

		row.Activated:Connect(function()
			statusLabel.Text = "Buying " .. item.name .. "…"
			local ok, message = ShopPurchase:InvokeServer(item.id)
			statusLabel.Text = message or (if ok then "Purchased." else "Failed.")
			if not ok then
				-- small shake on rejection: cheap feedback beats a silent no
				local original = panel.Position
				TweenService:Create(panel, TweenInfo.new(0.05), { Position = original + UDim2.fromScale(0.01, 0) }):Play()
				task.delay(0.08, function()
					TweenService:Create(panel, TweenInfo.new(0.05), { Position = original }):Play()
				end)
			end
		end)
	end
end

buildShop()
renderCoins()
renderPhase()

shopButton.Activated:Connect(function()
	panel.Visible = not panel.Visible
	if panel.Visible then
		statusLabel.Text = ""
	end
end)

-- ------------------------------------------------------------------ network

RoundState.OnClientEvent:Connect(function(newState: any)
	if type(newState) ~= "table" then
		return
	end
	state.phase = tostring(newState.phase or state.phase)
	state.timeLeft = tonumber(newState.timeLeft) or state.timeLeft
	renderPhase()
end)

PlayerDataChanged.OnClientEvent:Connect(function(payload: any)
	if type(payload) == "table" and type(payload.coins) == "number" then
		state.coins = payload.coins
		renderCoins()
	end
end)

-- Late joiners missed the broadcast: ask for the current state once.
task.spawn(function()
	local request = ReplicatedStorage:FindFirstChild("Remotes")
	if request then
		-- RoundService broadcasts every second, so within 1s we're in sync.
		task.wait(1.5)
		renderPhase()
	end
end)
