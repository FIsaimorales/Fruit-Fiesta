local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(game.ReplicatedStorage.Shared.GameConfig)
local DataManager = require(script.Parent.DataManager)

local IncomeService = {}

local updateRemote: RemoteEvent

-- Calculates total coins/s for a player's current plot
local function calcIncome(data): number
	local total = 0
	for _, slot in data.plot do
		if slot and slot ~= false then
			total += GameConfig.getIncome(slot.speciesName, slot.rarityId)
		end
	end
	return total
end

function IncomeService.init(remotes: Folder)
	updateRemote = remotes:WaitForChild("UpdatePlayerData")

	task.spawn(function()
		while true do
			task.wait(GameConfig.INCOME_TICK_RATE)
			for _, player in Players:GetPlayers() do
				local data = DataManager.get(player)
				if not data then continue end

				local income = calcIncome(data)
				data.coins += income

				-- Fire updated state to the client
				updateRemote:FireClient(player, {
					coins = data.coins,
					plants = data.plants,
					plot = data.plot,
					rebirths = data.rebirths,
					incomePerSecond = income,
				})
			end
		end
	end)
end

-- Called by EconomyService when a player's plot/inventory changes mid-tick
function IncomeService.pushUpdate(player: Player)
	local data = DataManager.get(player)
	if not data then return end

	local income = calcIncome(data)
	updateRemote:FireClient(player, {
		coins = data.coins,
		plants = data.plants,
		plot = data.plot,
		rebirths = data.rebirths,
		incomePerSecond = income,
	})
end

return IncomeService
