--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local DataManager = require(script.Parent.DataManager)

export type PlayerData = GameConfig.PlayerData

local IncomeService = {}

local updatePlayerRemote: RemoteEvent
local updateCoinsRemote: RemoteEvent

-- Calculates total coins/s for a player's current plot
function IncomeService.calcIncome(data: PlayerData): number
	local total = 0
	for _, slot in data.plot do
		if slot and type(slot) == "table" then
			total += GameConfig.getIncome(slot.speciesName, slot.rarityId)
		end
	end
	return total
end

function IncomeService.init(remotes: Folder)
	updatePlayerRemote = remotes:WaitForChild("UpdatePlayerData") :: RemoteEvent
	updateCoinsRemote = remotes:WaitForChild("UpdateCoins") :: RemoteEvent

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
	updatePlayerRemote:FireClient(player, {
		coins = data.coins,
		plants = data.plants,
		plot = data.plot,
		rebirths = data.rebirths,
		incomePerSecond = income,
	})
end

return IncomeService
