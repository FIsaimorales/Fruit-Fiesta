--!strict
-- Authoritative roll pedestal logic.
--
-- The species + rarity are decided here, on the server, BEFORE the client is
-- told anything. The client then plays a slot-machine animation for
-- GameConfig.ROLL_ANIM_DURATION seconds purely as presentation — it never picks
-- or influences the outcome.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local DataManager = require(script.Parent.DataManager)

export type Plant = GameConfig.Plant
export type PlayerData = GameConfig.PlayerData

local RollService = {}

-- Fired as (player, plant, pedestalIndex) so world-side visuals (the physical
-- pedestal in the plot) can react to a roll without reaching into this module.
RollService.Rolled = Instance.new("BindableEvent")

local rollResultRemote: RemoteEvent

-- userId → { [pedestalIndex]: os.clock() of last roll }
local cooldowns: { [number]: { [number]: number } } = {}

local rng = Random.new()

-- Picks a rarity id using the luck-adjusted weight curve.
local function rollRarity(luck: number): number
	local weights = GameConfig.getRarityWeights(luck)

	local total = 0
	for _, w in weights do
		total += w
	end
	if total <= 0 then
		return 1
	end

	local roll = rng:NextNumber() * total
	local cumulative = 0
	for id, w in weights do
		cumulative += w
		if roll <= cumulative then
			return id
		end
	end
	return 1
end

-- Rolls a full plant (rarity first, then a species eligible for that rarity).
function RollService.rollPlant(luck: number): Plant
	local rarityId = rollRarity(luck)
	local eligible = GameConfig.getSpeciesForRarity(rarityId)
	if #eligible == 0 then
		return { speciesName = GameConfig.SPECIES[1].name, rarityId = 1 }
	end
	local species = eligible[rng:NextInteger(1, #eligible)]
	return { speciesName = species.name, rarityId = rarityId }
end

-- Seconds left before this pedestal can roll again (0 when ready).
function RollService.getCooldownRemaining(player: Player, pedestalIndex: number): number
	local playerCooldowns = cooldowns[player.UserId]
	if not playerCooldowns then
		return 0
	end
	local last = playerCooldowns[pedestalIndex]
	if not last then
		return 0
	end
	return math.max(GameConfig.ROLL_COOLDOWN - (os.clock() - last), 0)
end

-- Handles a client roll request. Returns true when a roll actually happened.
function RollService.requestRoll(player: Player, pedestalIndex: any): boolean
	if typeof(pedestalIndex) ~= "number" or pedestalIndex ~= math.floor(pedestalIndex) then
		return false
	end

	local data = DataManager.get(player)
	if not data then
		return false
	end

	-- Pedestal must be one the player actually owns.
	local owned = math.clamp(data.pedestals or GameConfig.PEDESTAL_START, 1, GameConfig.PEDESTAL_MAX)
	if pedestalIndex < 1 or pedestalIndex > owned then
		return false
	end

	if RollService.getCooldownRemaining(player, pedestalIndex) > 0 then
		return false
	end

	local playerCooldowns = cooldowns[player.UserId]
	if not playerCooldowns then
		playerCooldowns = {}
		cooldowns[player.UserId] = playerCooldowns
	end
	playerCooldowns[pedestalIndex] = os.clock()

	local plant = RollService.rollPlant(data.oreLuck or GameConfig.LUCK_START)
	table.insert(data.plants, plant)

	-- Tell the owner what they got plus how long to spin before revealing it.
	rollResultRemote:FireClient(player, {
		plant = plant,
		pedestalIndex = pedestalIndex,
		duration = GameConfig.ROLL_ANIM_DURATION,
	})

	RollService.Rolled:Fire(player, plant, pedestalIndex)
	return true
end

function RollService.init(remotes: Folder)
	rollResultRemote = remotes:WaitForChild("RollResult", 10) :: RemoteEvent
	if not rollResultRemote then
		error("[RollService] Falta el RemoteEvent RollResult en Remotes.")
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		cooldowns[player.UserId] = nil
	end)
end

return RollService
