--!strict
-- Leases one of the six plots to each player and keeps its world visuals in
-- sync with that player's data.
--
-- All geometry lives in ReplicatedStorage.Shared.PlotLayout so the Studio scene
-- draft and the live server build an identical world; this module only adds
-- ownership, prompts and refresh logic on top.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local PlantModel = require(ReplicatedStorage.Shared.PlantModel)
local PlotLayout = require(ReplicatedStorage.Shared.PlotLayout)
local DataManager = require(script.Parent.DataManager)
local RollService = require(script.Parent.RollService)
local UpgradeService = require(script.Parent.UpgradeService)

export type Plant = GameConfig.Plant

local PlotService = {}

PlotService.PLOT_COUNT = PlotLayout.PLOT_COUNT

-- plotIndex → Model, and userId → plotIndex
local plots: { [number]: Model } = {}
local ownership: { [number]: number } = {}

local function getPlotOf(player: Player): Model?
	local plotIndex = ownership[player.UserId]
	return plotIndex and plots[plotIndex] or nil
end

local function ownerOf(plot: Model): Player?
	local userId = plot:GetAttribute("OwnerUserId")
	if type(userId) ~= "number" then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

local function findLabel(container: Instance?, partName: string, guiName: string): TextLabel?
	if not container then
		return nil
	end
	local part = container:FindFirstChild(partName)
	if not part then
		return nil
	end
	local gui = part:FindFirstChild(guiName)
	if not gui then
		return nil
	end
	return gui:FindFirstChild("Label") :: TextLabel?
end

-- ── Refresh ───────────────────────────────────────────────────────────────────

-- Repaints one plot from its owner's current data: pot visibility, planted
-- models, pedestal availability and upgrade pricing.
function PlotService.refresh(player: Player)
	local plot = getPlotOf(player)
	if not plot then
		return
	end

	local data = DataManager.get(player)
	if not data then
		return
	end

	local maxPots = GameConfig.getMaxPots(data.rebirths or 0)
	local ownedPedestals = math.clamp(data.pedestals or GameConfig.PEDESTAL_START, 1, GameConfig.PEDESTAL_MAX)

	-- Pots + planted models
	local pots = plot:FindFirstChild("Pots")
	if pots then
		for slotIndex = 1, GameConfig.PLOT_MAX_SIZE do
			local pot = pots:FindFirstChild("Pot" .. slotIndex) :: Model?
			if not pot then
				continue
			end

			local unlocked = slotIndex <= maxPots
			for _, part in pot:GetDescendants() do
				if part:IsA("BasePart") then
					part.Transparency = unlocked and 0 or 1
					part.CanCollide = unlocked and part.Name == "PotBody"
				end
			end

			local existingPlant = pot:FindFirstChild("Plant")
			if existingPlant then
				existingPlant:Destroy()
			end

			local slot = data.plot[slotIndex]
			if unlocked and slot and type(slot) == "table" then
				local plant = PlantModel.build(slot)
				plant.Name = "Plant"
				-- Soil surface sits ~2 studs above the pot base.
				plant:PivotTo(pot:GetPivot() * CFrame.new(0, 2, 0))
				plant.Parent = pot
			end
		end
	end

	-- Pedestals: hide the ones this player has not bought yet.
	for pedestalIndex = 1, GameConfig.PEDESTAL_MAX do
		local pedestal = plot:FindFirstChild("Pedestal" .. pedestalIndex) :: Model?
		if not pedestal then
			continue
		end

		local owned = pedestalIndex <= ownedPedestals
		for _, part in pedestal:GetDescendants() do
			if part:IsA("BasePart") then
				part.Transparency = owned and 0 or 1
				part.CanCollide = owned
			end
		end

		local top = pedestal:FindFirstChild("Top") :: BasePart?
		if top then
			local prompt = top:FindFirstChild("RollPrompt") :: ProximityPrompt?
			if prompt then
				prompt.Enabled = owned
			end
			local gui = top:FindFirstChild("StatusGui") :: BillboardGui?
			if gui then
				gui.Enabled = owned
			end
		end
	end

	-- Upgrade signage
	local luck = data.oreLuck or GameConfig.LUCK_START
	local luckLabel = findLabel(plot:FindFirstChild("Upgrade_oreLuck"), "Pad", "InfoGui")
	if luckLabel then
		if luck >= GameConfig.LUCK_MAX then
			luckLabel.Text = string.format("⛏️ ORE LUCK\n%dx · MÁXIMO", luck)
		else
			luckLabel.Text = string.format(
				"⛏️ ORE LUCK\n%dx → %dx\n$%d",
				luck,
				luck + GameConfig.LUCK_STEP,
				GameConfig.getLuckCost(luck)
			)
		end
	end

	local pedestalLabel = findLabel(plot:FindFirstChild("Upgrade_pedestals"), "Pad", "InfoGui")
	if pedestalLabel then
		if ownedPedestals >= GameConfig.PEDESTAL_MAX then
			pedestalLabel.Text = string.format("🎰 PEDESTALES\n%d · MÁXIMO", ownedPedestals)
		else
			pedestalLabel.Text = string.format(
				"🎰 PEDESTALES\n%d → %d\n$%d",
				ownedPedestals,
				ownedPedestals + 1,
				GameConfig.getPedestalCost(ownedPedestals)
			)
		end
	end

	-- Owner sign
	local ownerLabel = findLabel(plot, "SignBoard", "OwnerGui")
	if ownerLabel then
		ownerLabel.Text = string.format("%s\n%d/%d macetas", player.DisplayName, maxPots, GameConfig.PLOT_MAX_SIZE)
	end
end

-- ── Ownership ─────────────────────────────────────────────────────────────────

local function resetPlotVisuals(plotIndex: number)
	local plot = plots[plotIndex]
	if not plot then
		return
	end

	plot:SetAttribute("OwnerUserId", nil)

	local border = plot:FindFirstChild("Border") :: BasePart?
	if border then
		border.Color = PlotLayout.UNCLAIMED_COLOR
	end

	local pots = plot:FindFirstChild("Pots")
	if pots then
		for _, pot in pots:GetChildren() do
			local plant = pot:FindFirstChild("Plant")
			if plant then
				plant:Destroy()
			end
		end
	end

	local ownerLabel = findLabel(plot, "SignBoard", "OwnerGui")
	if ownerLabel then
		ownerLabel.Text = "Parcela " .. plotIndex .. "\nLibre"
	end
end

-- Leases the first free plot to a player. Returns the plot index, or nil when
-- the server is somehow over capacity.
function PlotService.assign(player: Player): number?
	local existing = ownership[player.UserId]
	if existing then
		return existing
	end

	for plotIndex = 1, PlotLayout.PLOT_COUNT do
		local plot = plots[plotIndex]
		if plot and plot:GetAttribute("OwnerUserId") == nil then
			plot:SetAttribute("OwnerUserId", player.UserId)
			ownership[player.UserId] = plotIndex

			local border = plot:FindFirstChild("Border") :: BasePart?
			if border then
				border.Color = PlotLayout.CLAIMED_COLOR
			end

			-- Drop the player at the front of their own plot.
			local character = player.Character
			if character then
				local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					root.CFrame = PlotLayout.getPlotOrigin(plotIndex)
						* CFrame.new(0, 5, PlotLayout.PLOT_DEPTH / 2 - 6)
				end
			end

			PlotService.refresh(player)
			return plotIndex
		end
	end

	warn("[PlotService] No hay parcelas libres para " .. player.Name)
	return nil
end

function PlotService.release(player: Player)
	local plotIndex = ownership[player.UserId]
	if not plotIndex then
		return
	end
	ownership[player.UserId] = nil
	resetPlotVisuals(plotIndex)
end

-- ── Wiring ────────────────────────────────────────────────────────────────────

local function wirePrompts(plot: Model)
	for _, descendant in plot:GetDescendants() do
		if not descendant:IsA("ProximityPrompt") then
			continue
		end

		-- Prompt sits on a part, whose parent is the pedestal / button model.
		local model = descendant.Parent and descendant.Parent.Parent
		if not model or not model:IsA("Model") then
			continue
		end

		if descendant.Name == "RollPrompt" then
			local pedestalIndex = model:GetAttribute("PedestalIndex")
			descendant.Triggered:Connect(function(triggerPlayer: Player)
				-- Only the plot's owner may use its pedestals.
				if plot:GetAttribute("OwnerUserId") ~= triggerPlayer.UserId then
					return
				end
				RollService.requestRoll(triggerPlayer, pedestalIndex)
			end)
		elseif descendant.Name == "BuyPrompt" then
			local upgradeId = model:GetAttribute("UpgradeId")
			descendant.Triggered:Connect(function(triggerPlayer: Player)
				if plot:GetAttribute("OwnerUserId") ~= triggerPlayer.UserId then
					return
				end
				UpgradeService.buy(triggerPlayer, upgradeId)
			end)
		end
	end
end

-- Counts the pedestal billboards down so the player can see them recharge.
local function startCooldownDisplay()
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, plot in plots do
				local player = ownerOf(plot)
				if not player then
					continue
				end

				for pedestalIndex = 1, GameConfig.PEDESTAL_MAX do
					local pedestal = plot:FindFirstChild("Pedestal" .. pedestalIndex) :: Model?
					if not pedestal then
						continue
					end
					local top = pedestal:FindFirstChild("Top") :: BasePart?
					local label = findLabel(pedestal, "Top", "StatusGui")
					if not top or not label then
						continue
					end

					local prompt = top:FindFirstChild("RollPrompt") :: ProximityPrompt?
					local remaining = RollService.getCooldownRemaining(player, pedestalIndex)

					if remaining > 0 then
						label.Text = string.format("%.1fs", remaining)
						label.TextColor3 = Color3.fromRGB(190, 200, 220)
						top.Color = Color3.fromRGB(90, 100, 130)
						if prompt then
							prompt.Enabled = false
						end
					else
						label.Text = "ROLL"
						label.TextColor3 = Color3.fromRGB(255, 214, 90)
						top.Color = Color3.fromRGB(255, 196, 62)
						if prompt then
							prompt.Enabled = true
						end
					end
				end
			end
		end
	end)
end

function PlotService.init()
	-- Reuse the plots already in the scene (the Studio draft); build them only
	-- if the place has none.
	local folder = Workspace:FindFirstChild("Plots")
	if not folder then
		folder = PlotLayout.buildAll(Workspace)
	end

	for plotIndex = 1, PlotLayout.PLOT_COUNT do
		local plot = folder:FindFirstChild("Plot" .. plotIndex) :: Model?
		if plot then
			plots[plotIndex] = plot
			plot:SetAttribute("OwnerUserId", nil)
			wirePrompts(plot)
		end
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		PlotService.release(player)
	end)

	-- Keep the world in sync with data changes driven by rolls and upgrades.
	RollService.Rolled.Event:Connect(function(player: Player)
		PlotService.refresh(player)
	end)
	UpgradeService.Purchased.Event:Connect(function(player: Player)
		PlotService.refresh(player)
	end)

	startCooldownDisplay()
end

return PlotService
