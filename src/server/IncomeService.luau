--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local DataManager = require(script.Parent.DataManager)

export type PlayerData = GameConfig.PlayerData

local IncomeService = {}

local updatePlayerRemote: RemoteEvent
local updateCoinsRemote: RemoteEvent

-- Calculates total coins/s for a player's current plot. Only pots the player
-- has actually unlocked count, so a rebirth rollback can never keep paying out.
function IncomeService.calcIncome(data: PlayerData): number
	local maxPots = GameConfig.getMaxPots(data.rebirths or 0)
	local total = 0
	for i = 1, maxPots do
		local slot = data.plot[i]
		if slot and type(slot) == "table" then
			total += GameConfig.getIncome(slot.speciesName, slot.rarityId)
		end
	end
	return total
end

function IncomeService.init(remotes: Folder)
	updatePlayerRemote = remotes:WaitForChild("UpdatePlayerData", 10) :: RemoteEvent
	updateCoinsRemote = remotes:WaitForChild("UpdateCoins", 10) :: RemoteEvent
	if not updatePlayerRemote or not updateCoinsRemote then
		error("[IncomeService] No se encontraron los RemoteEvents necesarios en Remotes.")
	end

	task.spawn(function()
		while true do
			task.wait(GameConfig.INCOME_TICK_RATE)
			for _, player in Players:GetPlayers() do
				local data = DataManager.get(player)
				if not data then
					continue
				end

				local income = IncomeService.calcIncome(data)
				if income > 0 then
					data.coins += income
				end

				-- Enviar únicamente actualización ligera de monedas e income/s (optimización de red)
				updateCoinsRemote:FireClient(player, data.coins, income)
			end
		end
	end)
end

-- Called when a player's plot/inventory changes mid-tick or upon initial load
function IncomeService.pushUpdate(player: Player)
	local data = DataManager.get(player)
	if not data then
		return
	end

	local income = IncomeService.calcIncome(data)
	local oreLuck = data.oreLuck or GameConfig.LUCK_START
	local pedestals = data.pedestals or GameConfig.PEDESTAL_START

	updatePlayerRemote:FireClient(player, {
		coins = data.coins,
		plants = data.plants,
		plot = data.plot,
		rebirths = data.rebirths,
		incomePerSecond = income,

		oreLuck = oreLuck,
		pedestals = pedestals,
		maxPots = GameConfig.getMaxPots(data.rebirths or 0),
		nextPotUnlock = GameConfig.getNextPotUnlock(data.rebirths or 0),
		luckCost = oreLuck < GameConfig.LUCK_MAX and GameConfig.getLuckCost(oreLuck) or nil,
		pedestalCost = pedestals < GameConfig.PEDESTAL_MAX and GameConfig.getPedestalCost(pedestals) or nil,
	})
end

return IncomeService
