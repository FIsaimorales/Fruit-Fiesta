--!strict
-- Slot-machine roll presentation.
--
-- IMPORTANT: this module never decides anything. The server has already rolled
-- the real species + rarity and sent it over; everything here is suspense. The
-- teasers it flashes are deliberately weighted toward high rarities and "???"
-- because that reads better, and it costs nothing — the outcome is fixed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local UITheme = require(script.Parent.UITheme)
local UIEffects = require(script.Parent.UIEffects)
local SoundManager = require(script.Parent.SoundManager)

export type Plant = GameConfig.Plant

local RollAnimation = {}

-- Teaser frames shown while spinning. Heavy on the top rarities for suspense.
local TEASER_RARITY_IDS = { 3, 4, 5, 6, 4, 5, 6, 5, 6 }

local rng = Random.new()

local function randomTeaser(): (string, Color3)
	-- Roughly one frame in four is a "???" blackout.
	if rng:NextNumber() < 0.25 then
		return "???", Color3.fromRGB(220, 230, 250)
	end

	local rarityId = TEASER_RARITY_IDS[rng:NextInteger(1, #TEASER_RARITY_IDS)]
	local style = UITheme.getRarityStyle(rarityId)
	local species = GameConfig.getSpeciesForRarity(rarityId)
	if #species == 0 then
		return "???", style.badgeColor
	end
	local pick = species[rng:NextInteger(1, #species)]
	return UITheme.getSpeciesIcon(pick.name), style.badgeColor
end

export type RollUI = {
	play: (plant: Plant, duration: number, onReveal: (Plant) -> ()) -> (),
}

-- Builds the reusable spin overlay inside a ScreenGui.
function RollAnimation.create(screen: ScreenGui): RollUI
	local overlay = Instance.new("Frame")
	overlay.Name = "RollOverlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(8, 12, 22)
	overlay.BackgroundTransparency = 0.25
	overlay.Visible = false
	overlay.ZIndex = 90
	overlay.Parent = screen

	local card = Instance.new("Frame")
	card.Name = "RollCard"
	card.Size = UDim2.new(0, 300, 0, 300)
	card.Position = UDim2.new(0.5, 0, 0.5, 0)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.BackgroundColor3 = Color3.fromRGB(30, 36, 56)
	card.ZIndex = 92
	card.Parent = overlay
	UITheme.addCorner(card, 24)
	local cardStroke = UITheme.addStroke(card, UITheme.Colors.GoldAccent, 4)
	UITheme.addGradient(card, Color3.fromRGB(44, 52, 80), Color3.fromRGB(22, 26, 42))

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 30)
	header.Position = UDim2.new(0, 0, 0, 18)
	header.BackgroundTransparency = 1
	header.Text = "🎰 ROLLEANDO..."
	header.TextColor3 = UITheme.Colors.GoldAccent
	header.Font = UITheme.FontTitle
	header.TextSize = 18
	header.ZIndex = 93
	header.Parent = card

	-- The reel window: a framed slot the teasers flicker through.
	local reelWindow = Instance.new("Frame")
	reelWindow.Size = UDim2.new(1, -50, 0, 150)
	reelWindow.Position = UDim2.new(0.5, 0, 0, 62)
	reelWindow.AnchorPoint = Vector2.new(0.5, 0)
	reelWindow.BackgroundColor3 = Color3.fromRGB(16, 20, 34)
	reelWindow.ClipsDescendants = true
	reelWindow.ZIndex = 93
	reelWindow.Parent = card
	UITheme.addCorner(reelWindow, 16)
	UITheme.addStroke(reelWindow, Color3.fromRGB(70, 84, 120), 2)

	local reelIcon = Instance.new("TextLabel")
	reelIcon.Size = UDim2.new(1, 0, 1, 0)
	reelIcon.BackgroundTransparency = 1
	reelIcon.Text = "???"
	reelIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
	reelIcon.Font = UITheme.FontTitle
	reelIcon.TextSize = 76
	reelIcon.ZIndex = 94
	reelIcon.Parent = reelWindow

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, -40, 0, 40)
	statusLabel.Position = UDim2.new(0.5, 0, 1, -50)
	statusLabel.AnchorPoint = Vector2.new(0.5, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "El destino decide..."
	statusLabel.TextColor3 = UITheme.Colors.TextMuted
	statusLabel.Font = UITheme.FontBold
	statusLabel.TextSize = 14
	statusLabel.ZIndex = 93
	statusLabel.Parent = card

	local spinning = false

	local function play(plant: Plant, duration: number, onReveal: (Plant) -> ())
		if spinning then
			return
		end
		spinning = true

		overlay.Visible = true
		header.Text = "🎰 ROLLEANDO..."
		statusLabel.Text = "El destino decide..."
		cardStroke.Color = UITheme.Colors.GoldAccent
		UIEffects.openModal(card)

		task.spawn(function()
			local startTime = os.clock()
			local spinTime = math.max(duration, 0.5)

			while true do
				local elapsed = os.clock() - startTime
				if elapsed >= spinTime then
					break
				end

				local icon, color = randomTeaser()
				reelIcon.Text = icon
				reelIcon.TextColor3 = color
				SoundManager.playSound("Click", 1.6, 0.18)

				-- Reel decelerates: frames start at 45ms and stretch toward 380ms.
				local progress = elapsed / spinTime
				task.wait(0.045 + (progress ^ 3) * 0.335)
			end

			-- Reveal the result the server picked before any of this started.
			local style = UITheme.getRarityStyle(plant.rarityId)
			reelIcon.Text = UITheme.getSpeciesIcon(plant.speciesName)
			reelIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
			cardStroke.Color = style.strokeColor
			header.Text = "✨ ¡RESULTADO!"
			statusLabel.Text = plant.speciesName

			UIEffects.shakeObject(card, 0.22, 5)
			task.wait(0.45)

			overlay.Visible = false
			spinning = false
			onReveal(plant)
		end)
	end

	return { play = play }
end

return RollAnimation
