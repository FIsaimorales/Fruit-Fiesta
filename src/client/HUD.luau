--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local UITheme = require(script.Parent.UITheme)
local UIEffects = require(script.Parent.UIEffects)

export type Plant = GameConfig.Plant
export type PlayerData = GameConfig.PlayerData

export type HUDInstance = {
	onOpenEgg: (() -> ())?,
	onPlacePlant: ((inventoryIndex: number, slotIndex: number) -> ())?,
	onRemovePlant: ((slotIndex: number) -> ())?,
	onAutoEquip: (() -> ())?,
	updateFull: (data: PlayerData & { incomePerSecond: number? }) -> (),
	updateCoins: (coins: number, income: number) -> (),
	showGachaReveal: (plant: Plant) -> (),
}

local HUD = {}

function HUD.create(player: Player): HUDInstance
	local self: HUDInstance = {
		onOpenEgg = nil,
		onPlacePlant = nil,
		onRemovePlant = nil,
		onAutoEquip = nil,
		updateFull = function() end,
		updateCoins = function() end,
		showGachaReveal = function() end,
	}

	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	-- Limpiar instancias previas si existen
	local existing = playerGui:FindFirstChild("FruitGardenHUD")
	if existing then
		existing:Destroy()
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "FruitGardenHUD"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 10
	screen.Parent = playerGui

	-- Datos de estado en cliente
	local currentCoins = 0
	local currentIncome = 0
	local currentData: PlayerData = {
		coins = 0,
		plants = {},
		plot = {},
		rebirths = 0,
	}

	-- ── 1. BARRA SUPERIOR: PÍLDORA DE MONEDAS Y TICKER ─────────────────────────

	local topBarContainer = Instance.new("Frame")
	topBarContainer.Size = UDim2.new(0, 320, 0, 60)
	topBarContainer.Position = UDim2.new(0.5, 0, 0, 35)
	topBarContainer.AnchorPoint = Vector2.new(0.5, 0)
	topBarContainer.BackgroundTransparency = 1
	topBarContainer.Parent = screen

	local coinPill = Instance.new("Frame")
	coinPill.Size = UDim2.new(1, 0, 1, 0)
	coinPill.BackgroundColor3 = Color3.fromRGB(25, 28, 40)
	coinPill.Parent = topBarContainer
	UITheme.addCorner(coinPill, 20)
	UITheme.addStroke(coinPill, Color3.fromRGB(245, 180, 40), 3)
	UITheme.addGradient(coinPill, Color3.fromRGB(35, 40, 58), Color3.fromRGB(18, 20, 30))

	-- Icono de moneda 🪙
	local coinIcon = Instance.new("TextLabel")
	coinIcon.Size = UDim2.new(0, 44, 0, 44)
	coinIcon.Position = UDim2.new(0, 8, 0.5, 0)
	coinIcon.AnchorPoint = Vector2.new(0, 0.5)
	coinIcon.BackgroundTransparency = 1
	coinIcon.Text = "🪙"
	coinIcon.TextSize = 28
	coinIcon.Parent = coinPill

	-- Texto de monedas
	local coinsLabel = Instance.new("TextLabel")
	coinsLabel.Size = UDim2.new(0.55, 0, 0.5, 0)
	coinsLabel.Position = UDim2.new(0, 54, 0.1, 0)
	coinsLabel.BackgroundTransparency = 1
	coinsLabel.Text = "$0"
	coinsLabel.TextColor3 = Color3.fromRGB(255, 230, 80)
	coinsLabel.Font = UITheme.FontTitle
	coinsLabel.TextSize = 22
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
	coinsLabel.Parent = coinPill

	-- Insignia de Ingreso por segundo (+$X/s)
	local incomeBadge = Instance.new("Frame")
	incomeBadge.Size = UDim2.new(0, 105, 0, 24)
	incomeBadge.Position = UDim2.new(1, -12, 0.5, 0)
	incomeBadge.AnchorPoint = Vector2.new(1, 0.5)
	incomeBadge.BackgroundColor3 = Color3.fromRGB(30, 140, 50)
	incomeBadge.Parent = coinPill
	UITheme.addCorner(incomeBadge, 12)
	UITheme.addStroke(incomeBadge, Color3.fromRGB(60, 220, 90), 2)
	UITheme.addGradient(incomeBadge, Color3.fromRGB(50, 190, 70), Color3.fromRGB(20, 110, 40))

	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Size = UDim2.new(1, 0, 1, 0)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.Text = "+$0/s"
	incomeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	incomeLabel.Font = UITheme.FontBold
	incomeLabel.TextSize = 12
	incomeLabel.Parent = incomeBadge

	-- ── 2. TELÓN DE FONDO (BACKDROP PARA MODALES) ─────────────────────────────

	local modalBackdrop = Instance.new("TextButton")
	modalBackdrop.Size = UDim2.new(1, 0, 1, 0)
	modalBackdrop.BackgroundColor3 = Color3.fromRGB(5, 5, 10)
	modalBackdrop.BackgroundTransparency = 1
	modalBackdrop.Text = ""
	modalBackdrop.AutoButtonColor = false
	modalBackdrop.Visible = false
	modalBackdrop.ZIndex = 20
	modalBackdrop.Parent = screen

	local activeModal: GuiObject? = nil

	local function closeCurrentModal()
		if activeModal then
			UIEffects.closeModal(activeModal, modalBackdrop, function()
				activeModal = nil
			end)
		end
	end

	modalBackdrop.MouseButton1Click:Connect(closeCurrentModal)

	local function switchModal(newModal: GuiObject)
		if activeModal == newModal then
			closeCurrentModal()
			return
		end
		if activeModal then
			activeModal.Visible = false
		end
		activeModal = newModal
		UIEffects.openModal(newModal, modalBackdrop)
	end

	-- ── 3. BARRA DE NAVEGACIÓN DOCK INFERIOR (ESTILO SIMULATOR 2026) ───────────

	local dockFrame = Instance.new("Frame")
	dockFrame.Size = UDim2.new(0, 390, 0, 72)
	dockFrame.Position = UDim2.new(0.5, 0, 1, -16)
	dockFrame.AnchorPoint = Vector2.new(0.5, 1)
	dockFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 34)
	dockFrame.Parent = screen
	UITheme.addCorner(dockFrame, 22)
	UITheme.addStroke(dockFrame, Color3.fromRGB(60, 68, 95), 3)
	UITheme.addGradient(dockFrame, Color3.fromRGB(30, 34, 52), Color3.fromRGB(15, 17, 26))

	local dockLayout = Instance.new("UIListLayout")
	dockLayout.FillDirection = Enum.FillDirection.Horizontal
	dockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dockLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	dockLayout.Padding = UDim.new(0, 10)
	dockLayout.Parent = dockFrame

	local function createDockButton(icon: string, label: string, topColor: Color3, bottomColor: Color3, strokeColor: Color3): TextButton
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 84, 0, 56)
		btn.BackgroundColor3 = bottomColor
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.Parent = dockFrame
		UITheme.addCorner(btn, 14)
		UITheme.addStroke(btn, strokeColor, 2.5)
		UITheme.addGradient(btn, topColor, bottomColor)
		UIEffects.applyButtonBounce(btn)

		local iconLabel = Instance.new("TextLabel")
		iconLabel.Size = UDim2.new(1, 0, 0.55, 0)
		iconLabel.Position = UDim2.new(0, 0, 0.05, 0)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Text = icon
		iconLabel.TextSize = 22
		iconLabel.Parent = btn

		local textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.new(1, 0, 0.35, 0)
		textLabel.Position = UDim2.new(0, 0, 0.6, 0)
		textLabel.BackgroundTransparency = 1
		textLabel.Text = label
		textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		textLabel.Font = UITheme.FontBold
		textLabel.TextSize = 11
		textLabel.Parent = btn

		return btn
	end

	local eggDockBtn = createDockButton("🥚", "HUEVOS", Color3.fromRGB(255, 170, 40), Color3.fromRGB(200, 100, 15), Color3.fromRGB(150, 70, 10))
	local plotDockBtn = createDockButton("🌱", "JARDÍN", Color3.fromRGB(70, 220, 90), Color3.fromRGB(25, 140, 45), Color3.fromRGB(15, 90, 30))
	local invDockBtn = createDockButton("🎒", "MOCHILA", Color3.fromRGB(80, 160, 255), Color3.fromRGB(30, 90, 210), Color3.fromRGB(15, 55, 140))
	local statsDockBtn = createDockButton("🏆", "STATS", Color3.fromRGB(210, 100, 255), Color3.fromRGB(130, 40, 200), Color3.fromRGB(85, 20, 135))

	-- ── 4. VENTANA MODAL BASE (HELPER) ────────────────────────────────────────

	local function createModalFrame(titleText: string, width: number, height: number): (Frame, TextButton)
		local modal = Instance.new("Frame")
		modal.Size = UDim2.new(0, width, 0, height)
		modal.Position = UDim2.new(0.5, 0, 0.5, -20)
		modal.AnchorPoint = Vector2.new(0.5, 0.5)
		modal.BackgroundColor3 = Color3.fromRGB(22, 25, 38)
		modal.Visible = false
		modal.ZIndex = 25
		modal.Parent = screen
		UITheme.addCorner(modal, 20)
		UITheme.addStroke(modal, Color3.fromRGB(75, 85, 120), 3.5)
		UITheme.addGradient(modal, Color3.fromRGB(32, 36, 54), Color3.fromRGB(18, 20, 32))

		-- Header
		local header = Instance.new("Frame")
		header.Size = UDim2.new(1, 0, 0, 48)
		header.BackgroundColor3 = Color3.fromRGB(30, 34, 50)
		header.Parent = modal
		UITheme.addCorner(header, 18)
		UITheme.addGradient(header, Color3.fromRGB(45, 52, 78), Color3.fromRGB(25, 28, 42))

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, -60, 1, 0)
		title.Position = UDim2.new(0, 20, 0, 0)
		title.BackgroundTransparency = 1
		title.Text = titleText
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.Font = UITheme.FontTitle
		title.TextSize = 18
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = header

		-- Botón cerrar
		local closeBtn = Instance.new("TextButton")
		closeBtn.Size = UDim2.new(0, 32, 0, 32)
		closeBtn.Position = UDim2.new(1, -40, 0.5, 0)
		closeBtn.AnchorPoint = Vector2.new(0, 0.5)
		closeBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 60)
		closeBtn.Text = "✕"
		closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		closeBtn.Font = UITheme.FontBlack or Enum.Font.GothamBold
		closeBtn.TextSize = 16
		closeBtn.AutoButtonColor = false
		closeBtn.Parent = header
		UITheme.addCorner(closeBtn, 10)
		UITheme.addStroke(closeBtn, Color3.fromRGB(150, 25, 35), 2)
		UIEffects.applyButtonBounce(closeBtn)

		closeBtn.MouseButton1Click:Connect(closeCurrentModal)

		return modal, closeBtn
	end

	-- ── 5. MODAL: TIENDA DE HUEVOS (EGG SHOP) ──────────────────────────────────

	local eggModal = createModalFrame("🥚 TIENDA DE HUEVOS", 380, 420)

	local eggCard = Instance.new("Frame")
	eggCard.Size = UDim2.new(1, -30, 0, 160)
	eggCard.Position = UDim2.new(0, 15, 0, 60)
	eggCard.BackgroundColor3 = Color3.fromRGB(30, 35, 52)
	eggCard.Parent = eggModal
	UITheme.addCorner(eggCard, 16)
	UITheme.addStroke(eggCard, Color3.fromRGB(245, 180, 40), 2.5)

	local eggBigIcon = Instance.new("TextLabel")
	eggBigIcon.Size = UDim2.new(0, 80, 0, 80)
	eggBigIcon.Position = UDim2.new(0.5, 0, 0.35, 0)
	eggBigIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	eggBigIcon.BackgroundTransparency = 1
	eggBigIcon.Text = "🥚"
	eggBigIcon.TextSize = 56
	eggBigIcon.Parent = eggCard

	local eggTitle = Instance.new("TextLabel")
	eggTitle.Size = UDim2.new(1, 0, 0, 24)
	eggTitle.Position = UDim2.new(0, 0, 0.72, 0)
	eggTitle.BackgroundTransparency = 1
	eggTitle.Text = "Huevo Frutal Básico"
	eggTitle.TextColor3 = Color3.fromRGB(255, 230, 100)
	eggTitle.Font = UITheme.FontTitle
	eggTitle.TextSize = 16
	eggTitle.Parent = eggCard

	-- Vista previa de probabilidades
	local oddsContainer = Instance.new("Frame")
	oddsContainer.Size = UDim2.new(1, -30, 0, 110)
	oddsContainer.Position = UDim2.new(0, 15, 0, 230)
	oddsContainer.BackgroundColor3 = Color3.fromRGB(25, 28, 42)
	oddsContainer.Parent = eggModal
	UITheme.addCorner(oddsContainer, 14)

	local oddsTitle = Instance.new("TextLabel")
	oddsTitle.Size = UDim2.new(1, 0, 0, 22)
	oddsTitle.Position = UDim2.new(0, 0, 0, 4)
	oddsTitle.BackgroundTransparency = 1
	oddsTitle.Text = "PROBABILIDADES DE RAREZA"
	oddsTitle.TextColor3 = Color3.fromRGB(180, 190, 215)
	oddsTitle.Font = UITheme.FontBold
	oddsTitle.TextSize = 11
	oddsTitle.Parent = oddsContainer

	local oddsGrid = Instance.new("UIGridLayout")
	oddsGrid.CellSize = UDim2.new(0.31, 0, 0.34, 0)
	oddsGrid.CellPadding = UDim2.new(0.02, 0, 0.04, 0)
	oddsGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	oddsGrid.VerticalAlignment = Enum.VerticalAlignment.Center
	oddsGrid.Parent = oddsContainer

	local oddsPadding = Instance.new("UIPadding")
	oddsPadding.PaddingTop = UDim.new(0, 26)
	oddsPadding.Parent = oddsContainer

	local rarityBadges: { string } = { "Común 50%", "Poco C. 25%", "Raro 13%", "Épico 7%", "Legend. 4%", "Mítico 1%" }
	for id, text in rarityBadges do
		local style = UITheme.getRarityStyle(id)
		local badge = Instance.new("Frame")
		badge.BackgroundColor3 = style.badgeColor
		badge.Parent = oddsContainer
		UITheme.addCorner(badge, 8)

		local badgeText = Instance.new("TextLabel")
		badgeText.Size = UDim2.new(1, 0, 1, 0)
		badgeText.BackgroundTransparency = 1
		badgeText.Text = text
		badgeText.TextColor3 = Color3.fromRGB(255, 255, 255)
		badgeText.Font = UITheme.FontBold
		badgeText.TextSize = 10
		badgeText.Parent = badge
	end

	-- Botón grande de comprar huevo
	local buyEggBtn = Instance.new("TextButton")
	buyEggBtn.Size = UDim2.new(1, -30, 0, 50)
	buyEggBtn.Position = UDim2.new(0, 15, 1, -62)
	buyEggBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 70)
	buyEggBtn.Text = "🥚 ABRIR POR $" .. GameConfig.EGG_COST
	buyEggBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyEggBtn.Font = UITheme.FontTitle
	buyEggBtn.TextSize = 18
	buyEggBtn.AutoButtonColor = false
	buyEggBtn.Parent = eggModal
	UITheme.addCorner(buyEggBtn, 16)
	UITheme.addStroke(buyEggBtn, Color3.fromRGB(20, 110, 40), 3)
	UITheme.addGradient(buyEggBtn, Color3.fromRGB(60, 210, 95), Color3.fromRGB(30, 150, 60))
	UIEffects.applyButtonBounce(buyEggBtn)

	buyEggBtn.MouseButton1Click:Connect(function()
		if currentCoins < GameConfig.EGG_COST then
			UIEffects.playSound("Error")
			UIEffects.spawnFloatingText(screen, "¡Monedas Insuficientes!", UDim2.new(0.5, 0, 0.5, 0), Color3.fromRGB(255, 80, 80), 24)
			return
		end
		if self.onOpenEgg then
			self.onOpenEgg()
		end
	end)

	eggDockBtn.MouseButton1Click:Connect(function()
		switchModal(eggModal)
	end)

	-- ── 6. MODAL: JARDÍN (PLOT MACETAS) ────────────────────────────────────────

	local plotModal = createModalFrame("🌱 MI JARDÍN (MACETAS)", 440, 420)

	local plotGridContainer = Instance.new("Frame")
	plotGridContainer.Size = UDim2.new(1, -24, 1, -66)
	plotGridContainer.Position = UDim2.new(0, 12, 0, 56)
	plotGridContainer.BackgroundTransparency = 1
	plotGridContainer.Parent = plotModal

	local plotGridLayout = Instance.new("UIGridLayout")
	plotGridLayout.CellSize = UDim2.new(0.184, 0, 0.46, 0)
	plotGridLayout.CellPadding = UDim2.new(0.02, 0, 0.06, 0)
	plotGridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	plotGridLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	plotGridLayout.Parent = plotGridContainer

	local plotSlotCards: { TextButton } = {}

	for slotIdx = 1, GameConfig.PLOT_SIZE do
		local slotCard = Instance.new("TextButton")
		slotCard.BackgroundColor3 = Color3.fromRGB(30, 36, 52)
		slotCard.Text = ""
		slotCard.AutoButtonColor = false
		slotCard.Parent = plotGridContainer
		UITheme.addCorner(slotCard, 12)
		UITheme.addStroke(slotCard, Color3.fromRGB(60, 70, 95), 2)
		UIEffects.applyButtonBounce(slotCard)

		local iconLbl = Instance.new("TextLabel")
		iconLbl.Name = "Icon"
		iconLbl.Size = UDim2.new(1, 0, 0.45, 0)
		iconLbl.Position = UDim2.new(0, 0, 0.05, 0)
		iconLbl.BackgroundTransparency = 1
		iconLbl.Text = "🪴"
		iconLbl.TextSize = 26
		iconLbl.Parent = slotCard

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Name = "FruitName"
		nameLbl.Size = UDim2.new(1, -4, 0.25, 0)
		nameLbl.Position = UDim2.new(0, 2, 0.48, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = "Vacío"
		nameLbl.TextColor3 = Color3.fromRGB(180, 190, 210)
		nameLbl.Font = UITheme.FontBold
		nameLbl.TextSize = 10
		nameLbl.Parent = slotCard

		local subLbl = Instance.new("TextLabel")
		subLbl.Name = "SubInfo"
		subLbl.Size = UDim2.new(1, -4, 0.22, 0)
		subLbl.Position = UDim2.new(0, 2, 0.74, 0)
		subLbl.BackgroundTransparency = 1
		subLbl.Text = "(" .. slotIdx .. ")"
		subLbl.TextColor3 = Color3.fromRGB(120, 130, 150)
		subLbl.Font = UITheme.FontMedium
		subLbl.TextSize = 9
		subLbl.Parent = slotCard

		local currentIdx = slotIdx
		slotCard.MouseButton1Click:Connect(function()
			local slot = currentData.plot[currentIdx]
			if slot and type(slot) == "table" then
				if self.onRemovePlant then
					self.onRemovePlant(currentIdx)
					UIEffects.playSound("Pop")
				end
			else
				-- Si está vacío, abrir inventario para plantar
				switchModal(invModal)
			end
		end)

		plotSlotCards[slotIdx] = slotCard
	end

	plotDockBtn.MouseButton1Click:Connect(function()
		switchModal(plotModal)
	end)

	-- ── 7. MODAL: MOCHILA / INVENTARIO ─────────────────────────────────────────

	local invModal = createModalFrame("🎒 MOCHILA DE FRUTAS", 440, 450)

	-- Subheader con Auto-Equipar
	local invTopBar = Instance.new("Frame")
	invTopBar.Size = UDim2.new(1, -24, 0, 42)
	invTopBar.Position = UDim2.new(0, 12, 0, 54)
	invTopBar.BackgroundColor3 = Color3.fromRGB(28, 32, 48)
	invTopBar.Parent = invModal
	UITheme.addCorner(invTopBar, 12)

	local invCountLabel = Instance.new("TextLabel")
	invCountLabel.Size = UDim2.new(0.4, 0, 1, 0)
	invCountLabel.Position = UDim2.new(0, 12, 0, 0)
	invCountLabel.BackgroundTransparency = 1
	invCountLabel.Text = "Frutas: 0"
	invCountLabel.TextColor3 = Color3.fromRGB(200, 210, 235)
	invCountLabel.Font = UITheme.FontBold
	invCountLabel.TextSize = 13
	invCountLabel.TextXAlignment = Enum.TextXAlignment.Left
	invCountLabel.Parent = invTopBar

	local autoEquipBtn = Instance.new("TextButton")
	autoEquipBtn.Size = UDim2.new(0, 160, 0, 32)
	autoEquipBtn.Position = UDim2.new(1, -170, 0.5, 0)
	autoEquipBtn.AnchorPoint = Vector2.new(0, 0.5)
	autoEquipBtn.BackgroundColor3 = Color3.fromRGB(240, 150, 30)
	autoEquipBtn.Text = "⚡ EQUIPAR MEJORES"
	autoEquipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	autoEquipBtn.Font = UITheme.FontTitle
	autoEquipBtn.TextSize = 11
	autoEquipBtn.AutoButtonColor = false
	autoEquipBtn.Parent = invTopBar
	UITheme.addCorner(autoEquipBtn, 10)
	UITheme.addStroke(autoEquipBtn, Color3.fromRGB(160, 80, 10), 2)
	UITheme.addGradient(autoEquipBtn, Color3.fromRGB(255, 180, 50), Color3.fromRGB(210, 110, 15))
	UIEffects.applyButtonBounce(autoEquipBtn)

	autoEquipBtn.MouseButton1Click:Connect(function()
		if self.onAutoEquip then
			self.onAutoEquip()
			UIEffects.playSound("Fanfare")
			UIEffects.spawnFloatingText(screen, "¡Mejores Frutas Plantadas!", UDim2.new(0.5, 0, 0.5, 0), Color3.fromRGB(255, 220, 80), 22)
		end
	end)

	local invScroll = Instance.new("ScrollingFrame")
	invScroll.Size = UDim2.new(1, -24, 1, -112)
	invScroll.Position = UDim2.new(0, 12, 0, 102)
	invScroll.BackgroundColor3 = Color3.fromRGB(22, 25, 38)
	invScroll.BackgroundTransparency = 0.5
	invScroll.BorderSizePixel = 0
	invScroll.ScrollBarThickness = 5
	invScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	invScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	invScroll.Parent = invModal
	UITheme.addCorner(invScroll, 12)

	local invGridLayout = Instance.new("UIGridLayout")
	invGridLayout.CellSize = UDim2.new(0, 94, 0, 105)
	invGridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
	invGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	invGridLayout.Parent = invScroll

	local invScrollPadding = Instance.new("UIPadding")
	invScrollPadding.PaddingTop = UDim.new(0, 6)
	invScrollPadding.PaddingLeft = UDim.new(0, 6)
	invScrollPadding.PaddingRight = UDim.new(0, 6)
	invScrollPadding.PaddingBottom = UDim.new(0, 6)
	invScrollPadding.Parent = invScroll

	local inventoryCards: { Frame } = {}

	invDockBtn.MouseButton1Click:Connect(function()
		switchModal(invModal)
	end)

	-- ── 8. MODAL: ESTADÍSTICAS (STATS) ────────────────────────────────────────

	local statsModal = createModalFrame("🏆 TUS ESTADÍSTICAS", 380, 360)

	local statsContainer = Instance.new("Frame")
	statsContainer.Size = UDim2.new(1, -30, 1, -70)
	statsContainer.Position = UDim2.new(0, 15, 0, 56)
	statsContainer.BackgroundTransparency = 1
	statsContainer.Parent = statsModal

	local statsLayout = Instance.new("UIListLayout")
	statsLayout.Padding = UDim.new(0, 8)
	statsLayout.Parent = statsContainer

	local function makeStatRow(icon: string, title: string, initialVal: string): TextLabel
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 48)
		row.BackgroundColor3 = Color3.fromRGB(28, 32, 48)
		row.Parent = statsContainer
		UITheme.addCorner(row, 12)
		UITheme.addStroke(row, Color3.fromRGB(60, 68, 95), 1.5)

		local iconLbl = Instance.new("TextLabel")
		iconLbl.Size = UDim2.new(0, 40, 1, 0)
		iconLbl.BackgroundTransparency = 1
		iconLbl.Text = icon
		iconLbl.TextSize = 22
		iconLbl.Parent = row

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(0.5, 0, 1, 0)
		nameLbl.Position = UDim2.new(0, 44, 0, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = title
		nameLbl.TextColor3 = Color3.fromRGB(200, 210, 235)
		nameLbl.Font = UITheme.FontBold
		nameLbl.TextSize = 13
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.Parent = row

		local valLbl = Instance.new("TextLabel")
		valLbl.Size = UDim2.new(0.4, 0, 1, 0)
		valLbl.Position = UDim2.new(1, -12, 0, 0)
		valLbl.AnchorPoint = Vector2.new(1, 0)
		valLbl.BackgroundTransparency = 1
		valLbl.Text = initialVal
		valLbl.TextColor3 = Color3.fromRGB(255, 230, 90)
		valLbl.Font = UITheme.FontTitle
		valLbl.TextSize = 14
		valLbl.TextXAlignment = Enum.TextXAlignment.Right
		valLbl.Parent = row

		return valLbl
	end

	local statIncomeVal = makeStatRow("⚡", "Ingreso Total", "+$0/s")
	local statPlantedVal = makeStatRow("🌱", "Frutas Plantadas", "0 / 10")
	local statBackpackVal = makeStatRow("🎒", "Frutas en Mochila", "0")
	local statCoinsVal = makeStatRow("🪙", "Monedas Actuales", "$0")

	statsDockBtn.MouseButton1Click:Connect(function()
		switchModal(statsModal)
	end)

	-- ── 9. CINEMÁTICA DE APERTURA DE HUEVOS (GACHA REVEAL MODAL) ───────────────

	local gachaOverlay = Instance.new("Frame")
	gachaOverlay.Size = UDim2.new(1, 0, 1, 0)
	gachaOverlay.BackgroundColor3 = Color3.fromRGB(5, 7, 15)
	gachaOverlay.BackgroundTransparency = 0.15
	gachaOverlay.Visible = false
	gachaOverlay.ZIndex = 100
	gachaOverlay.Parent = screen

	local gachaCard = Instance.new("Frame")
	gachaCard.Size = UDim2.new(0, 320, 0, 420)
	gachaCard.Position = UDim2.new(0.5, 0, 0.5, 0)
	gachaCard.AnchorPoint = Vector2.new(0.5, 0.5)
	gachaCard.BackgroundColor3 = Color3.fromRGB(26, 30, 46)
	gachaCard.ZIndex = 105
	gachaCard.Parent = gachaOverlay
	UITheme.addCorner(gachaCard, 24)
	local gachaStroke = UITheme.addStroke(gachaCard, Color3.fromRGB(255, 200, 50), 4)

	local gachaHeader = Instance.new("TextLabel")
	gachaHeader.Size = UDim2.new(1, 0, 0, 36)
	gachaHeader.Position = UDim2.new(0, 0, 0, 16)
	gachaHeader.BackgroundTransparency = 1
	gachaHeader.Text = "✨ ¡NUEVA FRUTA DESBLOQUEADA! ✨"
	gachaHeader.TextColor3 = Color3.fromRGB(255, 230, 100)
	gachaHeader.Font = UITheme.FontTitle
	gachaHeader.TextSize = 14
	gachaHeader.ZIndex = 110
	gachaHeader.Parent = gachaCard

	local gachaRarityBanner = Instance.new("Frame")
	gachaRarityBanner.Size = UDim2.new(0, 180, 0, 30)
	gachaRarityBanner.Position = UDim2.new(0.5, 0, 0, 60)
	gachaRarityBanner.AnchorPoint = Vector2.new(0.5, 0)
	gachaRarityBanner.BackgroundColor3 = Color3.fromRGB(240, 160, 30)
	gachaRarityBanner.ZIndex = 110
	gachaRarityBanner.Parent = gachaCard
	UITheme.addCorner(gachaRarityBanner, 15)

	local gachaRarityLabel = Instance.new("TextLabel")
	gachaRarityLabel.Size = UDim2.new(1, 0, 1, 0)
	gachaRarityLabel.BackgroundTransparency = 1
	gachaRarityLabel.Text = "LEGENDARIO"
	gachaRarityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	gachaRarityLabel.Font = UITheme.FontTitle
	gachaRarityLabel.TextSize = 13
	gachaRarityLabel.ZIndex = 112
	gachaRarityLabel.Parent = gachaRarityBanner

	local gachaFruitIcon = Instance.new("TextLabel")
	gachaFruitIcon.Size = UDim2.new(0, 120, 0, 120)
	gachaFruitIcon.Position = UDim2.new(0.5, 0, 0.45, 0)
	gachaFruitIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	gachaFruitIcon.BackgroundTransparency = 1
	gachaFruitIcon.Text = "🍎"
	gachaFruitIcon.TextSize = 80
	gachaFruitIcon.ZIndex = 110
	gachaFruitIcon.Parent = gachaCard

	local gachaFruitName = Instance.new("TextLabel")
	gachaFruitName.Size = UDim2.new(1, 0, 0, 32)
	gachaFruitName.Position = UDim2.new(0, 0, 0.68, 0)
	gachaFruitName.BackgroundTransparency = 1
	gachaFruitName.Text = "Manzana"
	gachaFruitName.TextColor3 = Color3.fromRGB(255, 255, 255)
	gachaFruitName.Font = UITheme.FontTitle
	gachaFruitName.TextSize = 22
	gachaFruitName.ZIndex = 110
	gachaFruitName.Parent = gachaCard

	local gachaIncomeBadge = Instance.new("Frame")
	gachaIncomeBadge.Size = UDim2.new(0, 160, 0, 32)
	gachaIncomeBadge.Position = UDim2.new(0.5, 0, 0.78, 0)
	gachaIncomeBadge.AnchorPoint = Vector2.new(0.5, 0)
	gachaIncomeBadge.BackgroundColor3 = Color3.fromRGB(35, 150, 60)
	gachaIncomeBadge.ZIndex = 110
	gachaIncomeBadge.Parent = gachaCard
	UITheme.addCorner(gachaIncomeBadge, 12)

	local gachaIncomeLabel = Instance.new("TextLabel")
	gachaIncomeLabel.Size = UDim2.new(1, 0, 1, 0)
	gachaIncomeLabel.BackgroundTransparency = 1
	gachaIncomeLabel.Text = "+$10/s"
	gachaIncomeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	gachaIncomeLabel.Font = UITheme.FontBold
	gachaIncomeLabel.TextSize = 15
	gachaIncomeLabel.ZIndex = 112
	gachaIncomeLabel.Parent = gachaIncomeBadge

	local gachaCollectBtn = Instance.new("TextButton")
	gachaCollectBtn.Size = UDim2.new(1, -40, 0, 46)
	gachaCollectBtn.Position = UDim2.new(0.5, 0, 1, -20)
	gachaCollectBtn.AnchorPoint = Vector2.new(0.5, 1)
	gachaCollectBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 75)
	gachaCollectBtn.Text = "¡GENIAL!"
	gachaCollectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	gachaCollectBtn.Font = UITheme.FontTitle
	gachaCollectBtn.TextSize = 18
	gachaCollectBtn.AutoButtonColor = false
	gachaCollectBtn.ZIndex = 115
	gachaCollectBtn.Parent = gachaCard
	UITheme.addCorner(gachaCollectBtn, 14)
	UITheme.addStroke(gachaCollectBtn, Color3.fromRGB(20, 110, 40), 2.5)
	UITheme.addGradient(gachaCollectBtn, Color3.fromRGB(60, 215, 95), Color3.fromRGB(30, 150, 60))
	UIEffects.applyButtonBounce(gachaCollectBtn)

	gachaCollectBtn.MouseButton1Click:Connect(function()
		UIEffects.closeModal(gachaCard, gachaOverlay, function()
			gachaOverlay.Visible = false
		end)
	end)

	self.showGachaReveal = function(plant: Plant)
		local rarity = GameConfig.getRarity(plant.rarityId)
		local income = GameConfig.getIncome(plant.speciesName, plant.rarityId)
		local style = UITheme.getRarityStyle(plant.rarityId)
		local icon = UITheme.getSpeciesIcon(plant.speciesName)

		gachaFruitIcon.Text = icon
		gachaFruitName.Text = plant.speciesName
		gachaRarityLabel.Text = string.upper(rarity and rarity.name or "COMÚN")
		gachaRarityBanner.BackgroundColor3 = style.badgeColor
		gachaStroke.Color = style.strokeColor
		gachaIncomeLabel.Text = NumberFormat.formatIncome(income)

		gachaOverlay.Visible = true
		gachaOverlay.BackgroundTransparency = 0.2
		UIEffects.openModal(gachaCard)

		if plant.rarityId >= 4 then
			UIEffects.playSound("GachaRare")
		else
			UIEffects.playSound("EggCrack")
		end
	end

	-- ── 10. MÉTODOS DE ACTUALIZACIÓN DEL ESTADO ─────────────────────────────────

	self.updateCoins = function(coins: number, income: number)
		currentCoins = coins
		currentIncome = income
		coinsLabel.Text = NumberFormat.formatMoney(coins)
		incomeLabel.Text = NumberFormat.formatIncome(income)
		statCoinsVal.Text = NumberFormat.formatMoney(coins)
		statIncomeVal.Text = NumberFormat.formatIncome(income)

		-- Color del botón de huevo según asequibilidad
		buyEggBtn.BackgroundColor3 = coins >= GameConfig.EGG_COST
			and Color3.fromRGB(40, 180, 70)
			or Color3.fromRGB(75, 80, 95)
	end

	self.updateFull = function(data: PlayerData & { incomePerSecond: number? })
		currentData = data
		self.updateCoins(data.coins, data.incomePerSecond or 0)

		-- Actualizar Slots del Jardín
		local occupiedCount = 0
		for i = 1, GameConfig.PLOT_SIZE do
			local slot = data.plot[i]
			local card = plotSlotCards[i]
			local iconLbl = card:FindFirstChild("Icon") :: TextLabel
			local nameLbl = card:FindFirstChild("FruitName") :: TextLabel
			local subLbl = card:FindFirstChild("SubInfo") :: TextLabel

			if slot and type(slot) == "table" then
				occupiedCount += 1
				local style = UITheme.getRarityStyle(slot.rarityId)
				local incomeVal = GameConfig.getIncome(slot.speciesName, slot.rarityId)
				local icon = UITheme.getSpeciesIcon(slot.speciesName)

				card.BackgroundColor3 = style.badgeColor
				iconLbl.Text = icon
				nameLbl.Text = slot.speciesName
				nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
				subLbl.Text = string.format("+$%s/s", NumberFormat.formatMoney(incomeVal):gsub("%$", ""))
				subLbl.TextColor3 = Color3.fromRGB(255, 255, 200)
			else
				card.BackgroundColor3 = Color3.fromRGB(30, 36, 52)
				iconLbl.Text = "🪴"
				nameLbl.Text = "Vacío"
				nameLbl.TextColor3 = Color3.fromRGB(160, 170, 190)
				subLbl.Text = "(Toca para +)"
				subLbl.TextColor3 = Color3.fromRGB(110, 120, 140)
			end
		end

		statPlantedVal.Text = string.format("%d / %d", occupiedCount, GameConfig.PLOT_SIZE)
		statBackpackVal.Text = tostring(#data.plants)
		invCountLabel.Text = string.format("Frutas: %d", #data.plants)

		-- Actualizar Lista de Mochila / Inventario
		for _, card in inventoryCards do
			card:Destroy()
		end
		table.clear(inventoryCards)

		for idx, plant in data.plants do
			local style = UITheme.getRarityStyle(plant.rarityId)
			local income = GameConfig.getIncome(plant.speciesName, plant.rarityId)
			local icon = UITheme.getSpeciesIcon(plant.speciesName)

			local itemCard = Instance.new("Frame")
			itemCard.BackgroundColor3 = Color3.fromRGB(28, 32, 48)
			itemCard.Parent = invScroll
			UITheme.addCorner(itemCard, 12)
			UITheme.addStroke(itemCard, style.strokeColor, 2)

			local itemIcon = Instance.new("TextLabel")
			itemIcon.Size = UDim2.new(1, 0, 0.42, 0)
			itemIcon.Position = UDim2.new(0, 0, 0.04, 0)
			itemIcon.BackgroundTransparency = 1
			itemIcon.Text = icon
			itemIcon.TextSize = 28
			itemIcon.Parent = itemCard

			local itemName = Instance.new("TextLabel")
			itemName.Size = UDim2.new(1, -4, 0.2, 0)
			itemName.Position = UDim2.new(0, 2, 0.44, 0)
			itemName.BackgroundTransparency = 1
			itemName.Text = plant.speciesName
			itemName.TextColor3 = Color3.fromRGB(255, 255, 255)
			itemName.Font = UITheme.FontBold
			itemName.TextSize = 10
			itemName.Parent = itemCard

			local itemIncome = Instance.new("TextLabel")
			itemIncome.Size = UDim2.new(1, -4, 0.16, 0)
			itemIncome.Position = UDim2.new(0, 2, 0.62, 0)
			itemIncome.BackgroundTransparency = 1
			itemIncome.Text = NumberFormat.formatIncome(income)
			itemIncome.TextColor3 = Color3.fromRGB(120, 255, 120)
			itemIncome.Font = UITheme.FontBold
			itemIncome.TextSize = 9
			itemIncome.Parent = itemCard

			local plantBtn = Instance.new("TextButton")
			plantBtn.Size = UDim2.new(1, -8, 0, 18)
			plantBtn.Position = UDim2.new(0, 4, 1, -22)
			plantBtn.BackgroundColor3 = Color3.fromRGB(40, 170, 70)
			plantBtn.Text = "PLANTAR"
			plantBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			plantBtn.Font = UITheme.FontTitle
			plantBtn.TextSize = 9
			plantBtn.AutoButtonColor = false
			plantBtn.Parent = itemCard
			UITheme.addCorner(plantBtn, 6)
			UIEffects.applyButtonBounce(plantBtn)

			local currentInventoryIdx = idx
			plantBtn.MouseButton1Click:Connect(function()
				for s = 1, GameConfig.PLOT_SIZE do
					local slot = data.plot[s]
					if not slot or slot == false then
						if self.onPlacePlant then
							self.onPlacePlant(currentInventoryIdx, s)
							UIEffects.playSound("Pop")
						end
						return
					end
				end
				UIEffects.playSound("Error")
				UIEffects.spawnFloatingText(screen, "¡El jardín está lleno!", UDim2.new(0.5, 0, 0.5, 0), Color3.fromRGB(255, 80, 80), 22)
			end)

			table.insert(inventoryCards, itemCard)
		end
	end

	return self
end

return HUD
