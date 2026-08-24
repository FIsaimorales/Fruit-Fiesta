local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GameConfig = require(game.ReplicatedStorage.Shared.GameConfig)
local NumberFormat = require(game.ReplicatedStorage.Shared.NumberFormat)

local HUD = {}

-- Rarity colors for UI
local RARITY_COLORS = {
	Color3.fromRGB(200, 200, 200),  -- Común (gray)
	Color3.fromRGB(100, 200, 100),  -- Poco común (green)
	Color3.fromRGB(80, 140, 255),   -- Raro (blue)
	Color3.fromRGB(160, 80, 255),   -- Épico (purple)
	Color3.fromRGB(255, 170, 40),   -- Legendario (gold)
	Color3.fromRGB(255, 80, 80),    -- Mítico (red)
}

local function rarityColor(id: number): Color3
	return RARITY_COLORS[id] or Color3.new(1, 1, 1)
end

local function makeLabel(parent: Instance, text: string, size: UDim2, pos: UDim2, fontSize: number, bold: boolean?): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.Size = size
	lbl.Position = pos
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = Color3.new(1, 1, 1)
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
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 16
	btn.AutoButtonColor = true
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn

	return btn
end

-- ── Build GUI ─────────────────────────────────────────────────────────────────

function HUD.create(player: Player)
	local self = {}
	self.onOpenEgg = nil :: (() -> ())?
	self.onPlacePlant = nil :: ((number, number) -> ())?
	self.onRemovePlant = nil :: ((number) -> ())?

	local playerGui = player:WaitForChild("PlayerGui")

	local screen = Instance.new("ScreenGui")
	screen.Name = "FruitGardenHUD"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.Parent = playerGui

	-- ── Top bar ──────────────────────────────────────────────────────────────

	local topBar = Instance.new("Frame")
	topBar.Size = UDim2.new(1, 0, 0, 60)
	topBar.Position = UDim2.new(0, 0, 0, 0)
	topBar.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	topBar.BackgroundTransparency = 0.2
	topBar.BorderSizePixel = 0
	topBar.Parent = screen

	local coinsLabel = makeLabel(topBar, "$0", UDim2.new(0.5, 0, 1, 0), UDim2.new(0.25, 0, 0, 0), 28, true)
	local incomeLabel = makeLabel(topBar, "+$0/s", UDim2.new(0.25, 0, 1, 0), UDim2.new(0.5, 0, 0, 0), 16)
	incomeLabel.TextColor3 = Color3.fromRGB(100, 255, 100)

	-- ── Egg button ───────────────────────────────────────────────────────────

	local eggBtn = makeButton(
		screen,
		"🥚 Abrir Huevo\n$" .. GameConfig.EGG_COST,
		UDim2.new(0, 150, 0, 60),
		UDim2.new(0.5, -75, 1, -80),
		Color3.fromRGB(60, 120, 200)
	)

	eggBtn.MouseButton1Click:Connect(function()
		if self.onOpenEgg then self.onOpenEgg() end
	end)

	-- ── Plot grid ────────────────────────────────────────────────────────────

	local plotFrame = Instance.new("Frame")
	plotFrame.Size = UDim2.new(0, 360, 0, 180)
	plotFrame.Position = UDim2.new(0, 10, 0.5, -90)
	plotFrame.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
	plotFrame.BackgroundTransparency = 0.3
	plotFrame.BorderSizePixel = 0
	plotFrame.Parent = screen

	local plotCorner = Instance.new("UICorner")
	plotCorner.CornerRadius = UDim.new(0, 10)
	plotCorner.Parent = plotFrame

	local plotTitle = makeLabel(plotFrame, "Plot (macetas)", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 0), 14, true)
	plotTitle.TextColor3 = Color3.fromRGB(200, 255, 200)

	local slotButtons: { TextButton } = {}

	for i = 1, GameConfig.PLOT_SIZE do
		local col = (i - 1) % 5
		local row = math.floor((i - 1) / 5)

		local slotBtn = makeButton(
			plotFrame,
			tostring(i),
			UDim2.new(0, 64, 0, 64),
			UDim2.new(0, 8 + col * 70, 0, 28 + row * 72),
			Color3.fromRGB(50, 90, 50)
		)
		slotBtn.TextSize = 11

		local slotIndex = i
		slotBtn.MouseButton1Click:Connect(function()
			-- If slot is occupied → remove plant back to inventory
			if self.onRemovePlant then
				self.onRemovePlant(slotIndex)
			end
		end)

		slotButtons[i] = slotBtn
	end

	-- ── Inventory panel ───────────────────────────────────────────────────────

	local invFrame = Instance.new("ScrollingFrame")
	invFrame.Size = UDim2.new(0, 200, 0.5, -40)
	invFrame.Position = UDim2.new(1, -210, 0, 70)
	invFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
	invFrame.BackgroundTransparency = 0.2
	invFrame.BorderSizePixel = 0
	invFrame.ScrollBarThickness = 4
	invFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	invFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	invFrame.Parent = screen

	local invCorner = Instance.new("UICorner")
	invCorner.CornerRadius = UDim.new(0, 10)
	invCorner.Parent = invFrame

	local invTitle = makeLabel(invFrame, "Inventario", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 0), 13, true)
	invTitle.TextColor3 = Color3.fromRGB(200, 200, 255)

	local invLayout = Instance.new("UIListLayout")
	invLayout.SortOrder = Enum.SortOrder.LayoutOrder
	invLayout.Padding = UDim.new(0, 4)
	invLayout.Parent = invFrame

	local invPadding = Instance.new("UIPadding")
	invPadding.PaddingTop = UDim.new(0, 28)
	invPadding.PaddingLeft = UDim.new(0, 6)
	invPadding.PaddingRight = UDim.new(0, 6)
	invPadding.Parent = invFrame

	local inventoryButtons: { TextButton } = {}

	-- ── Popup text (lucky hit notifications) ─────────────────────────────────

	local function showPopup(text: string, color: Color3)
		local popup = Instance.new("TextLabel")
		popup.Size = UDim2.new(0, 200, 0, 40)
		popup.Position = UDim2.new(0.5, -100, 0.4, 0)
		popup.BackgroundTransparency = 1
		popup.Text = text
		popup.TextColor3 = color
		popup.Font = Enum.Font.GothamBold
		popup.TextSize = 24
		popup.TextStrokeTransparency = 0.5
		popup.Parent = screen

		local tween = TweenService:Create(popup, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, -100, 0.25, 0),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		tween:Play()
		tween.Completed:Connect(function() popup:Destroy() end)
	end

	-- ── Update function called from init.client ───────────────────────────────

	local lastCoins = 0

	function self.update(data)
		-- Animate coins label
		local target = data.coins
		if target ~= lastCoins then
			local tween = TweenService:Create(
				coinsLabel,
				TweenInfo.new(0.4, Enum.EasingStyle.Quad),
				{}
			)
			tween:Play()
			coinsLabel.Text = NumberFormat.formatMoney(target)
			lastCoins = target
		end

		incomeLabel.Text = NumberFormat.formatIncome(data.incomePerSecond or 0)

		-- Update plot slots
		for i = 1, GameConfig.PLOT_SIZE do
			local slot = data.plot[i]
			local btn = slotButtons[i]
			if slot and slot ~= false then
				local species = GameConfig.getSpecies(slot.speciesName)
				local rarity = GameConfig.getRarity(slot.rarityId)
				btn.BackgroundColor3 = rarityColor(slot.rarityId)
				btn.Text = (slot.speciesName or "?") .. "\n" .. (rarity and rarity.name or "?")
				btn.TextSize = 9
			else
				btn.BackgroundColor3 = Color3.fromRGB(50, 90, 50)
				btn.Text = tostring(i)
				btn.TextSize = 11
			end
		end

		-- Rebuild inventory list
		for _, b in inventoryButtons do b:Destroy() end
		table.clear(inventoryButtons)

		for idx, plant in data.plants do
			local rarity = GameConfig.getRarity(plant.rarityId)
			local income = GameConfig.getIncome(plant.speciesName, plant.rarityId)

			local invBtn = Instance.new("TextButton")
			invBtn.Size = UDim2.new(1, 0, 0, 48)
			invBtn.BackgroundColor3 = rarityColor(plant.rarityId)
			invBtn.BackgroundTransparency = 0.3
			invBtn.Text = plant.speciesName .. "\n" .. (rarity and rarity.name or "?") .. " · +" .. NumberFormat.formatMoney(income) .. "/s"
			invBtn.TextColor3 = Color3.new(1, 1, 1)
			invBtn.Font = Enum.Font.Gotham
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
					local slot = data.plot[s]
					if not slot or slot == false then
						if self.onPlacePlant then
							self.onPlacePlant(inventoryIndex, s)
						end
						return
					end
				end
				showPopup("Plot lleno!", Color3.fromRGB(255, 100, 100))
			end)

			table.insert(inventoryButtons, invBtn)
		end

		-- Update egg button color based on affordability
		eggBtn.BackgroundColor3 = data.coins >= GameConfig.EGG_COST
			and Color3.fromRGB(60, 120, 200)
			or Color3.fromRGB(80, 80, 80)
	end

	return self
end

return HUD
