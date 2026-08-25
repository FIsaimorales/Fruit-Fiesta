--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(script.DataManager)
local IncomeService = require(script.IncomeService)
local RollService = require(script.RollService)
local UpgradeService = require(script.UpgradeService)
local PlotService = require(script.PlotService)
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

-- Server → Client: roll outcome (already decided) + how long to spin for
local _rollResult = getOrCreateRemote("RollResult")

-- Client → Server: pull a roll pedestal
local requestRoll = getOrCreateRemote("RequestRoll")

-- Client → Server: purchase an upgrade (oreLuck / pedestals)
local buyUpgrade = getOrCreateRemote("BuyUpgrade")

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

-- Pushes state to the owning client and repaints their physical plot. Every
-- mutation below funnels through this so HUD and world never disagree.
local function syncPlayer(player: Player)
	IncomeService.pushUpdate(player)
	PlotService.refresh(player)
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

	syncPlayer(player)
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

	-- Only pots unlocked at this rebirth count are plantable.
	if slotIndex < 1 or slotIndex > GameConfig.getMaxPots(data.rebirths or 0) then
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
	syncPlayer(player)
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

	syncPlayer(player)
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

	-- Fill unlocked pots with the best plants; the rest go back to the backpack
	local capacity = GameConfig.getMaxPots(data.rebirths or 0)
	local newPlot: { Plant | boolean } = {}
	local newPlants: { Plant } = {}

	for i = 1, GameConfig.PLOT_SIZE do
		if i <= capacity and allPlants[i] then
			newPlot[i] = allPlants[i]
		else
			newPlot[i] = false
		end
	end

	for i = capacity + 1, #allPlants do
		table.insert(newPlants, allPlants[i])
	end

	data.plot = newPlot
	data.plants = newPlants

	syncPlayer(player)
end)

-- ── Roll pedestals ────────────────────────────────────────────────────────────

-- The pedestal itself is a ProximityPrompt handled by PlotService; this remote
-- is the HUD's equivalent button. Both funnel into the same validated path.
requestRoll.OnServerEvent:Connect(function(player: Player, pedestalIndex: any)
	if not checkRateLimit(player, 0.1) then
		return
	end
	RollService.requestRoll(player, pedestalIndex)
end)

-- ── Upgrades ──────────────────────────────────────────────────────────────────

buyUpgrade.OnServerEvent:Connect(function(player: Player, upgradeId: any)
	if not checkRateLimit(player, 0.2) then
		return
	end
	if typeof(upgradeId) ~= "string" then
		return
	end
	UpgradeService.buy(player, upgradeId)
end)

-- Roll and upgrade both mutate coins/inventory, so refresh the client after.
RollService.Rolled.Event:Connect(function(player: Player)
	IncomeService.pushUpdate(player)
end)

UpgradeService.Purchased.Event:Connect(function(player: Player)
	IncomeService.pushUpdate(player)
end)

-- ── Player lifecycle ──────────────────────────────────────────────────────────

local function setupPlayer(player: Player)
	local data = DataManager.load(player)
	if not data then
		return
	end

	PlotService.assign(player)
	IncomeService.pushUpdate(player)
end

Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(player: Player)
	lastAction[player.UserId] = nil
end)

-- Must run before any setupPlayer call: pushUpdate fires the remotes these set up.
IncomeService.init(remotes)
RollService.init(remotes)
PlotService.init()

for _, player in Players:GetPlayers() do
	task.spawn(setupPlayer, player)
end

print("[Server] FruitGarden initialized: roll pedestals, upgrades & 2x3 plot grid.")
