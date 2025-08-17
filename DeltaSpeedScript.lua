local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local player = Players.LocalPlayer

-- SETTINGS
local STEP_DISTANCE = 4
local NORMAL_UPGRADE_STEPS = 100
local BOOST_UPGRADE_STEPS = 10
local BOOST_DURATION = 10
local BOOST_COOLDOWN = 30

-- STATE
local character, humanoid, rootPart
local lastPosition = Vector3.new()
local distanceCounter, stepTotal, appliedUpgrades = 0,0,0
local upgradesEnabled = false
local boostStored, boostActive, boostCooldown = 0,false,false
local boostEndTime, boostCooldownEnd = 0,0
local baseWalkSpeed, currentBaseSpeed = 16,16
local upgradeSoundSpeed = 1

-- GUI MAIN
local screenGui = Instance.new("ScreenGui")
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0,60,0,25)
toggleBtn.Position = UDim2.new(0,10,0,10)
toggleBtn.Text = "OFF"
toggleBtn.BackgroundColor3 = Color3.fromRGB(0,170,255)
toggleBtn.TextColor3 = Color3.fromRGB(255,255,255)
toggleBtn.Parent = screenGui

local infoText = Instance.new("TextLabel")
infoText.Size = UDim2.new(0,260,0,25)
infoText.Position = UDim2.new(0,80,0,10)
infoText.BackgroundTransparency = 1
infoText.TextColor3 = Color3.fromRGB(255,255,255)
infoText.TextXAlignment = Enum.TextXAlignment.Left
infoText.Parent = screenGui

local boostBtn = Instance.new("TextButton")
boostBtn.Size = UDim2.new(0,72,0,28)
boostBtn.Position = UDim2.new(0,10,0,45)
boostBtn.Text = "BOOST"
boostBtn.BackgroundColor3 = Color3.fromRGB(255,90,90)
boostBtn.TextColor3 = Color3.fromRGB(255,255,255)
boostBtn.Parent = screenGui

local boostInfo = Instance.new("TextLabel")
boostInfo.Size = UDim2.new(0,260,0,28)
boostInfo.Position = UDim2.new(0,92,0,45)
boostInfo.BackgroundTransparency = 1
boostInfo.TextColor3 = Color3.fromRGB(255,255,255)
boostInfo.TextXAlignment = Enum.TextXAlignment.Left
boostInfo.Parent = screenGui

-- SETTINGS GUI
local settingsGui = Instance.new("ScreenGui")
settingsGui.ResetOnSpawn = false
settingsGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0,250,0,280) -- длиннее
frame.Position = UDim2.new(0,400,0,50)
frame.BackgroundColor3 = Color3.fromRGB(50,50,50)
frame.Active = true
frame.Draggable = true
frame.Parent = settingsGui

local collapseBtn = Instance.new("TextButton")
collapseBtn.Size = UDim2.new(0,25,0,25)
collapseBtn.Position = UDim2.new(1,-30,0,5)
collapseBtn.Text = "-"
collapseBtn.Parent = frame

local collapsed = false
collapseBtn.MouseButton1Click:Connect(function()
    collapsed = not collapsed
    for _,child in pairs(frame:GetChildren()) do
        if child ~= collapseBtn then
            child.Visible = not collapsed
        end
    end
    frame.Size = collapsed and UDim2.new(0,250,0,25) or UDim2.new(0,250,0,280)
    collapseBtn.Text = collapsed and "+" or "-"
end)

local function CreateSetting(name, default, posY)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0,120,0,25)
    label.Position = UDim2.new(0,10,0,posY)
    label.Text = name
    label.TextColor3 = Color3.fromRGB(255,255,255)
    label.BackgroundTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local input = Instance.new("TextBox")
    input.Size = UDim2.new(0,60,0,25)
    input.Position = UDim2.new(0,140,0,posY)
    input.Text = tostring(default)
    input.TextColor3 = Color3.fromRGB(0,0,0)
    input.BackgroundColor3 = Color3.fromRGB(200,200,200)
    input.ClearTextOnFocus = false
    input.Parent = frame

    return input
end

local normalStepsInput = CreateSetting("Шаги для апгрейда", NORMAL_UPGRADE_STEPS, 30)
local normalSpeedInput = CreateSetting("Скорость за апгрейд", 1, 60)
local boostStepsInput = CreateSetting("Шаги для буста", BOOST_UPGRADE_STEPS, 100)
local boostAmountInput = CreateSetting("Скорость буста", 1, 130)
local boostDurationInput = CreateSetting("Длительность буста", BOOST_DURATION, 160)
local boostCooldownInput = CreateSetting("Перезарядка буста", BOOST_COOLDOWN, 190)

local function ApplySettings()
    NORMAL_UPGRADE_STEPS = tonumber(normalStepsInput.Text) or NORMAL_UPGRADE_STEPS
    BOOST_UPGRADE_STEPS = tonumber(boostStepsInput.Text) or BOOST_UPGRADE_STEPS
    appliedUpgrades = 0
    currentBaseSpeed = baseWalkSpeed + (tonumber(normalSpeedInput.Text) or 1) * appliedUpgrades
    BOOST_DURATION = tonumber(boostDurationInput.Text) or BOOST_DURATION
    boostStored = 0
end

for _,input in pairs({normalStepsInput, normalSpeedInput, boostStepsInput, boostAmountInput, boostDurationInput, boostCooldownInput}) do
    input.FocusLost:Connect(function(enterPressed)
        ApplySettings()
    end)
end

-- SOUNDS
local function PlaySound(id, volume, speed, duration)
    if not rootPart then return end
    local s = Instance.new("Sound", rootPart)
    s.SoundId = "rbxassetid://"..id
    s.Volume = volume or 1
    s.PlaybackSpeed = speed or 1
    s.Looped = false
    s:Play()
    if duration then Debris:AddItem(s, duration) else Debris:AddItem(s,4) end
end

-- EFFECTS
local function UpgradeEffects()
    if not rootPart or boostActive then return end
    for i=1,5 do
        local p = Instance.new("ParticleEmitter")
        p.Texture = "rbxassetid://243660364"
        p.Lifetime = NumberRange.new(0.7,1)
        p.Speed = NumberRange.new(20,40)
        p.Rate = 200
        p.Size = NumberSequence.new({NumberSequenceKeypoint.new(0,3),NumberSequenceKeypoint.new(1,0)})
        p.Parent = rootPart
        Debris:AddItem(p,2)
    end
    PlaySound(8208591201,1,upgradeSoundSpeed,4)
    upgradeSoundSpeed += 0.01
end

local function BoostEffects()
    if not rootPart then return end
    local trail = Instance.new("Trail", rootPart)
    trail.Color = ColorSequence.new(Color3.new(1,0,0), Color3.new(1,1,0))
    trail.Lifetime = 0.7
    local att0 = Instance.new("Attachment", rootPart)
    local att1 = Instance.new("Attachment", rootPart)
    att0.Position = Vector3.new(-1,0,0)
    att1.Position = Vector3.new(1,0,0)
    trail.Attachment0 = att0
    trail.Attachment1 = att1
    Debris:AddItem(trail, BOOST_DURATION)
    Debris:AddItem(att0, BOOST_DURATION)
    Debris:AddItem(att1, BOOST_DURATION)
    PlaySound(9065112164,1,1,BOOST_DURATION)
end

local function PersistentEffects()
    if not rootPart or not humanoid then return end
    local speed = humanoid.WalkSpeed
    local moving = (rootPart.Velocity.Magnitude > 0.1)

    if moving then
        if speed >= 50 then
            for i=1,4 do
                local cube = Instance.new("Part")
                cube.Size = Vector3.new(2,2,2)
                cube.Anchored = true
                cube.CanCollide = false
                cube.Transparency = 0.3
                cube.Color = Color3.fromRGB(math.random(0,255), math.random(0,255),255)
                cube.CFrame = rootPart.CFrame * CFrame.new(math.random(-3,3),-2,math.random(-3,3))
                cube.Parent = workspace

                local light = Instance.new("PointLight")
                light.Brightness = 5
                light.Range = 8
                light.Color = cube.Color
                light.Parent = cube

                Debris:AddItem(cube,2)
                coroutine.wrap(function()
                    local t=0
                    while t<1 do
                        t += 0.03
                        cube.CFrame = cube.CFrame * CFrame.Angles(0.1,0.2,0.1)
                        task.wait(0.03)
                    end
                end)()
            end

            local ice = Instance.new("Part")
            ice.Size = Vector3.new(4,1,4)
            ice.Anchored = true
            ice.CanCollide = false
            ice.Transparency = 0.5
            ice.Color = Color3.fromRGB(173,216,230)
            ice.Material = Enum.Material.Ice
            ice.CFrame = rootPart.CFrame * CFrame.new(0,-3,0)
            ice.Parent = workspace
            Debris:AddItem(ice,1)
        end
    end

    if speed >= 150 then
        local cone = Instance.new("WedgePart")
        cone.Size = Vector3.new(4,2,4)
        cone.Anchored = true
        cone.CanCollide = false
        cone.Transparency = 0.7
        cone.Color = Color3.fromRGB(255,0,255)
        cone.CFrame = rootPart.CFrame * CFrame.new(0,-3,0) * CFrame.Angles(math.rad(180),0,0)
        cone.Parent = workspace
        Debris:AddItem(cone,0.5)
    end
end

-- CHARACTER
local function OnCharacterAdded(char)
    character = char
    humanoid = char:WaitForChild("Humanoid")
    rootPart = char:WaitForChild("HumanoidRootPart")
    baseWalkSpeed = humanoid.WalkSpeed
    currentBaseSpeed = baseWalkSpeed + appliedUpgrades
    humanoid.WalkSpeed = currentBaseSpeed
    lastPosition = rootPart.Position
end

if player.Character then OnCharacterAdded(player.Character) end
player.CharacterAdded:Connect(OnCharacterAdded)

-- GUI Update
local function UpdateInfo()
    if not humanoid then return end
    local stepsLeft = NORMAL_UPGRADE_STEPS - (stepTotal % NORMAL_UPGRADE_STEPS)
    infoText.Text = ("Speed: %d | Steps left: %d"):format(currentBaseSpeed, stepsLeft)

    if boostActive then
        local timeLeft = math.max(0, boostEndTime - tick())
        boostInfo.Text = ("Boost ACTIVE +%d | %.1fs left"):format(boostStored, timeLeft)
    elseif boostCooldown then
        local cooldownLeft = math.max(0, boostCooldownEnd - tick())
        boostInfo.Text = ("Boost recharge: %.1fs"):format(cooldownLeft)
    else
        boostInfo.Text = ("Boost Stored: +%d"):format(boostStored)
    end
end

-- BUTTONS
toggleBtn.MouseButton1Click:Connect(function()
    upgradesEnabled = not upgradesEnabled
    toggleBtn.Text = upgradesEnabled and "ON" or "OFF"
end)

boostBtn.MouseButton1Click:Connect(function()
    if not humanoid or boostActive or boostCooldown or boostStored==0 then return end
    boostActive = true
    humanoid.WalkSpeed = currentBaseSpeed + boostStored
    boostEndTime = tick() + BOOST_DURATION
    BoostEffects()
    task.delay(BOOST_DURATION, function()
        boostActive = false
        boostCooldown = true
        boostCooldownEnd = tick() + BOOST_COOLDOWN
        boostStored = 0
        humanoid.WalkSpeed = currentBaseSpeed
        task.delay(BOOST_COOLDOWN, function() boostCooldown = false end)
    end)
end)

-- MAIN LOOP
RunService.RenderStepped:Connect(function()
    if not humanoid or not rootPart then return end
    local currentPos = rootPart.Position
    local dist = (currentPos - lastPosition).Magnitude
    lastPosition = currentPos

    if dist > 0.01 then
        distanceCounter += dist
        while distanceCounter >= STEP_DISTANCE do
            distanceCounter -= STEP_DISTANCE
            stepTotal += 1
            if stepTotal % BOOST_UPGRADE_STEPS == 0 then boostStored += tonumber(boostAmountInput.Text) or 1 end
            if upgradesEnabled and stepTotal % NORMAL_UPGRADE_STEPS == 0 then
                appliedUpgrades += tonumber(normalSpeedInput.Text) or 1
                currentBaseSpeed = baseWalkSpeed + appliedUpgrades
                if not boostActive then humanoid.WalkSpeed = currentBaseSpeed end
                UpgradeEffects()
            end
        end
    end

    UpdateInfo()
    PersistentEffects()
end)
