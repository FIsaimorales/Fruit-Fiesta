--!strict
local _Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)

export type Plant = GameConfig.Plant
export type PlayerData = GameConfig.PlayerData

export type HUDInstance = {
	onOpenEgg: (() -> ())?,
	onPlacePlant: ((inventoryIndex: number, slotIndex: number) -> ())?,
	onRemovePlant: ((slotIndex: number) -> ())?,
	updateFull: (data: PlayerData & { incomePerSecond: number? }) -> (),
	updateCoins: (coins: number, income: number) -> (),
}

local HUD = {}

-- Rarity colors for UI
local RARITY_COLORS = {
	Color3.fromRGB(190, 190, 190), -- 1: Común (gray)
	Color3.fromRGB(100, 210, 100), -- 2: Poco común (green)
	Color3.fromRGB(70, 150, 255),  -- 3: Raro (blue)
	Color3.fromRGB(180, 80, 255),  -- 4: Épico (purple)
	Color3.fromRGB(255, 180, 40),  -- 5: Legendario (gold)
	Color3.fromRGB(255, 60, 60),   -- 6: Mítico (red)
}

local function rarityColor(id: number): Color3
	return RARITY_COLORS[id] or Color3.fromRGB(255, 255, 255)
end

local function makeLabel(parent: Instance, text: string, size: UDim2, pos: UDim2, fontSize: number, bold: boolean?): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.Size = size
	lbl.Position = pos
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextScaled = false
	lbl.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	lbl.TextSize = fontSize
	lbl.TextXAlignment = Enum.TextXAlignment.Center
	lbl.Parent = parent
	return lbl
end

local function makeButton(parent: Instance, text: string, size: UDim2, pos: UDim2, color: Color3): TextButton
	local btn = Instance.new("TextButton")
	btn.Size = size
	btn.Position = pos
	btn.BackgroundColor3 = color
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.AutoButtonColor = true
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn

	return btn
end

function HUD.create(player: Player): HUDInstance
	local self: HUDInstance = {
		onOpenEgg = nil,
		onPlacePlant = nil,
		onRemovePlant = nil,
		updateFull = function() end,
		updateCoins = function() end,
	}

	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	-- Limpiar HUD anterior si existía
	local existing = playerGui:FindFirstChild("FruitGardenHUD")
	if existing then
		existing:Destroy()
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "FruitGardenHUD"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.Parent = playerGui

	-- ── Top bar ──────────────────────────────────────────────────────────────
	local topBar = Instance.new("Frame")
	topBar.Size = UDim2.new(1, 0, 0, 56)
	topBar.Position = UDim2.new(0, 0, 0, 0)
	topBar.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	topBar.BackgroundTransparency = 0.15
	topBar.BorderSizePixel = 0
	topBar.Parent = screen

	local coinsLabel = makeLabel(topBar, "$0", UDim2.new(0.4, 0, 0.6, 0), UDim2.new(0.3, 0, 0.05, 0), 24, true)
	coinsLabel.TextColor3 = Color3.fromRGB(255, 220, 80)

	local incomeLabel = makeLabel(topBar, "+$0/s", UDim2.new(0.4, 0, 0.35, 0), UDim2.new(0.3, 0, 0.6, 0), 13, false)
	incomeLabel.TextColor3 = Color3.fromRGB(120, 255, 120)

	-- ── Egg button ───────────────────────────────────────────────────────────
	local currentCoins = 0

	local eggBtn = makeButton(
		screen,
		"🥚 Abrir Huevo\n$" .. GameConfig.EGG_COST,
		UDim2.new(0, 150, 0, 55),
		UDim2.new(0.5, -75, 1, -75),
		Color3.fromRGB(50, 110, 200)
	)

	-- ── Popup notification system ─────────────────────────────────────────────
	local function showPopup(text: string, color: Color3)
		local popup = Instance.new("TextLabel")
		popup.Size = UDim2.new(0, 240, 0, 36)
		popup.Position = UDim2.new(0.5, -120, 0.45, 0)
		popup.BackgroundTransparency = 1
		popup.Text = text
		popup.TextColor3 = color
		popup.Font = Enum.Font.GothamBold
		popup.TextSize = 20
		popup.TextStrokeTransparency = 0.4
		popup.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		popup.Parent = screen

		local tween = TweenService:Create(
			popup,
			TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Position = UDim2.new(0.5, -120, 0.35, 0),
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}
		)
		tween:Play()
		tween.Completed:Connect(function()
			popup:Destroy()
		end)
	end

	eggBtn.MouseButton1Click:Connect(function()
		if currentCoins < GameConfig.EGG_COST then
			showPopup("¡Monedas insuficientes!", Color3.fromRGB(255, 100, 100))
			return
		end
		if self.onOpenEgg then
			self.onOpenEgg()
		end
	end)

	-- ── Plot grid ────────────────────────────────────────────────────────────
	local plotFrame = Instance.new("Frame")
	plotFrame.Size = UDim2.new(0, 340, 0, 160)
	plotFrame.Position = UDim2.new(0, 15, 0.5, -80)
	plotFrame.BackgroundColor3 = Color3.fromRGB(25, 45, 25)
	plotFrame.BackgroundTransparency = 0.25
	plotFrame.BorderSizePixel = 0
	plotFrame.Parent = screen

	local plotCorner = Instance.new("UICorner")
	plotCorner.CornerRadius = UDim.new(0, 10)
	plotCorner.Parent = plotFrame

	local plotTitle = makeLabel(plotFrame, "🌱 Jardín (Macetas)", UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 2), 13, true)
	plotTitle.TextColor3 = Color3.fromRGB(180, 255, 180)

	local slotButtons: { TextButton } = {}

	for i = 1, GameConfig.PLOT_SIZE do
		local col = (i - 1) % 5
		local row = math.floor((i - 1) / 5)

		local slotBtn = makeButton(
			plotFrame,
			tostring(i),
			UDim2.new(0, 60, 0, 56),
			UDim2.new(0, 8 + col * 66, 0, 28 + row * 62),
			Color3.fromRGB(40, 75, 40)
		)
		slotBtn.TextSize = 10

		local slotIndex = i
		slotBtn.MouseButton1Click:Connect(function()
			if self.onRemovePlant then
				self.onRemovePlant(slotIndex)
			end
		end)

		slotButtons[i] = slotBtn
	end

	-- ── Inventory panel ───────────────────────────────────────────────────────
	local invFrame = Instance.new("ScrollingFrame")
	invFrame.Size = UDim2.new(0, 210, 0.55, -40)
	invFrame.Position = UDim2.new(1, -225, 0, 65)
	invFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	invFrame.BackgroundTransparency = 0.2
	invFrame.BorderSizePixel = 0
	invFrame.ScrollBarThickness = 5
	invFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	invFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	invFrame.Parent = screen

	local invCorner = Instance.new("UICorner")
	invCorner.CornerRadius = UDim.new(0, 10)
	invCorner.Parent = invFrame

	local invTitle = makeLabel(invFrame, "🎒 Inventario", UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 2), 13, true)
	invTitle.TextColor3 = Color3.fromRGB(200, 210, 255)

	local invLayout = Instance.new("UIListLayout")
	invLayout.SortOrder = Enum.SortOrder.LayoutOrder
	invLayout.Padding = UDim.new(0, 4)
	invLayout.Parent = invFrame

	local invPadding = Instance.new("UIPadding")
	invPadding.PaddingTop = UDim.new(0, 26)
	invPadding.PaddingLeft = UDim.new(0, 6)
	invPadding.PaddingRight = UDim.new(0, 6)
	invPadding.PaddingBottom = UDim.new(0, 6)
	invPadding.Parent = invFrame

	local inventoryButtons: { TextButton } = {}
	local cachedPlotState: { [number]: Plant | boolean } = {}
	local lastInventoryCount = -1

	-- Helper to update coins label and egg button
	local function updateCoinDisplay(coins: number, income: number)
		currentCoins = coins
		coinsLabel.Text = NumberFormat.formatMoney(coins)
		incomeLabel.Text = NumberFormat.formatIncome(income)

		eggBtn.BackgroundColor3 = coins >= GameConfig.EGG_COST
			and Color3.fromRGB(50, 110, 200)
			or Color3.fromRGB(75, 75, 85)
	end

	self.updateCoins = function(coins: number, income: number)
		updateCoinDisplay(coins, income)
	end

	self.updateFull = function(data: PlayerData & { incomePerSecond: number? })
		updateCoinDisplay(data.coins, data.incomePerSecond or 0)
		cachedPlotState = data.plot

		-- Update plot slots
		for i = 1, GameConfig.PLOT_SIZE do
			local slot = data.plot[i]
			local btn = slotButtons[i]
			if slot and type(slot) == "table" then
				local rarity = GameConfig.getRarity(slot.rarityId)
				local incomeVal = GameConfig.getIncome(slot.speciesName, slot.rarityId)
				btn.BackgroundColor3 = rarityColor(slot.rarityId)
				btn.Text = string.format("%s\n%s\n+$%d/s", slot.speciesName or "?", rarity and rarity.name or "?", incomeVal)
				btn.TextSize = 8
			else
				btn.BackgroundColor3 = Color3.fromRGB(40, 75, 40)
				btn.Text = "Vacío\n(" .. i .. ")"
				btn.TextSize = 10
			end
		end

		-- Rebuild inventory only when inventory changes (avoids constant GC churn)
		if #data.plants ~= lastInventoryCount then
			for _, b in inventoryButtons do
				b:Destroy()
			end
			table.clear(inventoryButtons)
			lastInventoryCount = #data.plants

			for idx, plant in data.plants do
				local rarity = GameConfig.getRarity(plant.rarityId)
				local income = GameConfig.getIncome(plant.speciesName, plant.rarityId)

				local invBtn = Instance.new("TextButton")
				invBtn.Size = UDim2.new(1, 0, 0, 44)
				invBtn.BackgroundColor3 = rarityColor(plant.rarityId)
				invBtn.BackgroundTransparency = 0.25
				local incomeStr = (NumberFormat.formatMoney(income):gsub("%$", ""))
				invBtn.Text = string.format("%s (%s)\n+$%s/s", plant.speciesName, rarity and rarity.name or "?", incomeStr)
				invBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
				invBtn.Font = Enum.Font.GothamBold
				invBtn.TextSize = 11
				invBtn.AutoButtonColor = true
				invBtn.LayoutOrder = idx
				invBtn.Parent = invFrame

				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 6)
				corner.Parent = invBtn

				local inventoryIndex = idx
				invBtn.MouseButton1Click:Connect(function()
					-- Find first empty slot and place there
					for s = 1, GameConfig.PLOT_SIZE do
						local slot = cachedPlotState[s]
						if not slot or (slot :: any) == false then
							if self.onPlacePlant then
								self.onPlacePlant(inventoryIndex, s)
							end
							return
						end
					end
					showPopup("¡Plot lleno!", Color3.fromRGB(255, 100, 100))
				end)

				table.insert(inventoryButtons, invBtn)
			end
		end
	end

	return self
end

return HUD
