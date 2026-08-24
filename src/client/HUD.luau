--!strict
local _Players      = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService  = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local GameConfig   = require(ReplicatedStorage.Shared.GameConfig)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)

export type Plant      = GameConfig.Plant
export type PlayerData = GameConfig.PlayerData

export type HUDInstance = {
	updateCoins : (coins: number, income: number) -> (),
	updateFull  : (data: PlayerData & { incomePerSecond: number? }) -> (),
}

local HUD = {}

-- ── UI helpers ─────────────────────────────────────────────────────────────────

local function makeLabel(
	parent   : Instance,
	text     : string,
	size     : UDim2,
	pos      : UDim2,
	fontSize : number,
	bold     : boolean?
): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.Size               = size
	lbl.Position           = pos
	lbl.BackgroundTransparency = 1
	lbl.Text               = text
	lbl.TextColor3         = Color3.fromRGB(255, 255, 255)
	lbl.TextScaled         = false
	lbl.Font               = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	lbl.TextSize           = fontSize
	lbl.TextXAlignment     = Enum.TextXAlignment.Center
	lbl.Parent             = parent
	return lbl
end

local function addCorner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

-- ── Volume helpers ──────────────────────────────────────────────────────────────

local function applyGroupVolume(groupName: string, vol: number)
	local g = SoundService:FindFirstChild(groupName)
	if g and g:IsA("SoundGroup") then
		g.Volume = vol
	end
end

-- ── Slider factory ──────────────────────────────────────────────────────────────
-- Creates a self-contained slider row and returns getValue() → 0..1

local TRACK_W = 118
local ROW_H   = 70

local function createSlider(
	parent  : Frame,
	icon    : string,
	label   : string,
	desc    : string,
	default : number,          -- 0.0 – 1.0
	onChange: (v: number) -> ()
)
	-- Row
	local row = Instance.new("Frame")
	row.Size                   = UDim2.new(1, 0, 0, ROW_H)
	row.BackgroundColor3       = Color3.fromRGB(22, 28, 42)
	row.BackgroundTransparency = 0.1
	row.BorderSizePixel        = 0
	row.Parent                 = parent
	addCorner(row, 10)

	-- Icon
	local iconLbl = Instance.new("TextLabel")
	iconLbl.Size               = UDim2.new(0, 40, 1, 0)
	iconLbl.Position           = UDim2.new(0, 6, 0, 0)
	iconLbl.BackgroundTransparency = 1
	iconLbl.Text               = icon
	iconLbl.TextSize           = 24
	iconLbl.Font               = Enum.Font.GothamBold
	iconLbl.TextColor3         = Color3.fromRGB(180, 210, 255)
	iconLbl.Parent             = row

	-- Name
	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size               = UDim2.new(0, 92, 0, 22)
	nameLbl.Position           = UDim2.new(0, 50, 0, 10)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text               = label
	nameLbl.TextSize           = 13
	nameLbl.Font               = Enum.Font.GothamBold
	nameLbl.TextColor3         = Color3.fromRGB(235, 240, 255)
	nameLbl.TextXAlignment     = Enum.TextXAlignment.Left
	nameLbl.Parent             = row

	-- Description
	local descLbl = Instance.new("TextLabel")
	descLbl.Size               = UDim2.new(0, 92, 0, 16)
	descLbl.Position           = UDim2.new(0, 50, 0, 34)
	descLbl.BackgroundTransparency = 1
	descLbl.Text               = desc
	descLbl.TextSize           = 9
	descLbl.Font               = Enum.Font.Gotham
	descLbl.TextColor3         = Color3.fromRGB(115, 135, 165)
	descLbl.TextXAlignment     = Enum.TextXAlignment.Left
	descLbl.Parent             = row

	-- Track
	local track = Instance.new("Frame")
	track.Size             = UDim2.new(0, TRACK_W, 0, 12)
	track.Position         = UDim2.new(0, 148, 0.5, -6)
	track.BackgroundColor3 = Color3.fromRGB(38, 46, 64)
	track.BorderSizePixel  = 0
	track.Parent           = row
	addCorner(track, 99)

	-- Fill
	local fill = Instance.new("Frame")
	fill.Size             = UDim2.new(default, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(65, 190, 110)
	fill.BorderSizePixel  = 0
	fill.Parent           = track
	addCorner(fill, 99)

	-- Thumb
	local thumb = Instance.new("TextButton")
	thumb.Size             = UDim2.new(0, 20, 0, 20)
	thumb.Position         = UDim2.new(default, -10, 0.5, -10)
	thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	thumb.Text             = ""
	thumb.AutoButtonColor  = false
	thumb.BorderSizePixel  = 0
	thumb.ZIndex           = 5
	thumb.Parent           = track
	addCorner(thumb, 99)

	local thumbStroke = Instance.new("UIStroke")
	thumbStroke.Color        = Color3.fromRGB(0, 0, 0)
	thumbStroke.Transparency = 0.55
	thumbStroke.Thickness    = 1.5
	thumbStroke.Parent       = thumb

	-- Value badge
	local valLbl = Instance.new("TextLabel")
	valLbl.Size               = UDim2.new(0, 34, 0, 26)
	valLbl.Position           = UDim2.new(0, TRACK_W + 8, 0.5, -13)
	valLbl.BackgroundColor3   = Color3.fromRGB(32, 40, 58)
	valLbl.BackgroundTransparency = 0
	valLbl.Text               = tostring(math.round(default * 100))
	valLbl.TextSize           = 12
	valLbl.Font               = Enum.Font.GothamBold
	valLbl.TextColor3         = Color3.fromRGB(255, 255, 255)
	valLbl.TextXAlignment     = Enum.TextXAlignment.Center
	valLbl.Parent             = track
	addCorner(valLbl, 6)

	-- Drag logic
	local isDragging = false

	local function seek(absX: number)
		local tx = track.AbsolutePosition.X
		local tw = track.AbsoluteSize.X
		local ratio = math.clamp((absX - tx) / tw, 0, 1)
		fill.Size          = UDim2.new(ratio, 0, 1, 0)
		thumb.Position     = UDim2.new(ratio, -10, 0.5, -10)
		valLbl.Text        = tostring(math.round(ratio * 100))
		onChange(ratio)
	end

	thumb.MouseButton1Down:Connect(function()
		isDragging = true
	end)

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isDragging = true
			seek(input.Position.X)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			seek(input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isDragging = false
		end
	end)
end

-- ── HUD.create ─────────────────────────────────────────────────────────────────

function HUD.create(player: Player): HUDInstance
	local self: HUDInstance = {
		updateCoins = function() end,
		updateFull  = function() end,
	}

	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	local existing = playerGui:FindFirstChild("FruitGardenHUD")
	if existing then existing:Destroy() end

	local screen = Instance.new("ScreenGui")
	screen.Name            = "FruitGardenHUD"
	screen.ResetOnSpawn    = false
	screen.IgnoreGuiInset  = true
	screen.Parent          = playerGui

	-- ── Top bar ────────────────────────────────────────────────────────────────
	local topBar = Instance.new("Frame")
	topBar.Size                   = UDim2.new(1, 0, 0, 56)
	topBar.Position               = UDim2.new(0, 0, 0, 0)
	topBar.BackgroundColor3       = Color3.fromRGB(18, 20, 28)
	topBar.BackgroundTransparency = 0.15
	topBar.BorderSizePixel        = 0
	topBar.Parent                 = screen

	local coinsLabel = makeLabel(topBar, "$0",     UDim2.new(0.4, 0, 0.6, 0),  UDim2.new(0.3, 0, 0.05, 0), 24, true)
	coinsLabel.TextColor3 = Color3.fromRGB(255, 220, 80)

	local incomeLabel = makeLabel(topBar, "+$0/s", UDim2.new(0.4, 0, 0.35, 0), UDim2.new(0.3, 0, 0.60, 0), 13, false)
	incomeLabel.TextColor3 = Color3.fromRGB(120, 255, 120)

	-- Gear button (floating top-right)
	local gearBtn = Instance.new("ImageButton")
	gearBtn.Size               = UDim2.new(0, 46, 0, 46)
	gearBtn.Position           = UDim2.new(1, -60, 0, 10)
	gearBtn.BackgroundColor3   = Color3.fromRGB(28, 34, 52)
	gearBtn.BackgroundTransparency = 0
	gearBtn.Image              = "rbxassetid://17368089841" -- Reemplaza 0 con el ID de la imagen
	gearBtn.AutoButtonColor    = true
	gearBtn.BorderSizePixel    = 0
	gearBtn.Parent             = screen
	addCorner(gearBtn, 12)

	-- ── Settings panel ──────────────────────────────────────────────────────────
	local PANEL_W  = 338
	local PANEL_H  = 330

	local panel = Instance.new("Frame")
	panel.Name                   = "SettingsPanel"
	panel.Size                   = UDim2.new(0, PANEL_W, 0, PANEL_H)
	panel.Position               = UDim2.new(1, -(PANEL_W + 10), 0, 64)
	panel.BackgroundColor3       = Color3.fromRGB(14, 17, 28)
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel        = 0
	panel.Visible                = false
	panel.ZIndex                 = 10
	panel.Parent                 = screen
	addCorner(panel, 14)

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color        = Color3.fromRGB(55, 72, 115)
	panelStroke.Transparency = 0.3
	panelStroke.Thickness    = 1.5
	panelStroke.Parent       = panel

	-- Header
	local header = Instance.new("Frame")
	header.Size               = UDim2.new(1, 0, 0, 52)
	header.BackgroundColor3   = Color3.fromRGB(20, 26, 42)
	header.BorderSizePixel    = 0
	header.ZIndex             = 11
	header.Parent             = panel
	addCorner(header, 14)

	-- Flat bottom cover for header corners
	local hCover = Instance.new("Frame")
	hCover.Size               = UDim2.new(1, 0, 0, 14)
	hCover.Position           = UDim2.new(0, 0, 1, -14)
	hCover.BackgroundColor3   = Color3.fromRGB(20, 26, 42)
	hCover.BorderSizePixel    = 0
	hCover.ZIndex             = 11
	hCover.Parent             = header

	local titleLbl = makeLabel(header, "⚙  Settings", UDim2.new(1, -56, 1, 0), UDim2.new(0, 14, 0, 0), 17, true)
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.TextColor3     = Color3.fromRGB(215, 228, 255)
	titleLbl.ZIndex         = 12

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size               = UDim2.new(0, 32, 0, 32)
	closeBtn.Position           = UDim2.new(1, -42, 0, 10)
	closeBtn.BackgroundColor3   = Color3.fromRGB(175, 48, 48)
	closeBtn.Text               = "✕"
	closeBtn.TextSize           = 15
	closeBtn.Font               = Enum.Font.GothamBold
	closeBtn.TextColor3         = Color3.fromRGB(255, 255, 255)
	closeBtn.AutoButtonColor    = true
	closeBtn.BorderSizePixel    = 0
	closeBtn.ZIndex             = 12
	closeBtn.Parent             = header
	addCorner(closeBtn, 8)

	-- Divider
	local divider = Instance.new("Frame")
	divider.Size               = UDim2.new(1, -24, 0, 1)
	divider.Position           = UDim2.new(0, 12, 0, 52)
	divider.BackgroundColor3   = Color3.fromRGB(55, 72, 115)
	divider.BackgroundTransparency = 0.4
	divider.BorderSizePixel    = 0
	divider.ZIndex             = 11
	divider.Parent             = panel

	-- Section label
	local audioLbl = makeLabel(panel, "— Audio —", UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 60), 12, true)
	audioLbl.TextColor3 = Color3.fromRGB(110, 150, 215)
	audioLbl.ZIndex     = 11

	-- Sliders container
	local slidersCont = Instance.new("Frame")
	slidersCont.Size                   = UDim2.new(1, 0, 0, 0)
	slidersCont.Position               = UDim2.new(0, 0, 0, 86)
	slidersCont.BackgroundTransparency = 1
	slidersCont.AutomaticSize          = Enum.AutomaticSize.Y
	slidersCont.ZIndex                 = 11
	slidersCont.Parent                 = panel

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder  = Enum.SortOrder.LayoutOrder
	listLayout.Padding    = UDim.new(0, 6)
	listLayout.Parent     = slidersCont

	local contPad = Instance.new("UIPadding")
	contPad.PaddingLeft   = UDim.new(0, 12)
	contPad.PaddingRight  = UDim.new(0, 12)
	contPad.PaddingBottom = UDim.new(0, 12)
	contPad.Parent        = slidersCont

	-- General Volume
	createSlider(slidersCont, "🔊", "General", "Volumen general", 1.0, function(v)
		for _, child in SoundService:GetChildren() do
			if child:IsA("SoundGroup") then
				child.Volume = v
			end
		end
	end)

	-- Music Volume
	createSlider(slidersCont, "🎵", "Música", "Volumen de música", 1.0, function(v)
		applyGroupVolume("Music", v)
	end)

	-- Effects Volume
	createSlider(slidersCont, "✨", "Efectos", "Volumen de efectos", 1.0, function(v)
		applyGroupVolume("Effects", v)
	end)

	-- ── Panel open / close animation ─────────────────────────────────────────────
	local panelOpen    = false
	local PANEL_OPEN_X = -(PANEL_W + 10)
	local PANEL_CLOSE_X = 10

	local function openPanel()
		panelOpen = true
		panel.Position = UDim2.new(1, PANEL_CLOSE_X, 0, 64)
		panel.Visible  = true
		TweenService:Create(
			panel,
			TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = UDim2.new(1, PANEL_OPEN_X, 0, 64) }
		):Play()
		TweenService:Create(gearBtn, TweenInfo.new(0.2), { ImageColor3 = Color3.fromRGB(150, 150, 150) }):Play()
	end

	local function closePanel()
		panelOpen = false
		local tw = TweenService:Create(
			panel,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(1, PANEL_CLOSE_X, 0, 64) }
		)
		tw:Play()
		tw.Completed:Connect(function()
			if not panelOpen then
				panel.Visible = false
			end
		end)
		TweenService:Create(gearBtn, TweenInfo.new(0.2), { ImageColor3 = Color3.fromRGB(255, 255, 255) }):Play()
	end

	gearBtn.MouseButton1Click:Connect(function()
		if panelOpen then closePanel() else openPanel() end
	end)

	closeBtn.MouseButton1Click:Connect(closePanel)

	-- ── Coin display ─────────────────────────────────────────────────────────────

	local function updateDisplay(coins: number, income: number)
		coinsLabel.Text  = NumberFormat.formatMoney(coins)
		incomeLabel.Text = NumberFormat.formatIncome(income)
	end

	self.updateCoins = function(coins: number, income: number)
		updateDisplay(coins, income)
	end

	self.updateFull = function(data: PlayerData & { incomePerSecond: number? })
		updateDisplay(data.coins, data.incomePerSecond or 0)
	end

	return self
end

return HUD
