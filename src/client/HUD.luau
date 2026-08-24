--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local UITheme = require(script.Parent.UITheme)
local UIEffects = require(script.Parent.UIEffects)
local SoundManager = require(script.Parent.SoundManager)

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

	-- Limpiar instancias previas
	local existing = playerGui:FindFirstChild("FruitGardenHUD")
	if existing then
		existing:Destroy()
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "FruitGardenHUD"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- Garantiza renderizado jerárquico limpio
	screen.DisplayOrder = 10
	screen.Parent = playerGui

	-- Variables de estado
	local currentCoins = 0
	local currentIncome = 0
	local currentData: PlayerData = {
		coins = 0,
		plants = {},
		plot = {},
		rebirths = 0,
	}

	-- ── 1. BARRA SUPERIOR: PÍLDORA DE MONEDAS ─────────────────────────────────

	local topBarContainer = Instance.new("Frame")
	topBarContainer.Size = UDim2.new(0, 340, 0, 58)
	topBarContainer.Position = UDim2.new(0.5, 0, 0, 36)
	topBarContainer.AnchorPoint = Vector2.new(0.5, 0)
	topBarContainer.BackgroundTransparency = 1
	topBarContainer.Parent = screen

	local coinPill = Instance.new("Frame")
	coinPill.Size = UDim2.new(1, 0, 1, 0)
	coinPill.BackgroundColor3 = Color3.fromRGB(32, 38, 58)
	coinPill.Parent = topBarContainer
	UITheme.addCorner(coinPill, 20)
	UITheme.addStroke(coinPill, UITheme.Colors.GoldAccent, 3)
	UITheme.addGradient(coinPill, Color3.fromRGB(42, 50, 76), Color3.fromRGB(24, 28, 44))

	-- Icono de moneda
	local coinIcon = Instance.new("ImageLabel")
	coinIcon.Size = UDim2.new(0, 36, 0, 36)
	coinIcon.Position = UDim2.new(0, 12, 0.5, 0)
	coinIcon.AnchorPoint = Vector2.new(0, 0.5)
	coinIcon.BackgroundTransparency = 1
	coinIcon.Image = UITheme.ICONS.Coin
	coinIcon.ImageColor3 = Color3.fromRGB(255, 220, 60)
	coinIcon.Parent = coinPill

	local coinsLabel = Instance.new("TextLabel")
	coinsLabel.Size = UDim2.new(0.5, 0, 0.5, 0)
	coinsLabel.Position = UDim2.new(0, 54, 0.12, 0)
	coinsLabel.BackgroundTransparency = 1
	coinsLabel.Text = "$0"
	coinsLabel.TextColor3 = UITheme.Colors.GoldAccent
	coinsLabel.Font = UITheme.FontTitle
	coinsLabel.TextSize = 22
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
	coinsLabel.Parent = coinPill

	-- Insignia de Ingresos por segundo (+$X/s)
	local incomeBadge = Instance.new("Frame")
	incomeBadge.Size = UDim2.new(0, 110, 0, 26)
	incomeBadge.Position = UDim2.new(1, -12, 0.5, 0)
	incomeBadge.AnchorPoint = Vector2.new(1, 0.5)
	incomeBadge.BackgroundColor3 = UITheme.Colors.GreenSuccessDark
	incomeBadge.Parent = coinPill
	UITheme.addCorner(incomeBadge, 13)
	UITheme.addStroke(incomeBadge, UITheme.Colors.GreenSuccess, 2)
	UITheme.addGradient(incomeBadge, UITheme.Colors.GreenSuccess, UITheme.Colors.GreenSuccessDark)

	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Size = UDim2.new(1, 0, 1, 0)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.Text = "+$0/s"
	incomeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	incomeLabel.Font = UITheme.FontBold
	incomeLabel.TextSize = 13
	incomeLabel.Parent = incomeBadge

	-- ── 2. BOTÓN DE CONFIGURACIÓN (TOP RIGHT ⚙️) ──────────────────────────────

	local gearBtn = Instance.new("ImageButton")
	gearBtn.Size = UDim2.new(0, 48, 0, 48)
	gearBtn.Position = UDim2.new(1, -64, 0, 36)
	gearBtn.BackgroundColor3 = Color3.fromRGB(34, 42, 64)
	gearBtn.Image = UITheme.ICONS.Gear
	gearBtn.ImageColor3 = Color3.fromRGB(255, 255, 255)
	gearBtn.AutoButtonColor = false
	gearBtn.BorderSizePixel = 0
	gearBtn.Parent = screen
	UITheme.addCorner(gearBtn, 14)
	UITheme.addStroke(gearBtn, UITheme.Colors.BorderOutline, 2.5)
	UITheme.addGradient(gearBtn, Color3.fromRGB(48, 58, 88), Color3.fromRGB(26, 32, 50))
	UIEffects.applyButtonBounce(gearBtn)

	-- ── 3. TELÓN DE FONDO (MODAL BACKDROP) ────────────────────────────────────

	local modalBackdrop = Instance.new("TextButton")
	modalBackdrop.Size = UDim2.new(1, 0, 1, 0)
	modalBackdrop.BackgroundColor3 = Color3.fromRGB(12, 16, 28)
	modalBackdrop.BackgroundTransparency = 1
	modalBackdrop.Text = ""
	modalBackdrop.AutoButtonColor = false
	modalBackdrop.Visible = false
	modalBackdrop.ZIndex = 5
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

	-- ── 4. BARRA DE NAVEGACIÓN DOCK INFERIOR (2026 AAA STYLE) ─────────────────

	local dockFrame = Instance.new("Frame")
	dockFrame.Size = UDim2.new(0, 420, 0, 74)
	dockFrame.Position = UDim2.new(0.5, 0, 1, -16)
	dockFrame.AnchorPoint = Vector2.new(0.5, 1)
	dockFrame.BackgroundColor3 = Color3.fromRGB(26, 32, 48)
	dockFrame.ZIndex = 4
	dockFrame.Parent = screen
	UITheme.addCorner(dockFrame, 24)
	UITheme.addStroke(dockFrame, Color3.fromRGB(65, 80, 115), 3)
	UITheme.addGradient(dockFrame, Color3.fromRGB(36, 44, 68), Color3.fromRGB(20, 24, 38))

	local dockLayout = Instance.new("UIListLayout")
	dockLayout.FillDirection = Enum.FillDirection.Horizontal
	dockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dockLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	dockLayout.Padding = UDim.new(0, 10)
	dockLayout.Parent = dockFrame

	local function createDockButton(iconAsset: string, label: string, topColor: Color3, bottomColor: Color3, strokeColor: Color3): TextButton
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 92, 0, 56)
		btn.BackgroundColor3 = bottomColor
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.Parent = dockFrame
		UITheme.addCorner(btn, 16)
		UITheme.addStroke(btn, strokeColor, 2.5)
		UITheme.addGradient(btn, topColor, bottomColor)
		UIEffects.applyButtonBounce(btn)

		local iconImg = Instance.new("ImageLabel")
		iconImg.Size = UDim2.new(0, 26, 0, 26)
		iconImg.Position = UDim2.new(0.5, 0, 0.32, 0)
		iconImg.AnchorPoint = Vector2.new(0.5, 0.5)
		iconImg.BackgroundTransparency = 1
		iconImg.Image = iconAsset
		iconImg.ImageColor3 = Color3.fromRGB(255, 255, 255)
		iconImg.Parent = btn

		local textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.new(1, 0, 0.35, 0)
		textLabel.Position = UDim2.new(0, 0, 0.62, 0)
		textLabel.BackgroundTransparency = 1
		textLabel.Text = label
		textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		textLabel.Font = UITheme.FontTitle
		textLabel.TextSize = 11
		textLabel.Parent = btn

		return btn
	end

	local eggDockBtn = createDockButton(UITheme.ICONS.Egg, "HUEVOS", Color3.fromRGB(255, 175, 45), Color3.fromRGB(205, 105, 15), Color3.fromRGB(155, 75, 10))
	local plotDockBtn = createDockButton(UITheme.ICONS.Plant, "JARDÍN", Color3.fromRGB(75, 225, 95), Color3.fromRGB(30, 145, 50), Color3.fromRGB(18, 95, 32))
	local invDockBtn = createDockButton(UITheme.ICONS.Backpack, "MOCHILA", Color3.fromRGB(85, 165, 255), Color3.fromRGB(35, 95, 215), Color3.fromRGB(18, 58, 145))
	local statsDockBtn = createDockButton(UITheme.ICONS.Trophy, "STATS", Color3.fromRGB(215, 105, 255), Color3.fromRGB(135, 45, 205), Color3.fromRGB(90, 22, 140))

	-- ── 5. VENTANA MODAL BASE (HELPER) ────────────────────────────────────────

	local function createModalFrame(titleText: string, width: number, height: number): (Frame, TextButton)
		local modal = Instance.new("Frame")
		modal.Size = UDim2.new(0, width, 0, height)
		modal.Position = UDim2.new(0.5, 0, 0.5, -15)
		modal.AnchorPoint = Vector2.new(0.5, 0.5)
		modal.BackgroundColor3 = Color3.fromRGB(32, 38, 58)
		modal.Visible = false
		modal.ZIndex = 10
		modal.Parent = screen
		UITheme.addCorner(modal, 22)
		UITheme.addStroke(modal, Color3.fromRGB(85, 100, 145), 3.5)
		UITheme.addGradient(modal, Color3.fromRGB(42, 50, 76), Color3.fromRGB(24, 28, 44))

		-- Header
		local header = Instance.new("Frame")
		header.Size = UDim2.new(1, 0, 0, 52)
		header.BackgroundColor3 = Color3.fromRGB(40, 48, 72)
		header.Parent = modal
		UITheme.addCorner(header, 20)
		UITheme.addGradient(header, Color3.fromRGB(56, 66, 98), Color3.fromRGB(34, 40, 62))

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
		closeBtn.Size = UDim2.new(0, 34, 0, 34)
		closeBtn.Position = UDim2.new(1, -44, 0.5, 0)
		closeBtn.AnchorPoint = Vector2.new(0, 0.5)
		closeBtn.BackgroundColor3 = UITheme.Colors.RedDanger
		closeBtn.Text = "✕"
		closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		closeBtn.Font = UITheme.FontBold
		closeBtn.TextSize = 16
		closeBtn.AutoButtonColor = false
		closeBtn.Parent = header
		UITheme.addCorner(closeBtn, 10)
		UITheme.addStroke(closeBtn, Color3.fromRGB(160, 30, 40), 2)
		UIEffects.applyButtonBounce(closeBtn)

		closeBtn.MouseButton1Click:Connect(closeCurrentModal)

		return modal, closeBtn
	end

	-- ── 6. MODAL: CONFIGURACIÓN (SLIDERS REALES Y FUNCIONALES) ─────────────────

	local settingsModal = createModalFrame("⚙️ CONFIGURACIÓN", 380, 350)

	local settingsContainer = Instance.new("Frame")
	settingsContainer.Size = UDim2.new(1, -24, 1, -68)
	settingsContainer.Position = UDim2.new(0, 12, 0, 58)
	settingsContainer.BackgroundTransparency = 1
	settingsContainer.Parent = settingsModal

	local settingsLayout = Instance.new("UIListLayout")
	settingsLayout.Padding = UDim.new(0, 12)
	settingsLayout.Parent = settingsContainer

	local function createSlider(parent: Instance, icon: string, title: string, initialVol: number, onChange: (number) -> ())
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, 0, 0, 66)
		card.BackgroundColor3 = Color3.fromRGB(42, 50, 76)
		card.Parent = parent
		UITheme.addCorner(card, 14)
		UITheme.addStroke(card, UITheme.Colors.BorderOutline, 1.5)

		local iconLbl = Instance.new("TextLabel")
		iconLbl.Size = UDim2.new(0, 36, 0, 30)
		iconLbl.Position = UDim2.new(0, 10, 0, 4)
		iconLbl.BackgroundTransparency = 1
		iconLbl.Text = icon
		iconLbl.TextSize = 20
		iconLbl.Parent = card

		local titleLbl = Instance.new("TextLabel")
		titleLbl.Size = UDim2.new(0.5, 0, 0, 30)
		titleLbl.Position = UDim2.new(0, 48, 0, 4)
		titleLbl.BackgroundTransparency = 1
		titleLbl.Text = title
		titleLbl.TextColor3 = Color3.fromRGB(230, 240, 255)
		titleLbl.Font = UITheme.FontBold
		titleLbl.TextSize = 13
		titleLbl.TextXAlignment = Enum.TextXAlignment.Left
		titleLbl.Parent = card

		local valLbl = Instance.new("TextLabel")
		valLbl.Size = UDim2.new(0.3, 0, 0, 30)
		valLbl.Position = UDim2.new(1, -12, 0, 4)
		valLbl.AnchorPoint = Vector2.new(1, 0)
		valLbl.BackgroundTransparency = 1
		valLbl.Text = math.floor(initialVol * 100) .. "%"
		valLbl.TextColor3 = UITheme.Colors.GoldAccent
		valLbl.Font = UITheme.FontTitle
		valLbl.TextSize = 13
		valLbl.TextXAlignment = Enum.TextXAlignment.Right
		valLbl.Parent = card

		local track = Instance.new("TextButton")
		track.Size = UDim2.new(1, -24, 0, 16)
		track.Position = UDim2.new(0, 12, 1, -22)
		track.BackgroundColor3 = Color3.fromRGB(22, 26, 40)
		track.Text = ""
		track.AutoButtonColor = false
		track.Parent = card
		UITheme.addCorner(track, 8)
		UITheme.addStroke(track, Color3.fromRGB(60, 72, 105), 1.5)

		local fill = Instance.new("Frame")
		fill.Size = UDim2.new(initialVol, 0, 1, 0)
		fill.BackgroundColor3 = Color3.fromRGB(60, 170, 255)
		fill.BorderSizePixel = 0
		fill.Parent = track
		UITheme.addCorner(fill, 8)
		UITheme.addGradient(fill, Color3.fromRGB(90, 200, 255), Color3.fromRGB(30, 120, 240))

		local knob = Instance.new("Frame")
		knob.Size = UDim2.new(0, 22, 0, 22)
		knob.Position = UDim2.new(initialVol, 0, 0.5, 0)
		knob.AnchorPoint = Vector2.new(0.5, 0.5)
		knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		knob.Parent = track
		UITheme.addCorner(knob, 11)
		UITheme.addStroke(knob, Color3.fromRGB(30, 100, 220), 2)

		local dragging = false
		local function updateFromInput(inputPos: Vector2)
			local trackAbsPos = track.AbsolutePosition.X
			local trackAbsSize = track.AbsoluteSize.X
			local relX = math.clamp((inputPos.X - trackAbsPos) / trackAbsSize, 0, 1)

			fill.Size = UDim2.new(relX, 0, 1, 0)
			knob.Position = UDim2.new(relX, 0, 0.5, 0)
			valLbl.Text = math.floor(relX * 100) .. "%"
			onChange(relX)
		end

		track.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				updateFromInput(Vector2.new(input.Position.X, input.Position.Y))
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				updateFromInput(Vector2.new(input.Position.X, input.Position.Y))
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
	end

	-- Control real de volumen a través de SoundManager
	createSlider(settingsContainer, "🔊", "Volumen General", SoundManager.getMasterVolume(), function(v)
		SoundManager.setMasterVolume(v)
	end)

	createSlider(settingsContainer, "🎵", "Música de Fondo", SoundManager.getMusicVolume(), function(v)
		SoundManager.setMusicVolume(v)
	end)

	createSlider(settingsContainer, "✨", "Efectos de Sonido", SoundManager.getEffectsVolume(), function(v)
		SoundManager.setEffectsVolume(v)
	end)

	gearBtn.MouseButton1Click:Connect(function()
		switchModal(settingsModal)
	end)

	-- ── 7. MODAL: TIENDA DE HUEVOS ─────────────────────────────────────────────

	local eggModal = createModalFrame("🥚 TIENDA DE HUEVOS", 400, 440)

	local eggCard = Instance.new("Frame")
	eggCard.Size = UDim2.new(1, -30, 0, 165)
	eggCard.Position = UDim2.new(0, 15, 0, 62)
	eggCard.BackgroundColor3 = Color3.fromRGB(42, 50, 76)
	eggCard.Parent = eggModal
	UITheme.addCorner(eggCard, 18)
	UITheme.addStroke(eggCard, UITheme.Colors.GoldAccent, 2.5)

	local eggBigIcon = Instance.new("ImageLabel")
	eggBigIcon.Size = UDim2.new(0, 72, 0, 72)
	eggBigIcon.Position = UDim2.new(0.5, 0, 0.38, 0)
	eggBigIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	eggBigIcon.BackgroundTransparency = 1
	eggBigIcon.Image = UITheme.ICONS.Egg
	eggBigIcon.ImageColor3 = Color3.fromRGB(255, 220, 80)
	eggBigIcon.Parent = eggCard

	local eggTitle = Instance.new("TextLabel")
	eggTitle.Size = UDim2.new(1, 0, 0, 26)
	eggTitle.Position = UDim2.new(0, 0, 0.74, 0)
	eggTitle.BackgroundTransparency = 1
	eggTitle.Text = "Huevo Frutal Mágico"
	eggTitle.TextColor3 = UITheme.Colors.GoldAccent
	eggTitle.Font = UITheme.FontTitle
	eggTitle.TextSize = 17
	eggTitle.Parent = eggCard

	-- Probabilidades
	local oddsContainer = Instance.new("Frame")
	oddsContainer.Size = UDim2.new(1, -30, 0, 115)
	oddsContainer.Position = UDim2.new(0, 15, 0, 240)
	oddsContainer.BackgroundColor3 = Color3.fromRGB(36, 44, 68)
	oddsContainer.Parent = eggModal
	UITheme.addCorner(oddsContainer, 14)

	local oddsTitle = Instance.new("TextLabel")
	oddsTitle.Size = UDim2.new(1, 0, 0, 22)
	oddsTitle.Position = UDim2.new(0, 0, 0, 4)
	oddsTitle.BackgroundTransparency = 1
	oddsTitle.Text = "PROBABILIDADES DE RAREZA"
	oddsTitle.TextColor3 = UITheme.Colors.TextMuted
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

	local buyEggBtn = Instance.new("TextButton")
	buyEggBtn.Size = UDim2.new(1, -30, 0, 52)
	buyEggBtn.Position = UDim2.new(0, 15, 1, -64)
	buyEggBtn.BackgroundColor3 = UITheme.Colors.GreenSuccess
	buyEggBtn.Text = "🥚 ABRIR HUEVO ($" .. GameConfig.EGG_COST .. ")"
	buyEggBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyEggBtn.Font = UITheme.FontTitle
	buyEggBtn.TextSize = 18
	buyEggBtn.AutoButtonColor = false
	buyEggBtn.Parent = eggModal
	UITheme.addCorner(buyEggBtn, 16)
	UITheme.addStroke(buyEggBtn, UITheme.Colors.GreenSuccessDark, 3)
	UITheme.addGradient(buyEggBtn, Color3.fromRGB(65, 225, 100), UITheme.Colors.GreenSuccessDark)
	UIEffects.applyButtonBounce(buyEggBtn)

	buyEggBtn.MouseButton1Click:Connect(function()
		if currentCoins < GameConfig.EGG_COST then
			UIEffects.playSound("Error")
			UIEffects.spawnFloatingText(screen, "¡Monedas Insuficientes!", UDim2.new(0.5, 0, 0.5, 0), UITheme.Colors.RedDanger, 24)
			return
		end
		if self.onOpenEgg then
			self.onOpenEgg()
		end
	end)

	eggDockBtn.MouseButton1Click:Connect(function()
		switchModal(eggModal)
	end)

	-- ── 8. MODAL: JARDÍN (PLOT MACETAS) ────────────────────────────────────────

	local plotModal = createModalFrame("🌱 MI JARDÍN (MACETAS)", 460, 440)

	local plotGridContainer = Instance.new("Frame")
	plotGridContainer.Size = UDim2.new(1, -24, 1, -70)
	plotGridContainer.Position = UDim2.new(0, 12, 0, 60)
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
		slotCard.BackgroundColor3 = Color3.fromRGB(42, 50, 76)
		slotCard.Text = ""
		slotCard.AutoButtonColor = false
		slotCard.Parent = plotGridContainer
		UITheme.addCorner(slotCard, 14)
		UITheme.addStroke(slotCard, UITheme.Colors.BorderOutline, 2)
		UIEffects.applyButtonBounce(slotCard)

		local iconLbl = Instance.new("TextLabel")
		iconLbl.Name = "Icon"
		iconLbl.Size = UDim2.new(1, 0, 0.45, 0)
		iconLbl.Position = UDim2.new(0, 0, 0.05, 0)
		iconLbl.BackgroundTransparency = 1
		iconLbl.Text = "🪴"
		iconLbl.TextSize = 28
		iconLbl.Parent = slotCard

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Name = "FruitName"
		nameLbl.Size = UDim2.new(1, -4, 0.25, 0)
		nameLbl.Position = UDim2.new(0, 2, 0.48, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = "Vacío"
		nameLbl.TextColor3 = Color3.fromRGB(200, 215, 240)
		nameLbl.Font = UITheme.FontBold
		nameLbl.TextSize = 10
		nameLbl.Parent = slotCard

		local subLbl = Instance.new("TextLabel")
		subLbl.Name = "SubInfo"
		subLbl.Size = UDim2.new(1, -4, 0.22, 0)
		subLbl.Position = UDim2.new(0, 2, 0.74, 0)
		subLbl.BackgroundTransparency = 1
		subLbl.Text = "(" .. slotIdx .. ")"
		subLbl.TextColor3 = UITheme.Colors.TextMuted
		subLbl.Font = UITheme.FontMedium
		subLbl.TextSize = 9
		subLbl.Parent = slotCard

		local currentIdx = slotIdx
		slotCard.MouseButton1Click:Connect(function()
			local slot = currentData.plot[currentIdx]
			if slot and type(slot) == "table" then
				if self.onRemovePlant then
					self.onRemovePlant(currentIdx)
					SoundManager.playSound("Pop", 1.0, 0.5)
				end
			else
				switchModal(invModal)
			end
		end)

		plotSlotCards[slotIdx] = slotCard
	end

	plotDockBtn.MouseButton1Click:Connect(function()
		switchModal(plotModal)
	end)

	-- ── 9. MODAL: MOCHILA / INVENTARIO ─────────────────────────────────────────

	local invModal = createModalFrame("🎒 MOCHILA DE FRUTAS", 460, 460)

	local invTopBar = Instance.new("Frame")
	invTopBar.Size = UDim2.new(1, -24, 0, 44)
	invTopBar.Position = UDim2.new(0, 12, 0, 56)
	invTopBar.BackgroundColor3 = Color3.fromRGB(40, 48, 72)
	invTopBar.Parent = invModal
	UITheme.addCorner(invTopBar, 12)

	local invCountLabel = Instance.new("TextLabel")
	invCountLabel.Size = UDim2.new(0.4, 0, 1, 0)
	invCountLabel.Position = UDim2.new(0, 14, 0, 0)
	invCountLabel.BackgroundTransparency = 1
	invCountLabel.Text = "Frutas: 0"
	invCountLabel.TextColor3 = Color3.fromRGB(220, 230, 255)
	invCountLabel.Font = UITheme.FontBold
	invCountLabel.TextSize = 14
	invCountLabel.TextXAlignment = Enum.TextXAlignment.Left
	invCountLabel.Parent = invTopBar

	local autoEquipBtn = Instance.new("TextButton")
	autoEquipBtn.Size = UDim2.new(0, 175, 0, 34)
	autoEquipBtn.Position = UDim2.new(1, -185, 0.5, 0)
	autoEquipBtn.AnchorPoint = Vector2.new(0, 0.5)
	autoEquipBtn.BackgroundColor3 = Color3.fromRGB(250, 160, 30)
	autoEquipBtn.Text = "⚡ EQUIPAR MEJORES"
	autoEquipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	autoEquipBtn.Font = UITheme.FontTitle
	autoEquipBtn.TextSize = 11
	autoEquipBtn.AutoButtonColor = false
	autoEquipBtn.Parent = invTopBar
	UITheme.addCorner(autoEquipBtn, 10)
	UITheme.addStroke(autoEquipBtn, Color3.fromRGB(170, 90, 10), 2)
	UITheme.addGradient(autoEquipBtn, Color3.fromRGB(255, 190, 60), Color3.fromRGB(220, 120, 15))
	UIEffects.applyButtonBounce(autoEquipBtn)

	autoEquipBtn.MouseButton1Click:Connect(function()
		if self.onAutoEquip then
			self.onAutoEquip()
			SoundManager.playSound("Fanfare", 1.2, 0.6)
			UIEffects.spawnFloatingText(screen, "¡Mejores Frutas Plantadas!", UDim2.new(0.5, 0, 0.5, 0), UITheme.Colors.GoldAccent, 22)
		end
	end)

	local invScroll = Instance.new("ScrollingFrame")
	invScroll.Size = UDim2.new(1, -24, 1, -116)
	invScroll.Position = UDim2.new(0, 12, 0, 106)
	invScroll.BackgroundColor3 = Color3.fromRGB(26, 32, 48)
	invScroll.BorderSizePixel = 0
	invScroll.ScrollBarThickness = 6
	invScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	invScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	invScroll.Parent = invModal
	UITheme.addCorner(invScroll, 14)

	local invGridLayout = Instance.new("UIGridLayout")
	invGridLayout.CellSize = UDim2.new(0, 98, 0, 110)
	invGridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
	invGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	invGridLayout.Parent = invScroll

	local invScrollPadding = Instance.new("UIPadding")
	invScrollPadding.PaddingTop = UDim.new(0, 8)
	invScrollPadding.PaddingLeft = UDim.new(0, 8)
	invScrollPadding.PaddingRight = UDim.new(0, 8)
	invScrollPadding.PaddingBottom = UDim.new(0, 8)
	invScrollPadding.Parent = invScroll

	local inventoryCards: { Frame } = {}

	invDockBtn.MouseButton1Click:Connect(function()
		switchModal(invModal)
	end)

	-- ── 10. MODAL: ESTADÍSTICAS & LOGROS ──────────────────────────────────────

	local statsModal = createModalFrame("🏆 TUS ESTADÍSTICAS", 400, 380)

	local statsContainer = Instance.new("Frame")
	statsContainer.Size = UDim2.new(1, -24, 1, -68)
	statsContainer.Position = UDim2.new(0, 12, 0, 58)
	statsContainer.BackgroundTransparency = 1
	statsContainer.Parent = statsModal

	local statsLayout = Instance.new("UIListLayout")
	statsLayout.Padding = UDim.new(0, 10)
	statsLayout.Parent = statsContainer

	local function makeStatRow(iconAsset: string, title: string, initialVal: string): TextLabel
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 52)
		row.BackgroundColor3 = Color3.fromRGB(42, 50, 76)
		row.Parent = statsContainer
		UITheme.addCorner(row, 14)
		UITheme.addStroke(row, UITheme.Colors.BorderOutline, 1.5)

		local iconImg = Instance.new("ImageLabel")
		iconImg.Size = UDim2.new(0, 28, 0, 28)
		iconImg.Position = UDim2.new(0, 12, 0.5, 0)
		iconImg.AnchorPoint = Vector2.new(0, 0.5)
		iconImg.BackgroundTransparency = 1
		iconImg.Image = iconAsset
		iconImg.ImageColor3 = Color3.fromRGB(255, 255, 255)
		iconImg.Parent = row

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(0.5, 0, 1, 0)
		nameLbl.Position = UDim2.new(0, 50, 0, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = title
		nameLbl.TextColor3 = Color3.fromRGB(220, 230, 255)
		nameLbl.Font = UITheme.FontBold
		nameLbl.TextSize = 13
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.Parent = row

		local valLbl = Instance.new("TextLabel")
		valLbl.Size = UDim2.new(0.4, 0, 1, 0)
		valLbl.Position = UDim2.new(1, -14, 0, 0)
		valLbl.AnchorPoint = Vector2.new(1, 0)
		valLbl.BackgroundTransparency = 1
		valLbl.Text = initialVal
		valLbl.TextColor3 = UITheme.Colors.GoldAccent
		valLbl.Font = UITheme.FontTitle
		valLbl.TextSize = 15
		valLbl.TextXAlignment = Enum.TextXAlignment.Right
		valLbl.Parent = row

		return valLbl
	end

	local statIncomeVal = makeStatRow(UITheme.ICONS.Bolt, "Ingreso Total", "+$0/s")
	local statPlantedVal = makeStatRow(UITheme.ICONS.Plant, "Frutas Plantadas", "0 / 10")
	local statBackpackVal = makeStatRow(UITheme.ICONS.Backpack, "Frutas en Mochila", "0")
	local statCoinsVal = makeStatRow(UITheme.ICONS.Coin, "Monedas Actuales", "$0")

	statsDockBtn.MouseButton1Click:Connect(function()
		switchModal(statsModal)
	end)

	-- ── 11. CINEMÁTICA DE APERTURA DE HUEVOS (GACHA REVEAL) ────────────────────

	local gachaOverlay = Instance.new("Frame")
	gachaOverlay.Size = UDim2.new(1, 0, 1, 0)
	gachaOverlay.BackgroundColor3 = Color3.fromRGB(8, 12, 22)
	gachaOverlay.BackgroundTransparency = 0.15
	gachaOverlay.Visible = false
	gachaOverlay.ZIndex = 100
	gachaOverlay.Parent = screen

	local gachaCard = Instance.new("Frame")
	gachaCard.Size = UDim2.new(0, 330, 0, 430)
	gachaCard.Position = UDim2.new(0.5, 0, 0.5, 0)
	gachaCard.AnchorPoint = Vector2.new(0.5, 0.5)
	gachaCard.BackgroundColor3 = Color3.fromRGB(36, 44, 68)
	gachaCard.ZIndex = 105
	gachaCard.Parent = gachaOverlay
	UITheme.addCorner(gachaCard, 26)
	local gachaStroke = UITheme.addStroke(gachaCard, UITheme.Colors.GoldAccent, 4)

	local gachaHeader = Instance.new("TextLabel")
	gachaHeader.Size = UDim2.new(1, 0, 0, 36)
	gachaHeader.Position = UDim2.new(0, 0, 0, 16)
	gachaHeader.BackgroundTransparency = 1
	gachaHeader.Text = "✨ ¡NUEVA FRUTA DESBLOQUEADA! ✨"
	gachaHeader.TextColor3 = UITheme.Colors.GoldAccent
	gachaHeader.Font = UITheme.FontTitle
	gachaHeader.TextSize = 14
	gachaHeader.Parent = gachaCard

	local gachaRarityBanner = Instance.new("Frame")
	gachaRarityBanner.Size = UDim2.new(0, 190, 0, 32)
	gachaRarityBanner.Position = UDim2.new(0.5, 0, 0, 58)
	gachaRarityBanner.AnchorPoint = Vector2.new(0.5, 0)
	gachaRarityBanner.BackgroundColor3 = Color3.fromRGB(240, 160, 30)
	gachaRarityBanner.Parent = gachaCard
	UITheme.addCorner(gachaRarityBanner, 16)

	local gachaRarityLabel = Instance.new("TextLabel")
	gachaRarityLabel.Size = UDim2.new(1, 0, 1, 0)
	gachaRarityLabel.BackgroundTransparency = 1
	gachaRarityLabel.Text = "LEGENDARIO"
	gachaRarityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	gachaRarityLabel.Font = UITheme.FontTitle
	gachaRarityLabel.TextSize = 13
	gachaRarityLabel.Parent = gachaRarityBanner

	local gachaFruitIcon = Instance.new("TextLabel")
	gachaFruitIcon.Size = UDim2.new(0, 120, 0, 120)
	gachaFruitIcon.Position = UDim2.new(0.5, 0, 0.46, 0)
	gachaFruitIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	gachaFruitIcon.BackgroundTransparency = 1
	gachaFruitIcon.Text = "🍎"
	gachaFruitIcon.TextSize = 80
	gachaFruitIcon.Parent = gachaCard

	local gachaFruitName = Instance.new("TextLabel")
	gachaFruitName.Size = UDim2.new(1, 0, 0, 32)
	gachaFruitName.Position = UDim2.new(0, 0, 0.69, 0)
	gachaFruitName.BackgroundTransparency = 1
	gachaFruitName.Text = "Manzana"
	gachaFruitName.TextColor3 = Color3.fromRGB(255, 255, 255)
	gachaFruitName.Font = UITheme.FontTitle
	gachaFruitName.TextSize = 22
	gachaFruitName.Parent = gachaCard

	local gachaIncomeBadge = Instance.new("Frame")
	gachaIncomeBadge.Size = UDim2.new(0, 160, 0, 32)
	gachaIncomeBadge.Position = UDim2.new(0.5, 0, 0.78, 0)
	gachaIncomeBadge.AnchorPoint = Vector2.new(0.5, 0)
	gachaIncomeBadge.BackgroundColor3 = UITheme.Colors.GreenSuccessDark
	gachaIncomeBadge.Parent = gachaCard
	UITheme.addCorner(gachaIncomeBadge, 12)

	local gachaIncomeLabel = Instance.new("TextLabel")
	gachaIncomeLabel.Size = UDim2.new(1, 0, 1, 0)
	gachaIncomeLabel.BackgroundTransparency = 1
	gachaIncomeLabel.Text = "+$10/s"
	gachaIncomeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	gachaIncomeLabel.Font = UITheme.FontBold
	gachaIncomeLabel.TextSize = 15
	gachaIncomeLabel.Parent = gachaIncomeBadge

	local gachaCollectBtn = Instance.new("TextButton")
	gachaCollectBtn.Size = UDim2.new(1, -40, 0, 48)
	gachaCollectBtn.Position = UDim2.new(0.5, 0, 1, -18)
	gachaCollectBtn.AnchorPoint = Vector2.new(0.5, 1)
	gachaCollectBtn.BackgroundColor3 = UITheme.Colors.GreenSuccess
	gachaCollectBtn.Text = "¡GENIAL!"
	gachaCollectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	gachaCollectBtn.Font = UITheme.FontTitle
	gachaCollectBtn.TextSize = 18
	gachaCollectBtn.AutoButtonColor = false
	gachaCollectBtn.Parent = gachaCard
	UITheme.addCorner(gachaCollectBtn, 14)
	UITheme.addStroke(gachaCollectBtn, UITheme.Colors.GreenSuccessDark, 2.5)
	UITheme.addGradient(gachaCollectBtn, Color3.fromRGB(65, 225, 100), UITheme.Colors.GreenSuccessDark)
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
		gachaOverlay.BackgroundTransparency = 0.25
		UIEffects.openModal(gachaCard)
		UIEffects.shakeObject(gachaCard, 0.25, 6)

		if plant.rarityId >= 4 then
			SoundManager.playSound("Fanfare", 1.0, 0.8)
		else
			SoundManager.playSound("EggCrack", 1.0, 0.7)
		end
	end

	-- ── 12. MÉTODOS DE ACTUALIZACIÓN DEL ESTADO ────────────────────────────────

	self.updateCoins = function(coins: number, income: number)
		currentCoins = coins
		currentIncome = income
		coinsLabel.Text = NumberFormat.formatMoney(coins)
		incomeLabel.Text = NumberFormat.formatIncome(income)
		statCoinsVal.Text = NumberFormat.formatMoney(coins)
		statIncomeVal.Text = NumberFormat.formatIncome(income)

		buyEggBtn.BackgroundColor3 = coins >= GameConfig.EGG_COST
			and UITheme.Colors.GreenSuccess
			or Color3.fromRGB(75, 85, 105)
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
				card.BackgroundColor3 = Color3.fromRGB(42, 50, 76)
				iconLbl.Text = "🪴"
				nameLbl.Text = "Vacío"
				nameLbl.TextColor3 = Color3.fromRGB(190, 205, 230)
				subLbl.Text = "(Toca para +)"
				subLbl.TextColor3 = UITheme.Colors.TextMuted
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
			itemCard.BackgroundColor3 = Color3.fromRGB(38, 46, 70)
			itemCard.Parent = invScroll
			UITheme.addCorner(itemCard, 14)
			UITheme.addStroke(itemCard, style.strokeColor, 2)

			local itemIcon = Instance.new("TextLabel")
			itemIcon.Size = UDim2.new(1, 0, 0.42, 0)
			itemIcon.Position = UDim2.new(0, 0, 0.04, 0)
			itemIcon.BackgroundTransparency = 1
			itemIcon.Text = icon
			itemIcon.TextSize = 30
			itemIcon.Parent = itemCard

			local itemName = Instance.new("TextLabel")
			itemName.Size = UDim2.new(1, -4, 0.2, 0)
			itemName.Position = UDim2.new(0, 2, 0.44, 0)
			itemName.BackgroundTransparency = 1
			itemName.Text = plant.speciesName
			itemName.TextColor3 = Color3.fromRGB(255, 255, 255)
			itemName.Font = UITheme.FontBold
			itemName.TextSize = 11
			itemName.Parent = itemCard

			local itemIncome = Instance.new("TextLabel")
			itemIncome.Size = UDim2.new(1, -4, 0.16, 0)
			itemIncome.Position = UDim2.new(0, 2, 0.62, 0)
			itemIncome.BackgroundTransparency = 1
			itemIncome.Text = NumberFormat.formatIncome(income)
			itemIncome.TextColor3 = Color3.fromRGB(100, 255, 120)
			itemIncome.Font = UITheme.FontBold
			itemIncome.TextSize = 10
			itemIncome.Parent = itemCard

			local plantBtn = Instance.new("TextButton")
			plantBtn.Size = UDim2.new(1, -10, 0, 20)
			plantBtn.Position = UDim2.new(0, 5, 1, -24)
			plantBtn.BackgroundColor3 = UITheme.Colors.GreenSuccess
			plantBtn.Text = "PLANTAR"
			plantBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			plantBtn.Font = UITheme.FontTitle
			plantBtn.TextSize = 10
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
							SoundManager.playSound("Pop", 1.1, 0.5)
						end
						return
					end
				end
				SoundManager.playSound("Error", 1.0, 0.6)
				UIEffects.spawnFloatingText(screen, "¡El jardín está lleno!", UDim2.new(0.5, 0, 0.5, 0), UITheme.Colors.RedDanger, 22)
			end)

			table.insert(inventoryCards, itemCard)
		end
	end

	return self
end

return HUD
