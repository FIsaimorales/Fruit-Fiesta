--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(script.DataManager)
local IncomeService = require(script.IncomeService)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

-- Create or retrieve RemoteEvents folder in ReplicatedStorage
local remotes: Folder
local existingRemotes = ReplicatedStorage:FindFirstChild("Remotes")
if existingRemotes and existingRemotes:IsA("Folder") then
	remotes = existingRemotes
else
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

-- Server → Client: push full player state (inventory changes, initial load)
getOrCreateRemote("UpdatePlayerData")

-- Server → Client: lightweight tick update for coins & income/s
getOrCreateRemote("UpdateCoins")

-- Client → Server: open an egg
local openEgg = getOrCreateRemote("OpenEgg")

-- Client → Server: place a plant from inventory into a plot slot
local placePlant = getOrCreateRemote("PlacePlant")

-- Client → Server: remove plant from plot slot back to inventory
local removePlant = getOrCreateRemote("RemovePlant")

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
	for id, w in ipairs(GameConfig.EGG_WEIGHTS) do
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

	if #eligibleSpecies == 0 then
		warn("[Server] No hay especies para rarityId=" .. rarityId .. ". Usando fallback Manzana.")
		return "Manzana", 1
	end
	local selectedSpecies = eligibleSpecies[math.random(1, #eligibleSpecies)]
	return selectedSpecies.name, rarityId
end

openEgg.OnServerEvent:Connect(function(player: Player)
	if not checkRateLimit(player, 0.15) then
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
	table.insert(data.plants, { speciesName = speciesName, rarityId = rarityId })

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
	if currentSlot and (currentSlot :: any) ~= false then
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
	if not slot or (slot :: any) == false or type(slot) ~= "table" then
		return
	end

	data.plot[slotIndex] = false
	table.insert(data.plants, slot)

	IncomeService.pushUpdate(player)
end)

-- ── Player lifecycle ──────────────────────────────────────────────────────────

local function setupPlayer(player: Player)
	local data = DataManager.load(player)
	if data then
		IncomeService.pushUpdate(player)
	end
end

-- Inicializar IncomeService ANTES de conectar PlayerAdded para evitar nil-access en pushUpdate
IncomeService.init(remotes)

Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(player: Player)
	lastAction[player.UserId] = nil
end)

for _, player in Players:GetPlayers() do
	task.spawn(setupPlayer, player)
end

print("[Server] FruitGarden initialized with security and gacha fixes.")
