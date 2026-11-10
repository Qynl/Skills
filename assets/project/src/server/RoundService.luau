--!strict
-- RoundService — intermission -> playing -> results, broadcast to clients.
--
-- The server owns the phase and the clock. Clients only render what they're
-- told. Runs on ONE task at startup; the loop exits cleanly when the server
-- empties, so a dead lobby doesn't keep a thread spinning forever.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

type Phase = "Intermission" | "Playing" | "Results"

type State = {
	phase: Phase,
	timeLeft: number,
}

-- Minimal signal so other services can react without BindableEvents.
local function newSignal()
	local handlers: { (...any) -> () } = {}
	local signal = {}
	function signal.connect(fn: (...any) -> ())
		table.insert(handlers, fn)
		return function()
			local index = table.find(handlers, fn)
			if index then
				table.remove(handlers, index)
			end
		end
	end
	function signal.fire(...: any)
		for _, fn in ipairs(handlers) do
			task.spawn(fn, ...)
		end
	end
	return signal
end

local RoundService = {}

RoundService.RoundEnded = newSignal()

local state: State = { phase = "Intermission", timeLeft = Config.IntermissionSeconds }
local roundRemote: RemoteEvent? = nil
local running = false

local function broadcast()
	local remote = roundRemote
	if not remote then
		return
	end
	remote:FireAllClients({ phase = state.phase, timeLeft = state.timeLeft })
end

local function setPhase(phase: Phase, seconds: number)
	state.phase = phase
	state.timeLeft = seconds
	broadcast()
end

local function countDown(seconds: number): boolean
	local remaining = seconds
	while remaining > 0 do
		task.wait(1)
		if #Players:GetPlayers() == 0 then
			return false -- empty server: abort the round rather than running it alone
		end
		remaining -= 1
		state.timeLeft = remaining
		broadcast()
	end
	return true
end

-- Replace this with your win condition. Returns the winning players.
local function scoreRound(): { Player }
	local players = Players:GetPlayers()
	if #players == 0 then
		return {}
	end
	-- Example: everyone who is still alive wins; otherwise the first player.
	return players
end

local function award(winners: { Player })
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = require(script.Parent.DataService)
		profile.addCoins(player, Config.ParticipationReward)
	end
	for _, winner in ipairs(winners) do
		local profile = require(script.Parent.DataService)
		profile.addCoins(winner, Config.WinReward)
		profile.addWin(winner)
	end
end

local function loop()
	while running do
		-- Wait for enough players before starting a round.
		while #Players:GetPlayers() < Config.MinPlayersToStart and running do
			setPhase("Intermission", Config.IntermissionSeconds)
			task.wait(1)
		end
		if not running then
			return
		end

		setPhase("Intermission", Config.IntermissionSeconds)
		if not countDown(Config.IntermissionSeconds) then
			continue
		end

		setPhase("Playing", Config.RoundSeconds)
		if not countDown(Config.RoundSeconds) then
			continue
		end

		local winners = scoreRound()
		award(winners)
		setPhase("Results", Config.ResultsSeconds)
		RoundService.RoundEnded.fire(winners)
		task.wait(Config.ResultsSeconds)
	end
end

function RoundService.start(remotes: { [string]: Instance }): ()
	assert(not running, "RoundService.start() called twice")
	local remote = remotes.RoundState
	if not remote or not remote:IsA("RemoteEvent") then
		error("RoundService.start requires the RoundState RemoteEvent")
	end
	roundRemote = remote
	running = true
	task.spawn(loop)
end

function RoundService.stop(): ()
	running = false
end

function RoundService.getState(): State
	return { phase = state.phase, timeLeft = state.timeLeft }
end

return RoundService
