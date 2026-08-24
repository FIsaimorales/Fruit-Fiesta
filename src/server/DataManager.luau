--!strict
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

export type PlayerData = GameConfig.PlayerData
export type Plant = GameConfig.Plant

local DataManager = {}

local store = DataStoreService:GetDataStore(GameConfig.DATASTORE_NAME)

-- In-memory cache: userId → data table
local cache: { [number]: PlayerData } = {}

-- Create a fresh default data table with starter coins and plant
local function createDefaultData(): PlayerData
	local initialPlot: { Plant | boolean } = {}
	for i = 1, GameConfig.PLOT_SIZE do
		if i == 1 and GameConfig.STARTING_PLANT then
			initialPlot[i] = {
				speciesName = GameConfig.STARTING_PLANT.speciesName,
				rarityId = GameConfig.STARTING_PLANT.rarityId,
			}
		else
			initialPlot[i] = false -- false = empty slot (serializable in JSON)
		end
	end

	return {
		coins = GameConfig.STARTING_COINS or 150,
		plants = {},
		plot = initialPlot,
		rebirths = 0,
	}
end

local function deepCopy(t: any): any
	if type(t) ~= "table" then
		return t
	end
	local copy = {}
	for k, v in t do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Retry wrapper for DataStore operations
local function retryDataStore<T>(attempts: number, delaySec: number, operation: () -> T): (boolean, any)
	local success = false
	local result: any = nil
	for attempt = 1, attempts do
		success, result = pcall(operation)
		if success then
			return true, result
		end
		if attempt < attempts then
			task.wait(delaySec * attempt)
		end
	end
	return false, result
end

function DataManager.load(player: Player): PlayerData?
	local key = "player_" .. player.UserId
	local success, result = retryDataStore(3, 1, function()
		return store:GetAsync(key)
	end)

	if not success then
		warn("[DataManager] CRITICAL: Fallo al cargar datos para " .. player.Name .. " (" .. player.UserId .. "): " .. tostring(result))
		-- Desconectar al jugador preventivamente para evitar que un auto-guardado sobrescriba sus datos reales con datos vacíos
		player:Kick("Error al cargar tus datos. Por favor reingresa al juego.")
		return nil
	end

	local data: PlayerData
	if result and type(result) == "table" then
		-- Jugador existente: fusionar con defaults por si se agregaron nuevos campos
		local defaults = createDefaultData()
		data = deepCopy(defaults)
		for k, v in result do
			(data :: any)[k] = v
		end
	else
		-- Nuevo jugador: asignar datos iniciales
		data = createDefaultData()
	end

	-- Asegurar que el array del plot tenga la longitud correcta
	for i = 1, GameConfig.PLOT_SIZE do
		if data.plot[i] == nil then
			data.plot[i] = false
		end
	end

	cache[player.UserId] = data
	return data
end

function DataManager.save(player: Player): boolean
	local data = cache[player.UserId]
	if not data then
		return false
	end

	local key = "player_" .. player.UserId
	local success, err = retryDataStore(3, 1, function()
		store:UpdateAsync(key, function(_oldData)
			return data
		end)
		return nil
	end)

	if not success then
		warn("[DataManager] Error al guardar datos para " .. player.Name .. " (" .. player.UserId .. "): " .. tostring(err))
		return false
	end

	return true
end

function DataManager.get(player: Player): PlayerData?
	return cache[player.UserId]
end

function DataManager.unload(player: Player)
	if cache[player.UserId] then
		DataManager.save(player)
		cache[player.UserId] = nil
	end
end

-- Auto-guardado periódico cada 60 segundos con distribución escalonada para evitar picos de escritura
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in Players:GetPlayers() do
			if cache[player.UserId] then
				DataManager.save(player)
				task.wait(0.2) -- Stagger saves
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	DataManager.unload(player)
end)

-- BindToClose: Esperar a que todos los guardados finalicen antes de que el servidor se apague
game:BindToClose(function()
	local playersToSave: { Player } = {}

	for _, player in Players:GetPlayers() do
		if cache[player.UserId] then
			table.insert(playersToSave, player)
		end
	end

	if #playersToSave == 0 then
		return
	end

	print(string.format("[DataManager] Servidor cerrándose: Guardando datos de %d jugadores...", #playersToSave))

	-- Rastrear threads en lugar de contador compartido (evita race condition)
	local threads: { thread } = {}
	for _, player in playersToSave do
		table.insert(threads, task.spawn(function()
			DataManager.save(player)
		end))
	end

	-- Esperar con timeout máximo de 25 segundos (Roblox corta a los 30s)
	local startTime = os.clock()
	while (os.clock() - startTime) < 25 do
		local allDone = true
		for _, thread in threads do
			if coroutine.status(thread) ~= "dead" then
				allDone = false
				break
			end
		end
		if allDone then break end
		task.wait(0.05)
	end

	print("[DataManager] Guardado de cierre finalizado.")
end)

return DataManager
