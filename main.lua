-- Services
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local scriptRunning = true -- Global killswitch

-- Safe Storage Folder (Kept in script memory)
local SafeStorage = Instance.new("Folder")

-- References to track original locations for toggling
local enemyDmgRemote = nil
local enemyDmgParent = nil
local afkRemote = nil
local afkParent = nil

-- Cache original positions on script startup
local wdoReplicated = ReplicatedStorage:WaitForChild("WDOReplicatedStorage", 5)
local events = wdoReplicated and wdoReplicated:WaitForChild("Events", 5)
if events then
    enemyDmgRemote = events:FindFirstChild("enemyDamage")
    enemyDmgParent = events
    
    afkRemote = events:FindFirstChild("setAFK")
    afkParent = events
end

-- Fixed Order Map List (Strictly ordered top to bottom)
local mapList = {
    "Belimir",
    "Slime Cave",
    "Bandit Hideout",
    "Mushroom Forest",
    "Courtyard",
    "Overgrown Cavern",
    "Lyseria Desert",
    "Frozen Lake",
    "Skycloud Islands",
    "Alstigar Darkswamp"
}
local selectedMapIndex = 1

-- Feature States
local godModeActive = false
local antiAfkActive = false
local bringEnemiesActive = false
local anchorActive = false
local autoExecuteActive = false
local autoVoteActive = false
local autoM1Active = false
local autoXActive = false
local autoRActive = false
local autoTActive = false
local autoGActive = false

-- GUI Setup
local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local Title = Instance.new("TextLabel")
local CloseBtn = Instance.new("TextButton")
local TabBar = Instance.new("Frame")
local CombatTabBtn = Instance.new("TextButton")
local MiscTabBtn = Instance.new("TextButton")
local Container = Instance.new("ScrollingFrame")
local UIListLayout = Instance.new("UIListLayout")
local UIPadding = Instance.new("UIPadding")

ScreenGui.Name = "InternalUiPanelV18"
ScreenGui.Parent = game:GetService("CoreGui") 
ScreenGui.ResetOnSpawn = false

MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 260, 0, 360) -- Extended slightly for the dual-line header
MainFrame.Position = UDim2.new(0.5, -130, 0.5, -180)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

-- Custom Dual-Line Title Block
Title.Size = UDim2.new(1, 0, 0, 45)
Title.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Text = "explosion's doohickey\nk to toggle visibility"
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 14
Title.TextWrapped = true
Title.Parent = MainFrame

CloseBtn.Name = "CloseBtn"
CloseBtn.Size = UDim2.new(0, 25, 0, 25)
CloseBtn.Position = UDim2.new(1, -30, 0, 10) -- Centered vertically with the new header height
CloseBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
CloseBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
CloseBtn.Text = "X"
CloseBtn.Font = Enum.Font.SourceSansBold
CloseBtn.TextSize = 14
CloseBtn.Parent = MainFrame

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 5)
CloseCorner.Parent = CloseBtn

-- Tab Navigation Bar
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1, 0, 0, 30)
TabBar.Position = UDim2.new(0, 0, 0, 45)
TabBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
TabBar.BorderSizePixel = 0
TabBar.Parent = MainFrame

local function createTabButton(text, xScalePosition)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.5, 0, 1, 0)
    btn.Position = UDim2.new(xScalePosition, 0, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    btn.BorderSizePixel = 0
    btn.TextColor3 = Color3.fromRGB(180, 180, 180)
    btn.Text = text
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 14
    btn.Parent = TabBar
    return btn
end

CombatTabBtn = createTabButton("Combat", 0)
MiscTabBtn = createTabButton("Misc", 0.5)

-- Feature Items Container
Container.Size = UDim2.new(1, 0, 1, -75)
Container.Position = UDim2.new(0, 0, 0, 75)
Container.BackgroundTransparency = 1
Container.BorderSizePixel = 0
Container.ScrollBarThickness = 4
Container.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
Container.CanvasSize = UDim2.new(0, 0, 0, 390) 
Container.Parent = MainFrame

UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 6)
UIListLayout.Parent = Container

UIPadding.PaddingTop = UDim.new(0, 6)
UIPadding.Parent = Container

local registry = {} 

local function createToggleButton(text, tabGroup)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.92, 0, 0, 38)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.TextColor3 = Color3.fromRGB(230, 230, 230)
    btn.Text = text .. " : OFF"
    btn.Font = Enum.Font.SourceSansSemibold
    btn.TextSize = 14
    btn.Parent = Container
    
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 5)
    UICorner.Parent = btn
    
    table.insert(registry, {Instance = btn, Tab = tabGroup})
    return btn
end

-- Instantiate Tabbed Features
local GodModeBtn = createToggleButton("God Mode", "Combat")
local BringEnemiesBtn = createToggleButton("Bring Enemies", "Combat")
local AutoExecuteBtn = createToggleButton("Auto Execute", "Combat")
local AutoM1Btn = createToggleButton("Auto M1 [Z]", "Combat")
local AutoXBtn = createToggleButton("Auto X", "Combat")
local AutoRBtn = createToggleButton("Auto R", "Combat")
local AutoTBtn = createToggleButton("Auto T", "Combat")
local AutoGBtn = createToggleButton("Auto G", "Combat")

local AntiAfkBtn = createToggleButton("Anti-AFK", "Misc")
local AnchorBtn = createToggleButton("Anchor Character", "Misc")
local MapTargetBtn = createToggleButton("Vote Target", "Misc")
MapTargetBtn.Text = "Target: " .. tostring(mapList[selectedMapIndex])
local AutoVoteBtn = createToggleButton("Auto Vote", "Misc")

-- Tab Switching Logic
local function switchTab(activeTabName)
    if activeTabName == "Combat" then
        CombatTabBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        CombatTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        MiscTabBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        MiscTabBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
    else
        MiscTabBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        MiscTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        CombatTabBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        CombatTabBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
    end
    
    for _, item in ipairs(registry) do
        item.Instance.Visible = (item.Tab == activeTabName)
    end
end

CombatTabBtn.MouseButton1Click:Connect(function() switchTab("Combat") end)
MiscTabBtn.MouseButton1Click:Connect(function() switchTab("Misc") end)
switchTab("Combat") 

-- UI Dragging Logic
local dragging, dragInput, dragStart, startPos
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

MainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local function updateButtonVisual(button, activeState, text)
    if activeState then
        button.Text = text .. " : ON"
        button.BackgroundColor3 = Color3.fromRGB(39, 174, 96)
    else
        button.Text = text .. " : OFF"
        button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    end
end

-- Centralized Auto M1 Toggle
local function toggleAutoM1()
    if not scriptRunning then return end
    autoM1Active = not autoM1Active
    updateButtonVisual(AutoM1Btn, autoM1Active, "Auto M1 [Z]")
    if not autoM1Active then
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end
end

-- Keybind Handler (K and Z)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or not scriptRunning then return end
    if input.KeyCode == Enum.KeyCode.K then
        MainFrame.Visible = not MainFrame.Visible
    elseif input.KeyCode == Enum.KeyCode.Z then
        toggleAutoM1()
    end
end)

-- Feature Action Connectors
GodModeBtn.MouseButton1Click:Connect(function()
    godModeActive = not godModeActive
    updateButtonVisual(GodModeBtn, godModeActive, "God Mode")
    if enemyDmgRemote then
        enemyDmgRemote.Parent = godModeActive and SafeStorage or enemyDmgParent
    end
end)

AntiAfkBtn.MouseButton1Click:Connect(function()
    antiAfkActive = not antiAfkActive
    updateButtonVisual(AntiAfkBtn, antiAfkActive, "Anti-AFK")
    if afkRemote then
        afkRemote.Parent = antiAfkActive and SafeStorage or afkParent
    end
end)

AnchorBtn.MouseButton1Click:Connect(function()
    anchorActive = not anchorActive
    updateButtonVisual(AnchorBtn, anchorActive, "Anchor Character")
    if LocalPlayer.Character then
        local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then root.Anchored = anchorActive end
    end
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    if anchorActive and scriptRunning then
        local root = char:WaitForChild("HumanoidRootPart", 5)
        if root then root.Anchored = true end
    end
end)

BringEnemiesBtn.MouseButton1Click:Connect(function()
    bringEnemiesActive = not bringEnemiesActive
    updateButtonVisual(BringEnemiesBtn, bringEnemiesActive, "Bring Enemies")
    if not bringEnemiesActive then
        local spawnedEnemies = Workspace:FindFirstChild("SpawnedEnemies")
        if spawnedEnemies then
            for _, enemy in ipairs(spawnedEnemies:GetChildren()) do
                if enemy:IsA("Model") then
                    local root = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
                    if root then root.Anchored = false end
                end
            end
        end
    end
end)

AutoExecuteBtn.MouseButton1Click:Connect(function()
    autoExecuteActive = not autoExecuteActive
    updateButtonVisual(AutoExecuteBtn, autoExecuteActive, "Auto Execute")
end)

-- Map Target Selector (Cycles Top to Bottom sequential order)
MapTargetBtn.MouseButton1Click:Connect(function()
    selectedMapIndex = selectedMapIndex + 1
    if selectedMapIndex > #mapList then
        selectedMapIndex = 1
    end
    MapTargetBtn.Text = "Target: " .. tostring(mapList[selectedMapIndex])
end)

AutoVoteBtn.MouseButton1Click:Connect(function()
    autoVoteActive = not autoVoteActive
    updateButtonVisual(AutoVoteBtn, autoVoteActive, "Auto Vote")
end)

AutoM1Btn.MouseButton1Click:Connect(toggleAutoM1)
AutoXBtn.MouseButton1Click:Connect(function() autoXActive = not autoXActive updateButtonVisual(AutoXBtn, autoXActive, "Auto X") end)
AutoRBtn.MouseButton1Click:Connect(function() autoRActive = not autoRActive updateButtonVisual(AutoRBtn, autoRActive, "Auto R") end)
AutoTBtn.MouseButton1Click:Connect(function() autoTActive = not autoTActive updateButtonVisual(AutoTBtn, autoTActive, "Auto T") end)
AutoGBtn.MouseButton1Click:Connect(function() autoGActive = not autoGActive updateButtonVisual(AutoGBtn, autoGActive, "Auto G") end)

-- DeadEnemies Cleaner Connection
local deadEnemiesFolder = Workspace:FindFirstChild("DeadEnemies")
local deadCleanerConnection
if deadEnemiesFolder then
    for _, corpse in ipairs(deadEnemiesFolder:GetChildren()) do
        corpse:Destroy()
    end
    deadCleanerConnection = deadEnemiesFolder.ChildAdded:Connect(function(child)
        if child then
            task.wait()
            child:Destroy()
        end
    end)
end

-- Safe Click Simulation Handler
local function clickGuiButton(button)
    if not button then return end
    
    if firesignal then
        pcall(function() firesignal(button.MouseButton1Click) end)
        pcall(function() firesignal(button.Activated) end)
    end
    
    pcall(function()
        local pos = button.AbsolutePosition
        local size = button.AbsoluteSize
        local cX = pos.X + (size.X / 2)
        local cY = pos.Y + (size.Y / 2)
        VirtualInputManager:SendMouseButtonEvent(cX, cY, 0, true, game, 0)
        task.wait(0.01)
        VirtualInputManager:SendMouseButtonEvent(cX, cY, 0, false, game, 0)
    end)
end

-- Full Shutdown Destruction Hook
CloseBtn.MouseButton1Click:Connect(function()
    scriptRunning = false
    if deadCleanerConnection then deadCleanerConnection:Disconnect() end
    
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    
    if enemyDmgRemote and enemyDmgParent then enemyDmgRemote.Parent = enemyDmgParent end
    if afkRemote and afkParent then afkRemote.Parent = afkParent end
    
    if LocalPlayer.Character then
        local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then root.Anchored = false end
    end
    
    local spawnedEnemies = Workspace:FindFirstChild("SpawnedEnemies")
    if spawnedEnemies then
        for _, enemy in ipairs(spawnedEnemies:GetChildren()) do
            if enemy:IsA("Model") then
                local root = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
                if root then root.Anchored = false end
            end
        end
    end
    
    SafeStorage:Destroy()
    ScreenGui:Destroy()
end)

-- Background Processing Loops

-- Loop 1: Enemy Tracking / Standard Cleanup Loop
task.spawn(function()
    while scriptRunning do
        task.wait(0.05)
        if not scriptRunning then break end
        
        local spawnedEnemies = Workspace:FindFirstChild("SpawnedEnemies")
        if spawnedEnemies then
            for _, enemy in ipairs(spawnedEnemies:GetChildren()) do
                if enemy:IsA("Model") then
                    local humanoid = enemy:FindFirstChildOfClass("Humanoid")
                    
                    if humanoid and humanoid.Health <= 0 then
                        enemy:Destroy()
                    elseif bringEnemiesActive and LocalPlayer.Character then
                        local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if myRoot then
                            local targetPosition = myRoot.CFrame * CFrame.new(0, 0, -4)
                            local enemyRoot = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
                            if enemyRoot then
                                enemyRoot.Anchored = true
                                enemyRoot.CFrame = targetPosition
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- Loop 2: Performance-Friendly Auto Execute Loop
task.spawn(function()
    while scriptRunning do
        task.wait(0.1)
        if not scriptRunning then break end
        
        if autoExecuteActive and LocalPlayer.Character then
            local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local spawnedEnemies = Workspace:FindFirstChild("SpawnedEnemies")
            
            if myRoot and spawnedEnemies then
                for _, enemy in ipairs(spawnedEnemies:GetChildren()) do
                    if enemy:IsA("Model") then
                        local enemyRoot = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
                        if enemyRoot and (myRoot.Position - enemyRoot.Position).Magnitude <= 10 then
                            
                            for _, prompt in ipairs(enemy:GetDescendants()) do
                                if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                                    if fireproximityprompt then
                                        fireproximityprompt(prompt)
                                    else
                                        task.spawn(function()
                                            prompt:InputHoldBegin()
                                            task.wait(prompt.HoldDuration)
                                            prompt:InputHoldEnd()
                                        end)
                                    end
                                end
                            end
                            
                        end
                    end
                end
            end
        end
    end
end)

-- Loop 3: Clean Sequential Auto-Vote Loop
task.spawn(function()
    while scriptRunning do
        task.wait(0.3)
        if not scriptRunning then break end
        
        if autoVoteActive then
            local targetMapName = mapList[selectedMapIndex]
            if targetMapName then
                
                -- METHOD A: Direct Server Remote Broadcast
                if events then
                    local mapVoteRemote = events:FindFirstChild("mapVote")
                    if mapVoteRemote and mapVoteRemote:IsA("RemoteEvent") then
                        pcall(function() mapVoteRemote:FireServer(targetMapName) end)
                    end
                end
                
                -- METHOD B: Client UI Click Simulation Fallback wrapped inside a safety gate
                pcall(function()
                    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                    local uiPackage = playerGui and playerGui:FindFirstChild("UIPackage")
                    local mapVote = uiPackage and (uiPackage:FindFirstChild("MapVote") or uiPackage:FindFirstChild("MapVoting"))
                    
                    if mapVote then
                        local frame = mapVote:FindFirstChild("Frame")
                        local holder = frame and frame:FindFirstChild("Holder")
                        local scrollingFrame = holder and holder:FindFirstChild("ScrollingFrame")
                        local infoHolder = frame and frame:FindFirstChild("InfoHolder")
                        local voteButton = infoHolder and infoHolder:FindFirstChild("VoteButton")
                        
                        if scrollingFrame and voteButton then
                            local targetMapSelectionBtn = scrollingFrame:FindFirstChild(targetMapName)
                            if targetMapSelectionBtn then
                                clickGuiButton(targetMapSelectionBtn)
                                task.wait(0.05)
                                clickGuiButton(voteButton)
                            end
                        end
                    end
                end)
                
            end
        end
    end
end)

-- Loop 4: Macro Automations
task.spawn(function()
    while scriptRunning do
        task.wait(0.08)
        if not scriptRunning then break end
        if autoM1Active then
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            task.wait(0.02)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        end
    end
end)

task.spawn(function()
    while scriptRunning do
        task.wait(0.2)
        if not scriptRunning then break end
        if autoXActive then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.X, false, game)
            task.wait(0.02)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.X, false, game)
        end
    end
end)

task.spawn(function()
    while scriptRunning do
        task.wait(0.2)
        if not scriptRunning then break end
        if autoRActive then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game)
            task.wait(0.02)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game)
        end
    end
end)

task.spawn(function()
    while scriptRunning do
        task.wait(0.2)
        if not scriptRunning then break end
        if autoTActive then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.T, false, game)
            task.wait(0.02)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.T, false, game)
        end
    end
end)

task.spawn(function()
    while scriptRunning do
        task.wait(0.2)
        if not scriptRunning then break end
        if autoGActive then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.G, false, game)
            task.wait(0.02)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.G, false, game)
        end
    end
end)
