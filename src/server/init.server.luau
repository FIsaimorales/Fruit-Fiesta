local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(script.DataManager)
local IncomeService = require(script.IncomeService)
local GameConfig = require(game.ReplicatedStorage.Shared.GameConfig)

-- Create RemoteEvents folder in ReplicatedStorage
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local function makeRemote(name: string)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end

-- Server → Client: push full player state
local _updatePlayerData = makeRemote("UpdatePlayerData")

-- Client → Server: open an egg
local openEgg = makeRemote("OpenEgg")

-- Client → Server: place a plant from inventory into a plot slot
-- Args: inventoryIndex (number), slotIndex (number)
local placePlant = makeRemote("PlacePlant")

-- Client → Server: remove plant from plot slot back to inventory
-- Args: slotIndex (number)
local removePlant = makeRemote("RemovePlant")

-- Trade remotes (wired up later in Fase 2)
local _proposeTrade = makeRemote("ProposeTrade")
local _respondTrade = makeRemote("RespondTrade")

-- ── Egg gacha logic ───────────────────────────────────────────────────────────

local function rollRarity(minRarity: number): number
	local weights = {}
	local total = 0
	for id = minRarity, #GameConfig.RARITIES do
		local w = GameConfig.EGG_WEIGHTS[id] or 0
		table.insert(weights, { id = id, w = w })
		total += w
	end

	local roll = math.random() * total
	local cumulative = 0
	for _, entry in weights do
		cumulative += entry.w
		if roll <= cumulative then
			return entry.id
		end
	end
	return weights[#weights].id
end

local function rollSpecies(): (string, number)
	local species = GameConfig.SPECIES[math.random(1, #GameConfig.SPECIES)]
	local rarityId: number
	if species.fixedRarity then
		rarityId = species.fixedRarity
	else
		rarityId = rollRarity(species.minRarity)
	end
	return species.name, rarityId
end

openEgg.OnServerEvent:Connect(function(player: Player)
	local data = DataManager.get(player)
	if not data then return end
	if data.coins < GameConfig.EGG_COST then return end

	data.coins -= GameConfig.EGG_COST

	local speciesName, rarityId = rollSpecies()
	table.insert(data.plants, { speciesName = speciesName, rarityId = rarityId })

	IncomeService.pushUpdate(player)
end)

-- ── Plot management ───────────────────────────────────────────────────────────

placePlant.OnServerEvent:Connect(function(player: Player, inventoryIndex: number, slotIndex: number)
	local data = DataManager.get(player)
	if not data then return end
	if type(inventoryIndex) ~= "number" or type(slotIndex) ~= "number" then return end
	if slotIndex < 1 or slotIndex > GameConfig.PLOT_SIZE then return end
	if not data.plants[inventoryIndex] then return end
	if data.plot[slotIndex] and data.plot[slotIndex] ~= false then return end

	local plant = table.remove(data.plants, inventoryIndex)
	data.plot[slotIndex] = plant

	IncomeService.pushUpdate(player)
end)

removePlant.OnServerEvent:Connect(function(player: Player, slotIndex: number)
	local data = DataManager.get(player)
	if not data then return end
	if type(slotIndex) ~= "number" then return end
	if slotIndex < 1 or slotIndex > GameConfig.PLOT_SIZE then return end
	if not data.plot[slotIndex] or data.plot[slotIndex] == false then return end

	local plant = data.plot[slotIndex]
	data.plot[slotIndex] = false
	table.insert(data.plants, plant)

	IncomeService.pushUpdate(player)
end)

-- ── Player lifecycle ──────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player: Player)
	DataManager.load(player)
	IncomeService.pushUpdate(player)
end)

for _, player in Players:GetPlayers() do
	DataManager.load(player)
	IncomeService.pushUpdate(player)
end

IncomeService.init(remotes)

print("[Server] FruitGarden initialized")
