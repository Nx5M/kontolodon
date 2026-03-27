-- // MULTI-EXECUTION PREVENTION //
if getgenv().Drift36Loaded then return end
getgenv().Drift36Loaded = true

-- // LOAD WINDUI //
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- // CORE SERVICES //
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local RaceEventRE = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Race"):WaitForChild("RaceEvent")

-- // SCRIPT STATES //
local isAutoRaceEnabled = false
local useTween = false 
local teleportDelay = 3 
local scriptRunning = true 

-- // INITIALIZE WINDOW //
local Window = WindUI:CreateWindow({
    Title = "Drift 36",
    Icon = "car",
    Author = "Auto Farm",
    Folder = "Drift36UI",
    Size = UDim2.fromOffset(500, 300), 
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 170,
    HideSearchBar = true,
})

-- // EDIT OPEN BUTTON //
Window:EditOpenButton({
    Title = "", 
    Icon = "menu",
    CornerRadius = UDim.new(1, 0),
    StrokeThickness = 1,
    Color = ColorSequence.new(
        Color3.fromHex("FF0F7B"), 
        Color3.fromHex("F89B29")
    ),
    OnlyMobile = true,
    Enabled = true,
    Draggable = true,
})

-- // TOP BAR TAGS //
Window:Tag({
    Title = "v1.0.0",
    Icon = "github",
    Color = Color3.fromHex("#30ff6a"),
    Radius = 4, 
})

Window:Tag({
    Title = "@itsRaindrop", 
    Icon = "send",      
    Color = Color3.fromHex("#24A1DE"), 
    Radius = 4, 
})

-- // TABS //
local MainTab = Window:Tab({ Title = "Main", Icon = "house" })
local TPTab = Window:Tab({ Title = "Teleports", Icon = "map-pin" })
local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })
local AboutTab = Window:Tab({ Title = "About", Icon = "info" })

-- // MAIN TAB CONTENT //
MainTab:Section({ Title = "Auto Farm Configuration" })

MainTab:Toggle({
    Title = "Enable Auto Race",
    Desc = "Turn on to start auto-farming the Solo Race",
    Default = false,
    Callback = function(state)
        isAutoRaceEnabled = state
    end
})

MainTab:Dropdown({
    Title = "Farm Mode",
    Desc = "Choose how the car moves to checkpoints",
    Value = "Instant",
    Values = {"Instant", "Tween"},
    Callback = function(value)
        useTween = (value == "Tween")
    end
})

MainTab:Slider({
    Title = "Teleport Delay",
    Desc = "Time between teleports (Lower = Faster, but may cause kick!)",
    Step = 0.5,
    Value = {
        Min = 0.5,
        Max = 10,
        Default = 3,
    },
    Callback = function(value)
        teleportDelay = tonumber(value)
    end
})

-- // EXACT TELEPORT LOGIC //
local function MoveCarTo(targetCFrame)
    local araclarFolder = workspace:FindFirstChild("Araclar")
    local PlayerCar = araclarFolder and araclarFolder:FindFirstChild(LocalPlayer.Name .. "_spcar")
    local targetCharacter = LocalPlayer.Character

    if PlayerCar then
        local currentCF = PlayerCar:GetPivot()
        local lockedOrientationCF = CFrame.new(targetCFrame.Position) * currentCF.Rotation
        local mainPart = PlayerCar.PrimaryPart or PlayerCar:FindFirstChildWhichIsA("BasePart")

        if useTween then
            if mainPart then mainPart.Anchored = true end
            local cframeVal = Instance.new("CFrameValue")
            cframeVal.Value = currentCF
            local connection = cframeVal.Changed:Connect(function(newCF)
                if PlayerCar and PlayerCar.Parent then
                    PlayerCar:PivotTo(newCF)
                    if mainPart then
                        mainPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        mainPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    end
                end
            end)
            local tweenInfo = TweenInfo.new(math.max(teleportDelay - 0.1, 0.1), Enum.EasingStyle.Linear)
            local tween = TweenService:Create(cframeVal, tweenInfo, {Value = lockedOrientationCF})
            tween:Play()
            tween.Completed:Connect(function()
                connection:Disconnect()
                cframeVal:Destroy()
                if mainPart then mainPart.Anchored = false end
            end)
        else
            if mainPart then
                mainPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                mainPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end
            PlayerCar:PivotTo(lockedOrientationCF)
        end
    elseif targetCharacter and targetCharacter.PrimaryPart then
        targetCharacter:PivotTo(targetCFrame)
    end
end

-- // TELEPORTS TAB CONTENT //
TPTab:Section({ Title = "World Locations" })

TPTab:Button({
    Title = "Spawn",
    Callback = function() MoveCarTo(CFrame.new(718.8, 3.8, -1055.4)) end
})

TPTab:Button({
    Title = "Dealership",
    Callback = function() MoveCarTo(CFrame.new(577.4, 3.9, -1065.5)) end
})

TPTab:Button({
    Title = "Modification/Garage",
    Callback = function() MoveCarTo(CFrame.new(545.4, 3.0, -1348.4)) end
})

TPTab:Button({
    Title = "Races",
    Callback = function() MoveCarTo(CFrame.new(854.5, 3.0, -791.7)) end
})

-- // SETTINGS TAB CONTENT //
SettingsTab:Section({ Title = "UI Configuration" })

SettingsTab:Keybind({
    Title = "UI Toggle Key",
    Desc = "Change the key used to open/close the menu",
    Value = "RightShift",
    Callback = function(v)
        Window:SetToggleKey(Enum.KeyCode[v])
    end
})

SettingsTab:Section({ Title = "Script Management" })

SettingsTab:Button({
    Title = "Rejoin Server",
    Desc = "Quickly reconnect to a fresh server",
    Callback = function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end
})

SettingsTab:Button({
    Title = "Unload Script",
    Desc = "Completely kills the background loops and destroys the UI",
    Callback = function()
        scriptRunning = false
        getgenv().Drift36Loaded = false 
        getgenv().SCRIPT_KEY = nil 
        if Window.Destroy then
            Window:Destroy()
        end
    end
})

-- // ABOUT TAB CONTENT //
AboutTab:Section({ Title = "Socials" })

AboutTab:Button({
    Title = "Copy Telegram",
    Desc = "@itsRaindrop for updates and bug reports",
    Callback = function()
        setclipboard("https://t.me/itsRaindrop")
        WindUI:Notify({
            Title = "Success",
            Content = "Telegram link copied to clipboard!",
            Duration = 3
        })
    end
})

-- // ANTI-AFK //
for _, v in next, getconnections(LocalPlayer.Idled) do 
    v:Disable() 
end

-- // MAIN AUTO FARM LOOP //
task.spawn(function()
    while scriptRunning do
        if isAutoRaceEnabled then
            local araclarFolder = workspace:FindFirstChild("Araclar")
            local PlayerCar = araclarFolder and araclarFolder:FindFirstChild(LocalPlayer.Name .. "_spcar")
            
            if PlayerCar then
                local ClientObjects = workspace:FindFirstChild("SoloRace_ClientObjects")
                if not ClientObjects then
                    RaceEventRE:FireServer({
                        action = "EnterRaceZone",
                        raceId = "SoloRace"
                    })
                else
                    local Checkpoints = workspace:FindFirstChild("SoloRace_ServerCheckpoints")
                    if Checkpoints then
                        local raceGui = PlayerGui:FindFirstChild("General")
                        if raceGui then
                            local modules = raceGui:FindFirstChild("Modules")
                            if modules then
                                local rGui = modules:FindFirstChild("RaceGui")
                                if rGui then
                                    local checkpoint = rGui:FindFirstChild("checkpoint")
                                    if checkpoint then
                                        local infoLabel = checkpoint:FindFirstChild("InfoText")
                                        if infoLabel and infoLabel.Text then
                                            local CurrentPointArr = infoLabel.Text:split("/")
                                            if CurrentPointArr[1] and CurrentPointArr[2] then
                                                local CurLap = tonumber(CurrentPointArr[1])
                                                local LapMax = tonumber(CurrentPointArr[2])
                                                if CurLap and LapMax then
                                                    if CurLap == LapMax then
                                                        MoveCarTo(Checkpoints.ServerFinishLine.CFrame)
                                                    else
                                                        local LapFound = Checkpoints:FindFirstChild(tostring(CurLap + 1))
                                                        if LapFound then
                                                            MoveCarTo(LapFound.CFrame)
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        task.wait(isAutoRaceEnabled and teleportDelay or 1)
    end
end)

Window:SelectTab(1)

WindUI:Notify({
    Title = "Drift 36 Script",
    Content = "loaded successfully.",
    Duration = 3
})
