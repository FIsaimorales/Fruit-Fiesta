--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(script.DataManager)
local IncomeService = require(script.IncomeService)
local RollService = require(script.RollService)
local UpgradeService = require(script.UpgradeService)
local FarmService = require(script.FarmService)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

export type Animal = GameConfig.Animal

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

-- Server → Client: lightweight tick update for money & income/s
local _updateMoney = getOrCreateRemote("UpdateMoney")

-- Server → Client: notify egg gacha reveal result
local eggOpened = getOrCreateRemote("EggOpened")

-- Client → Server: open an egg
local openEgg = getOrCreateRemote("OpenEgg")

-- Client → Server: place a animal from inventory into a farm slot
local placeAnimal = getOrCreateRemote("PlaceAnimal")

-- Client → Server: remove animal from farm slot back to inventory
local removeAnimal = getOrCreateRemote("RemoveAnimal")

-- Client → Server: auto equip best animals
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

-- Pushes state to the owning client and repaints their physical farm. Every
-- mutation below funnels through this so HUD and world never disagree.
local function syncPlayer(player: Player)
	IncomeService.pushUpdate(player)
	FarmService.refresh(player)
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
	if data.money < GameConfig.EGG_COST then
		return
	end

	data.money -= GameConfig.EGG_COST

	local animalSpecies, rarityId = rollEgg()
	local newAnimal: Animal = { animalSpecies = animalSpecies, rarityId = rarityId }
	table.insert(data.animals, newAnimal)

	-- Notify client to play the gacha reveal cinematic
	eggOpened:FireClient(player, newAnimal)

	syncPlayer(player)
end)

-- ── Farm management ───────────────────────────────────────────────────────────

placeAnimal.OnServerEvent:Connect(function(player: Player, inventoryIndex: any, slotIndex: any)
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
	if inventoryIndex < 1 or inventoryIndex > #data.animals then
		return
	end

	-- Ensure target slot is empty
	local currentSlot = data.farm[slotIndex]
	if currentSlot and currentSlot ~= false then
		return
	end

	local animal = table.remove(data.animals, inventoryIndex)
	if not animal then
		return
	end

	data.farm[slotIndex] = animal
	syncPlayer(player)
end)

removeAnimal.OnServerEvent:Connect(function(player: Player, slotIndex: any)
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

	if slotIndex < 1 or slotIndex > GameConfig.FARM_SIZE then
		return
	end

	local slot = data.farm[slotIndex]
	if not slot or slot == false or type(slot) ~= "table" then
		return
	end

	data.farm[slotIndex] = false
	table.insert(data.animals, slot)

	syncPlayer(player)
end)

-- Auto equip best animals into the farm
autoEquipBest.OnServerEvent:Connect(function(player: Player)
	if not checkRateLimit(player, 0.2) then
		return
	end

	local data = DataManager.get(player)
	if not data then
		return
	end

	-- Collect all animals
	local allAnimals: { Animal } = {}
	for _, slot in data.farm do
		if slot and type(slot) == "table" then
			table.insert(allAnimals, slot)
		end
	end
	for _, animal in data.animals do
		table.insert(allAnimals, animal)
	end

	-- Sort by income descending
	table.sort(allAnimals, function(a, b)
		local incomeA = GameConfig.getIncome(a.animalSpecies, a.rarityId)
		local incomeB = GameConfig.getIncome(b.animalSpecies, b.rarityId)
		if incomeA == incomeB then
			return a.rarityId > b.rarityId
		end
		return incomeA > incomeB
	end)

	-- Fill unlocked pots with the best animals; the rest go back to the backpack
	local capacity = GameConfig.getMaxPots(data.rebirths or 0)
	local newFarm: { Animal | boolean } = {}
	local newAnimalsBackpack: { Animal } = {}

	for i = 1, GameConfig.FARM_SIZE do
		if i <= capacity and allAnimals[i] then
			newFarm[i] = allAnimals[i]
		else
			newFarm[i] = false
		end
	end

	for i = capacity + 1, #allAnimals do
		table.insert(newAnimalsBackpack, allAnimals[i])
	end

	data.farm = newFarm
	data.animals = newAnimalsBackpack

	syncPlayer(player)
end)

-- ── Roll pedestals ────────────────────────────────────────────────────────────

-- The pedestal itself is a ProximityPrompt handled by FarmService; this remote
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

-- Roll and upgrade both mutate money/inventory, so refresh the client after.
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

	FarmService.assign(player)
	IncomeService.pushUpdate(player)
end

Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(player: Player)
	lastAction[player.UserId] = nil
end)

-- Must run before any setupPlayer call: pushUpdate fires the remotes these set up.
IncomeService.init(remotes)
RollService.init(remotes)
FarmService.init()

for _, player in Players:GetPlayers() do
	task.spawn(setupPlayer, player)
end

print("[Server] Granja Fantástica initialized: roll pedestals, upgrades & 2x3 farm grid.")
