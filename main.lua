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
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local RaceEventRE = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Race"):WaitForChild("RaceEvent")

-- // SCRIPT STATES //
local isAutoRaceEnabled = false
local useTween = false 
local teleportDelay = 3 
local scriptRunning = true 

-- // WEBHOOK STATES //
local webhookUrl = ""
local webhookEnabled = false
local msg_file = "drift36_solo_webhook.txt"
local startTime = tick()
local racesCompleted = 0
local startCash = -1 

local function GetCash()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        local money = leaderstats:FindFirstChild("Money") or leaderstats:FindFirstChild("Cash")
        if money then return money.Value end
    end
    return 0
end

local function FormatNum(amount)
    local formatted = tostring(math.floor(amount))
    while true do  
        local k
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k==0) then break end
    end
    return formatted
end

local function FormatTime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function UpdateDiscord(forceNew)
    if not webhookEnabled or webhookUrl == "" then return end
    task.spawn(function()
        local curCash = GetCash()
        if startCash == -1 and curCash > 0 then startCash = curCash end
        local earned = startCash ~= -1 and (curCash - startCash) or 0
        local elapsed = tick() - startTime

        local data = {
            ["embeds"] = {{
                ["title"] = "🏎️ Drift 36 Solo Farm: " .. LocalPlayer.Name,
                ["color"] = 10181046,
                ["fields"] = {
                    {["name"] = "💵 Current Cash", ["value"] = "**$" .. FormatNum(curCash) .. "**", ["inline"] = true},
                    {["name"] = "💸 Session Profit", ["value"] = "**+$" .. FormatNum(earned) .. "**", ["inline"] = true},
                    {["name"] = "🏁 Races Finished", ["value"] = "**" .. tostring(racesCompleted) .. "**", ["inline"] = true},
                    {["name"] = "⏱️ Time Elapsed", ["value"] = "**" .. FormatTime(elapsed) .. "**", ["inline"] = true}
                },
                ["footer"] = {["text"] = "made by @itsraindrop on Telegram • " .. os.date("%X")},
                ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }}
        }

        local req = (syn and syn.request) or (http and http.request) or http_request or request
        if not req then return end

        local existingID = (not forceNew) and isfile and isfile(msg_file) and readfile(msg_file)
        local method, url = "POST", webhookUrl .. "?wait=true"
        
        if existingID and existingID ~= "" then 
            method, url = "PATCH", webhookUrl .. "/messages/" .. existingID .. "?wait=true" 
        end

        local success, response = pcall(function() 
            return req({Url = url, Method = method, Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)}) 
        end)

        if success and response.Success and method == "POST" then
            local resData = HttpService:JSONDecode(response.Body)
            if resData and resData.id and writefile then writefile(msg_file, resData.id) end
        elseif method == "PATCH" and not response.Success then 
            if writefile then writefile(msg_file, "") end 
            UpdateDiscord(true) 
        end
    end)
end

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
    Color = ColorSequence.new(Color3.fromHex("FF0F7B"), Color3.fromHex("F89B29")),
    OnlyMobile = true, Enabled = true, Draggable = true,
})

-- // TOP BAR TAGS //
Window:Tag({ Title = "v1.2.0", Icon = "github", Color = Color3.fromHex("#30ff6a"), Radius = 4 })
Window:Tag({ Title = "@itsRaindrop", Icon = "send", Color = Color3.fromHex("#24A1DE"), Radius = 4 })

-- // TABS //
local MainTab = Window:Tab({ Title = "Main", Icon = "house" })
local TPTab = Window:Tab({ Title = "Teleports", Icon = "map-pin" })
local WebhookTab = Window:Tab({ Title = "Webhook", Icon = "activity" }) -- NEW DEDICATED TAB
local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })
local AboutTab = Window:Tab({ Title = "About", Icon = "info" })

-- // MAIN TAB CONTENT //
MainTab:Section({ Title = "Auto Farm Configuration" })

MainTab:Toggle({
    Title = "Enable Auto Race",
    Desc = "Turn on to start auto-farming the Solo Race",
    Default = false,
    Callback = function(state) isAutoRaceEnabled = state end
})

MainTab:Dropdown({
    Title = "Farm Mode",
    Desc = "Choose how the car moves to checkpoints",
    Value = "Instant",
    Values = {"Instant", "Tween"},
    Callback = function(value) useTween = (value == "Tween") end
})

MainTab:Slider({
    Title = "Teleport Delay",
    Desc = "Time between teleports (Lower = Faster, but higher kick risk!)",
    Step = 0.5,
    Value = { Min = 0.5, Max = 10, Default = 3 },
    Callback = function(value) teleportDelay = tonumber(value) end
})

-- // ADVANCED TELEPORT LOGIC //
local function MoveCarTo(targetCFrame)
    local araclarFolder = workspace:FindFirstChild("Araclar")
    local PlayerCar = araclarFolder and araclarFolder:FindFirstChild(LocalPlayer.Name .. "_spcar")
    local targetCharacter = LocalPlayer.Character

    local _, targetRotY, _ = targetCFrame:ToEulerAnglesYXZ()
    local finalCF = CFrame.new(targetCFrame.Position + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, targetRotY + math.pi, 0)

    if PlayerCar then
        local mainPart = PlayerCar.PrimaryPart or PlayerCar:FindFirstChildWhichIsA("BasePart")

        if useTween then
            if mainPart then mainPart.Anchored = true end
            local cframeVal = Instance.new("CFrameValue")
            cframeVal.Value = PlayerCar:GetPivot()
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
            local tween = TweenService:Create(cframeVal, tweenInfo, {Value = finalCF})
            tween:Play()
            tween.Completed:Connect(function()
                connection:Disconnect()
                cframeVal:Destroy()
                if mainPart then 
                    mainPart.Anchored = false 
                    mainPart.AssemblyLinearVelocity = Vector3.new(0, -65, 0)
                    mainPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end
            end)
        else
            if mainPart then
                mainPart.AssemblyLinearVelocity = Vector3.new(0, -65, 0)
                mainPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end
            PlayerCar:PivotTo(finalCF)
        end
    elseif targetCharacter and targetCharacter.PrimaryPart then
        targetCharacter:PivotTo(finalCF)
    end
end

-- // TELEPORTS TAB CONTENT //
TPTab:Section({ Title = "World Locations" })
TPTab:Button({ Title = "Spawn", Callback = function() MoveCarTo(CFrame.new(718.8, 3.8, -1055.4)) end })
TPTab:Button({ Title = "Dealership", Callback = function() MoveCarTo(CFrame.new(577.4, 3.9, -1065.5)) end })
TPTab:Button({ Title = "Modification/Garage", Callback = function() MoveCarTo(CFrame.new(545.4, 3.0, -1348.4)) end })
TPTab:Button({ Title = "Races", Callback = function() MoveCarTo(CFrame.new(854.5, 3.0, -791.7)) end })

-- // WEBHOOK TAB CONTENT //
WebhookTab:Section({ Title = "Remote Monitoring" })

WebhookTab:Input({
    Title = "Discord Webhook URL",
    Desc = "Paste your webhook URL here",
    Default = "",
    Callback = function(text) webhookUrl = text end
})

WebhookTab:Toggle({
    Title = "Enable Live Dashboard",
    Desc = "Automatically updates a single message in Discord",
    Default = false,
    Callback = function(state) 
        webhookEnabled = state 
        if state and webhookUrl ~= "" then UpdateDiscord(true) end
    end
})

-- // SETTINGS TAB CONTENT //
SettingsTab:Section({ Title = "UI Configuration" })

SettingsTab:Keybind({
    Title = "UI Toggle Key",
    Desc = "Change the key used to open/close the menu",
    Value = "RightShift",
    Callback = function(v) Window:SetToggleKey(Enum.KeyCode[v]) end
})

SettingsTab:Section({ Title = "Script Management" })

SettingsTab:Button({
    Title = "Rejoin Server",
    Desc = "Quickly reconnect to a fresh server",
    Callback = function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end
})

SettingsTab:Button({
    Title = "Unload Script",
    Desc = "Completely kills background loops and destroys UI",
    Callback = function()
        scriptRunning = false
        getgenv().Drift36Loaded = false 
        getgenv().SCRIPT_KEY = nil 
        if Window.Destroy then Window:Destroy() end
    end
})

-- // ABOUT TAB CONTENT //
AboutTab:Section({ Title = "Socials" })
AboutTab:Button({
    Title = "Copy Telegram",
    Desc = "@itsRaindrop for updates",
    Callback = function()
        setclipboard("https://t.me/itsRaindrop")
        WindUI:Notify({ Title = "Success", Content = "Telegram link copied!", Duration = 3 })
    end
})

-- // ANTI-AFK //
for _, v in next, getconnections(LocalPlayer.Idled) do v:Disable() end

-- // MAIN AUTO FARM LOOP //
task.spawn(function()
    while scriptRunning do
        if isAutoRaceEnabled then
            local araclarFolder = workspace:FindFirstChild("Araclar")
            local PlayerCar = araclarFolder and araclarFolder:FindFirstChild(LocalPlayer.Name .. "_spcar")
            
            if PlayerCar then
                local ClientObjects = workspace:FindFirstChild("SoloRace_ClientObjects")
                if not ClientObjects then
                    RaceEventRE:FireServer({ action = "EnterRaceZone", raceId = "SoloRace" })
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
                                                        racesCompleted = racesCompleted + 1
                                                        UpdateDiscord(false)
                                                        task.wait(1.5)
                                                    else
                                                        local LapFound = Checkpoints:FindFirstChild(tostring(CurLap + 1))
                                                        if LapFound then MoveCarTo(LapFound.CFrame) end
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
WindUI:Notify({ Title = "Drift 36 Script", Content = "v1.2.0 loaded successfully.", Duration = 5 })
