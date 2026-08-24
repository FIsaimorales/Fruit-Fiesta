--!strict
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local UIEffects = {}

-- Audio asset IDs for satisfying feedback
local SOUND_IDS = {
	Click = "rbxassetid://6895079853",
	Pop = "rbxassetid://9069609200",
	EggCrack = "rbxassetid://9069608998",
	GachaRare = "rbxassetid://9069608552",
	Error = "rbxassetid://9069608823",
	CoinCollect = "rbxassetid://6518811702",
}

local soundsFolder: Folder? = nil
local function getSound(name: string): Sound?
	if not soundsFolder then
		local found = SoundService:FindFirstChild("FruitUISounds")
		if found and found:IsA("Folder") then
			soundsFolder = found
		else
			soundsFolder = Instance.new("Folder")
			soundsFolder.Name = "FruitUISounds"
			soundsFolder.Parent = SoundService
		end
	end

	local s = soundsFolder:FindFirstChild(name) :: Sound?
	if not s and SOUND_IDS[name] then
		s = Instance.new("Sound")
		s.Name = name
		s.SoundId = SOUND_IDS[name]
		s.Volume = 0.5
		s.Parent = soundsFolder
	end
	return s
end

function UIEffects.playSound(name: string)
	task.spawn(function()
		local snd = getSound(name)
		if snd then
			snd:Play()
		end
	end)
end

-- Adds elastic squash & stretch animations to any GuiButton
function UIEffects.applyButtonBounce(button: GuiButton, baseScale: number?)
	local scale = baseScale or 1.0
	local uiScale = button:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Scale = scale
		uiScale.Parent = button
	end

	local hoverTween: Tween? = nil
	local pressTween: Tween? = nil

	button.MouseEnter:Connect(function()
		if hoverTween then
			hoverTween:Cancel()
		end
		hoverTween = TweenService:Create(
			uiScale,
			TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = scale * 1.07 }
		)
		hoverTween:Play()
	end)

	button.MouseLeave:Connect(function()
		if hoverTween then
			hoverTween:Cancel()
		end
		hoverTween = TweenService:Create(
			uiScale,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = scale }
		)
		hoverTween:Play()
	end)

	button.MouseButton1Down:Connect(function()
		if pressTween then
			pressTween:Cancel()
		end
		pressTween = TweenService:Create(
			uiScale,
			TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = scale * 0.92 }
		)
		pressTween:Play()
		UIEffects.playSound("Click")
	end)

	button.MouseButton1Up:Connect(function()
		if pressTween then
			pressTween:Cancel()
		end
		pressTween = TweenService:Create(
			uiScale,
			TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = scale * 1.05 }
		)
		pressTween:Play()
	end)
end

-- Animate modal popup opening (Bouncy Spring)
function UIEffects.openModal(modalFrame: GuiObject, backdrop: GuiObject?)
	local uiScale = modalFrame:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Parent = modalFrame
	end

	uiScale.Scale = 0.5
	modalFrame.Visible = true

	if backdrop then
		backdrop.Visible = true
		backdrop.BackgroundTransparency = 1
		TweenService:Create(
			backdrop,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 0.45 }
		):Play()
	end

	UIEffects.playSound("Pop")

	local tween = TweenService:Create(
		uiScale,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1.0 }
	)
	tween:Play()
end

-- Animate modal closing
function UIEffects.closeModal(modalFrame: GuiObject, backdrop: GuiObject?, onComplete: (() -> ())?)
	local uiScale = modalFrame:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Parent = modalFrame
	end

	if backdrop then
		TweenService:Create(
			backdrop,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ BackgroundTransparency = 1 }
		):Play()
	end

	local tween = TweenService:Create(
		uiScale,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Scale = 0.6 }
	)
	tween:Play()

	tween.Completed:Connect(function()
		modalFrame.Visible = false
		if backdrop then
			backdrop.Visible = false
		end
		if onComplete then
			onComplete()
		end
	end)
end

-- Spawns floating animated +$ text popping upward
function UIEffects.spawnFloatingText(parent: Instance, text: string, startPos: UDim2, color: Color3, fontSize: number?)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 180, 0, 36)
	label.Position = startPos
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.Font = Enum.Font.GothamBlack
	label.TextSize = fontSize or 22
	label.TextStrokeTransparency = 0.3
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.ZIndex = 50
	label.Parent = parent

	local targetPos = UDim2.new(startPos.X.Scale, startPos.X.Offset, startPos.Y.Scale, startPos.Y.Offset - 50)

	local tween = TweenService:Create(
		label,
		TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Position = targetPos,
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	)
	tween:Play()
	tween.Completed:Connect(function()
		label:Destroy()
	end)
end

return UIEffects
