--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(script.DataManager)
local IncomeService = require(script.IncomeService)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

export type Plant = GameConfig.Plant

-- Create or retrieve RemoteEvents folder in ReplicatedStorage
local remotes = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function getOrCreateRemote(name: string): RemoteEvent
	local existing = remotes:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end

-- Server → Client: push full player state
local _updatePlayerData = getOrCreateRemote("UpdatePlayerData")

-- Server → Client: lightweight tick update for coins & income/s
local _updateCoins = getOrCreateRemote("UpdateCoins")

-- Server → Client: notify egg gacha reveal result
local eggOpened = getOrCreateRemote("EggOpened")

-- Client → Server: open an egg
local openEgg = getOrCreateRemote("OpenEgg")

-- Client → Server: place a plant from inventory into a plot slot
local placePlant = getOrCreateRemote("PlacePlant")

-- Client → Server: remove plant from plot slot back to inventory
local removePlant = getOrCreateRemote("RemovePlant")

-- Client → Server: auto equip best plants
local autoEquipBest = getOrCreateRemote("AutoEquipBest")

-- ── Debounce anti-spam helper ────────────────────────────────────────────────
local lastAction: { [number]: number } = {}

local function checkRateLimit(player: Player, minDelay: number): boolean
	local now = os.clock()
	local last = lastAction[player.UserId] or 0
	if (now - last) < minDelay then
		return false
	end
	lastAction[player.UserId] = now
	return true
end

-- ── Egg gacha logic (rarity rolled first according to EGG_WEIGHTS) ─────────────

local function rollRarity(): number
	local totalWeight = 0
	for _, w in GameConfig.EGG_WEIGHTS do
		totalWeight += w
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for id, w in GameConfig.EGG_WEIGHTS do
		cumulative += w
		if roll <= cumulative then
			return id
		end
	end
	return 1
end

local function rollEgg(): (string, number)
	local rarityId = rollRarity()
	local eligibleSpecies = GameConfig.getSpeciesForRarity(rarityId)

	local selectedSpecies = eligibleSpecies[math.random(1, #eligibleSpecies)]
	return selectedSpecies.name, rarityId
end

openEgg.OnServerEvent:Connect(function(player: Player)
	if not checkRateLimit(player, 0.2) then
		return
	end

	local data = DataManager.get(player)
	if not data then
		return
	end
	if data.coins < GameConfig.EGG_COST then
		return
	end

	data.coins -= GameConfig.EGG_COST

	local speciesName, rarityId = rollEgg()
	local newPlant: Plant = { speciesName = speciesName, rarityId = rarityId }
	table.insert(data.plants, newPlant)

	-- Notify client to play the gacha reveal cinematic
	eggOpened:FireClient(player, newPlant)

	IncomeService.pushUpdate(player)
end)

-- ── Plot management ───────────────────────────────────────────────────────────

placePlant.OnServerEvent:Connect(function(player: Player, inventoryIndex: any, slotIndex: any)
	if not checkRateLimit(player, 0.05) then
		return
	end

	-- Strict integer and type validation
	if typeof(inventoryIndex) ~= "number" or typeof(slotIndex) ~= "number" then
		return
	end
	if inventoryIndex ~= math.floor(inventoryIndex) or slotIndex ~= math.floor(slotIndex) then
		return
	end

	local data = DataManager.get(player)
	if not data then
		return
	end

	if slotIndex < 1 or slotIndex > GameConfig.PLOT_SIZE then
		return
	end
	if inventoryIndex < 1 or inventoryIndex > #data.plants then
		return
	end

	-- Ensure target slot is empty
	local currentSlot = data.plot[slotIndex]
	if currentSlot and currentSlot ~= false then
		return
	end

	local plant = table.remove(data.plants, inventoryIndex)
	if not plant then
		return
	end

	data.plot[slotIndex] = plant
	IncomeService.pushUpdate(player)
end)

removePlant.OnServerEvent:Connect(function(player: Player, slotIndex: any)
	if not checkRateLimit(player, 0.05) then
		return
	end

	-- Strict integer and type validation
	if typeof(slotIndex) ~= "number" or slotIndex ~= math.floor(slotIndex) then
		return
	end

	local data = DataManager.get(player)
	if not data then
		return
	end

	if slotIndex < 1 or slotIndex > GameConfig.PLOT_SIZE then
		return
	end

	local slot = data.plot[slotIndex]
	if not slot or slot == false or type(slot) ~= "table" then
		return
	end

	data.plot[slotIndex] = false
	table.insert(data.plants, slot)

	IncomeService.pushUpdate(player)
end)

-- Auto equip best plants into the plot
autoEquipBest.OnServerEvent:Connect(function(player: Player)
	if not checkRateLimit(player, 0.2) then
		return
	end

	local data = DataManager.get(player)
	if not data then
		return
	end

	-- Collect all plants
	local allPlants: { Plant } = {}
	for _, slot in data.plot do
		if slot and type(slot) == "table" then
			table.insert(allPlants, slot)
		end
	end
	for _, plant in data.plants do
		table.insert(allPlants, plant)
	end

	-- Sort by income descending
	table.sort(allPlants, function(a, b)
		local incomeA = GameConfig.getIncome(a.speciesName, a.rarityId)
		local incomeB = GameConfig.getIncome(b.speciesName, b.rarityId)
		if incomeA == incomeB then
			return a.rarityId > b.rarityId
		end
		return incomeA > incomeB
	end)

	-- Fill plot with best
	local newPlot: { Plant | boolean } = {}
	local newPlants: { Plant } = {}

	for i = 1, GameConfig.PLOT_SIZE do
		if allPlants[i] then
			newPlot[i] = allPlants[i]
		else
			newPlot[i] = false
		end
	end

	for i = GameConfig.PLOT_SIZE + 1, #allPlants do
		table.insert(newPlants, allPlants[i])
	end

	data.plot = newPlot
	data.plants = newPlants

	IncomeService.pushUpdate(player)
end)

-- ── Player lifecycle ──────────────────────────────────────────────────────────

local function setupPlayer(player: Player)
	local data = DataManager.load(player)
	if data then
		IncomeService.pushUpdate(player)
	end
end

Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(player: Player)
	lastAction[player.UserId] = nil
end)

-- Must run before any setupPlayer call: pushUpdate fires the remotes this sets up.
IncomeService.init(remotes)

for _, player in Players:GetPlayers() do
	task.spawn(setupPlayer, player)
end

print("[Server] FruitGarden initialized with modern UI remotes & AutoEquip.")
