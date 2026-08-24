local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local GameConfig = require(game.ReplicatedStorage.Shared.GameConfig)

local DataManager = {}

local store = DataStoreService:GetDataStore(GameConfig.DATASTORE_NAME)

-- In-memory cache: userId → data table
local cache: { [number]: any } = {}

local DEFAULT_DATA = {
	coins = 0,
	plants = {},   -- array of { speciesName: string, rarityId: number }
	plot = {},     -- [PLOT_SIZE] slots: nil = empty, or { speciesName, rarityId }
	rebirths = 0,
}

local function deepCopy(t)
	local copy = {}
	for k, v in t do
		copy[k] = type(v) == "table" and deepCopy(v) or v
	end
	return copy
end

function DataManager.load(player: Player)
	local key = "player_" .. player.UserId
	local success, result = pcall(function()
		return store:GetAsync(key)
	end)

	local data: typeof(DEFAULT_DATA)
	if success and result then
		-- Merge with defaults so new fields appear on old saves
		data = deepCopy(DEFAULT_DATA)
		for k, v in result do
			data[k] = v
		end
	else
		data = deepCopy(DEFAULT_DATA)
		if not success then
			warn("DataManager: load failed for", player.Name, result)
		end
	end

	-- Ensure plot array has correct length
	for i = 1, GameConfig.PLOT_SIZE do
		if data.plot[i] == nil then
			data.plot[i] = false  -- false = empty slot (nil doesn't serialize)
		end
	end

	cache[player.UserId] = data
	return data
end

function DataManager.save(player: Player)
	local data = cache[player.UserId]
	if not data then return end

	local key = "player_" .. player.UserId
	local success, err = pcall(function()
		store:SetAsync(key, data)
	end)

	if not success then
		warn("DataManager: save failed for", player.Name, err)
	end
end

function DataManager.get(player: Player)
	return cache[player.UserId]
end

function DataManager.unload(player: Player)
	DataManager.save(player)
	cache[player.UserId] = nil
end

-- Auto-save every 60 seconds for all online players
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in Players:GetPlayers() do
			DataManager.save(player)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	DataManager.unload(player)
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		DataManager.save(player)
	end
end)

return DataManager
