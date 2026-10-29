-- The note the old owner left on the break room table (a place part tagged BossNote,
-- with a ReadPrompt). Reading it holds the paper up on screen; E, Escape or walking
-- away puts it down. Everything is local: the first read sets the ReadBossNote player
-- attribute, which TutorialClient waits for, and ReadingNote is set while it's up so the
-- tutorial arrow gets out of the way.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Further than this from the note and it's put down.
local READ_RANGE = 12
local PAPER_SOUND_ID = "rbxassetid://9118835802" -- Scrapbook Open And Turn Pages 7

local PAPER = Color3.fromRGB(236, 226, 200)
local INK = Color3.fromRGB(46, 34, 26)
local ACCENT = Color3.fromRGB(112, 30, 26)
local HAND = Font.fromEnum(Enum.Font.Kalam)

local TEXT = table.concat({
	"Kid,",
	"",
	"I'm gone. Don't ask where, and don't come looking. The shop is yours now. Keep the lights on and the doors open.",
	"",
	"The stock doesn't come from a supplier. It comes from below. Take the elevator down at night, find whatever's worth something, and send it up on the cargo lift. Three loads a night, no more. It doesn't like being greedy.",
	"",
	"Then come back up and get it on the shelves before the customers come in.",
	"",
	"Don't run in the halls. Don't answer if it asks your name.",
	"",
	"Good luck.",
}, "\n")

local gui = Instance.new("ScreenGui")
gui.Name = "BossNote"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 8
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local shade = Instance.new("Frame")
shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundColor3 = Color3.new(0, 0, 0)
shade.BackgroundTransparency = 1
shade.BorderSizePixel = 0
shade.Parent = gui

local paper = Instance.new("Frame")
paper.AnchorPoint = Vector2.new(0.5, 0.5)
paper.Position = UDim2.fromScale(0.5, 1.5)
paper.Size = UDim2.fromOffset(440, 560)
paper.Rotation = -2
paper.BackgroundColor3 = PAPER
paper.BorderSizePixel = 0
paper.Parent = gui
local fit = Instance.new("UISizeConstraint")
fit.MaxSize = Vector2.new(440, 560)
fit.Parent = paper
local aspect = Instance.new("UIAspectRatioConstraint")
aspect.AspectRatio = 440 / 560
aspect.Parent = paper
local edge = Instance.new("UIStroke")
edge.Color = Color3.fromRGB(196, 178, 146)
edge.Thickness = 2
edge.Parent = paper

local writing = Instance.new("TextLabel")
writing.Position = UDim2.fromScale(0.08, 0.06)
writing.Size = UDim2.fromScale(0.84, 0.86)
writing.BackgroundTransparency = 1
writing.FontFace = HAND
writing.TextColor3 = INK
writing.TextScaled = true
writing.TextWrapped = true
writing.TextXAlignment = Enum.TextXAlignment.Left
writing.TextYAlignment = Enum.TextYAlignment.Top
writing.Text = TEXT
writing.Parent = paper
local maxText = Instance.new("UITextSizeConstraint")
maxText.MaxTextSize = 20
maxText.Parent = writing

local footer = Instance.new("TextLabel")
footer.AnchorPoint = Vector2.new(0.5, 0)
footer.Position = UDim2.new(0.5, 0, 1, 14)
footer.Size = UDim2.fromOffset(300, 20)
footer.BackgroundTransparency = 1
footer.Font = Enum.Font.GothamBold
footer.TextSize = 12
footer.TextColor3 = Color3.fromRGB(222, 202, 160)
footer.TextStrokeTransparency = 0.6
footer.Text = "E   put it down"
footer.Parent = paper

local stain = Instance.new("Frame")
stain.AnchorPoint = Vector2.new(0.5, 0.5)
stain.Position = UDim2.fromScale(0.82, 0.88)
stain.Size = UDim2.fromScale(0.2, 0.16)
stain.BackgroundColor3 = ACCENT:Lerp(PAPER, 0.75)
stain.BackgroundTransparency = 0.55
stain.BorderSizePixel = 0
stain.Parent = paper
local round = Instance.new("UICorner")
round.CornerRadius = UDim.new(0.5, 0)
round.Parent = stain

local sound = Instance.new("Sound")
sound.SoundId = PAPER_SOUND_ID
sound.Volume = 0.25
sound.Parent = script

local SLIDE = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local openNote -- the part being read, or nil
local openedAt = 0

local function close()
	if not openNote then
		return
	end
	local prompt = openNote:FindFirstChild("ReadPrompt")
	if prompt then
		prompt.Enabled = true
	end
	openNote = nil
	player:SetAttribute("ReadingNote", nil)
	sound:Play()
	TweenService:Create(shade, SLIDE, { BackgroundTransparency = 1 }):Play()
	local out = TweenService:Create(paper, SLIDE, { Position = UDim2.fromScale(0.5, 1.5) })
	out:Play()
	out.Completed:Once(function()
		if not openNote then
			gui.Enabled = false
		end
	end)
end

local function open(note, prompt)
	if openNote then
		return
	end
	openNote = note
	openedAt = os.clock()
	-- Off while it's up, so the E that puts it down doesn't pick it straight back up.
	prompt.Enabled = false
	player:SetAttribute("ReadingNote", true)
	player:SetAttribute("ReadBossNote", true)
	sound:Play()
	gui.Enabled = true
	TweenService:Create(shade, SLIDE, { BackgroundTransparency = 0.55 }):Play()
	TweenService:Create(paper, SLIDE, { Position = UDim2.fromScale(0.5, 0.5) }):Play()
end

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local note = prompt.Parent
	if prompt.Name == "ReadPrompt" and note and CollectionService:HasTag(note, "BossNote") then
		open(note, prompt)
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- The press that opened it can arrive here too.
	if
		openNote
		and not gameProcessed
		and os.clock() - openedAt > 0.2
		and (input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Escape)
	then
		close()
	end
end)

-- Walking off, dying, or the store being put away (the elevator leaving) all put it down.
task.spawn(function()
	while true do
		task.wait(0.2)
		if openNote then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if
				not root
				or not openNote:IsDescendantOf(workspace)
				or (root.Position - openNote.Position).Magnitude > READ_RANGE
			then
				close()
			end
		end
	end
end)
