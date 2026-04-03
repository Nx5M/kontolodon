-- // MULTI-EXECUTION PREVENTION //
if getgenv().Drift36Loaded then return end
getgenv().Drift36Loaded = true

-- // LOAD MILENIUM LIBRARY //
local library = loadstring(game:HttpGet("https://raw.githack.com/Nx5M/Millenium/refs/heads/main/nigga.lua"))()

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

-- // ADVANCED TELEPORT & SAFETY LOGIC //
local function MoveCarTo(targetCFrame)
    local araclarFolder = workspace:FindFirstChild("Araclar")
    local PlayerCar = araclarFolder and araclarFolder:FindFirstChild(LocalPlayer.Name .. "_spcar")
    local targetCharacter = LocalPlayer.Character

    local _, targetRotY, _ = targetCFrame:ToEulerAnglesYXZ()
    local finalCF = CFrame.new(targetCFrame.Position + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, targetRotY + math.pi, 0)

    if PlayerCar then
        if not PlayerCar:FindFirstChild("Wheels") or not PlayerCar:FindFirstChild("DriveSeat") then 
            return 
        end

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
                    mainPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    mainPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end
            end)
        else
            if mainPart then
                mainPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                mainPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end
            PlayerCar:PivotTo(finalCF)
        end
    elseif targetCharacter and targetCharacter.PrimaryPart then
        targetCharacter:PivotTo(finalCF)
    end
end

-- // INITIALIZE MILENIUM UI //
local Window = library:window({
    name = "Drift 36", 
    suffix = "Auto Farm",
    game_info = "v1.2.1 • @itsRaindrop",
    
    -- CUSTOMIZE THIS TEXT HERE:
    footer = "t.me/@itsRaindrop", 
    
    size = UDim2.new(0, 550, 0, 350)
})

-- Spawn our custom Mobile Toggle button so you can open/close it!
library:CreateMobileToggle(Window)

-- // MAIN TAB //
local MainTab = Window:tab({name = "Main", tabs = {"Configuration"}})
local MainCol = MainTab:column({size = 1})
local MainSec = MainCol:section({name = "Auto Farm Configuration", default = true})

MainSec:toggle({
    name = "Enable Auto Race", 
    info = "Turn on to start auto-farming the Solo Race",
    default = false,
    callback = function(state) isAutoRaceEnabled = state end
})

MainSec:dropdown({
    name = "Farm Mode",
    info = "Choose how the car moves",
    items = {"Instant", "Tween"},
    default = "Instant",
    callback = function(value) useTween = (value == "Tween") end
})

MainSec:slider({
    name = "Teleport Delay",
    info = "Time between teleports",
    min = 0.5,
    max = 10,
    interval = 0.5,
    default = 3,
    callback = function(value) teleportDelay = tonumber(value) end
})

-- // TELEPORTS TAB //
local TPTab = Window:tab({name = "Teleports", tabs = {"World"}})
local TPCol = TPTab:column({size = 1})
local TPSec = TPCol:section({name = "World Locations", default = true})

TPSec:button({name = "Spawn", callback = function() MoveCarTo(CFrame.new(718.8, 3.8, -1055.4)) end})
TPSec:button({name = "Dealership", callback = function() MoveCarTo(CFrame.new(577.4, 3.9, -1065.5)) end})
TPSec:button({name = "Modification/Garage", callback = function() MoveCarTo(CFrame.new(545.4, 3.0, -1348.4)) end})
TPSec:button({name = "Races", callback = function() MoveCarTo(CFrame.new(854.5, 3.0, -791.7)) end})

-- // WEBHOOK TAB //
local WebhookTab = Window:tab({name = "Webhook", tabs = {"Monitor"}})
local WebhookCol = WebhookTab:column({size = 1})
local WebhookSec = WebhookCol:section({name = "Remote Monitoring", default = true})

WebhookSec:textbox({
    name = "Discord Webhook URL",
    placeholder = "Paste URL here...",
    callback = function(text) webhookUrl = text end
})

WebhookSec:toggle({
    name = "Enable Live Dashboard",
    info = "Automatically updates a message in Discord",
    default = false,
    callback = function(state) 
        webhookEnabled = state 
        if state and webhookUrl ~= "" then UpdateDiscord(true) end
    end
})

-- // SETTINGS TAB //
local SettingsTab = Window:tab({name = "Settings", tabs = {"Manage"}})
local SettingsCol = SettingsTab:column({size = 1})
local SettingsSec = SettingsCol:section({name = "Script Management", default = true})

SettingsSec:button({name = "Rejoin Server", callback = function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end})
SettingsSec:button({
    name = "Unload Script", 
    callback = function()
        scriptRunning = false
        getgenv().Drift36Loaded = false 
        if library.unload_menu then library:unload_menu() end
        
        -- Clean up our custom mobile toggle
        local mobileToggle = coregui:FindFirstChild("MileniumMobileToggle")
        if mobileToggle then mobileToggle:Destroy() end
    end
})

-- // ANTI-AFK //
for _, v in next, getconnections(LocalPlayer.Idled) do v:Disable() end

-- // MEMORY LEAK & ERROR SPAM FIX //
task.spawn(function()
    while scriptRunning do
        if isAutoRaceEnabled then
            local aChassis = PlayerGui:FindFirstChild("A-Chassis Interface")
            if aChassis then
                aChassis:Destroy() 
            end
        end
        task.wait(0.5) 
    end
end)

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
