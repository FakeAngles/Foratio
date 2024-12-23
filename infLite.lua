local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local SpawnedVehicles = workspace:WaitForChild("SpawnedVehicles")
local RunService = game:GetService("RunService")

local active = true
local currentClosestVehicle

local function getDistance(a, b)
    return (a - b).Magnitude
end

local function getClosestVehicle()
    local playerPos = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position
    if not playerPos then return nil end

    local closest, shortest = nil, math.huge
    for _, vehicle in ipairs(SpawnedVehicles:GetChildren()) do
        local part = vehicle:FindFirstChild("HumanoidRootPart") or vehicle.PrimaryPart
        if part then
            local dist = getDistance(playerPos, part.Position)
            if dist < shortest then
                closest, shortest = vehicle, dist
            end
        end
    end
    return closest
end

local function freezeValue(prop)
    local value = prop.Value
    prop.Changed:Connect(function()
        if active and prop.Value ~= value then
            prop.Value = value
        end
    end)
    prop.Value = value
end

local function freezeWeapons(vehicle)
    if not vehicle or vehicle == currentClosestVehicle then return end
    currentClosestVehicle = vehicle

    local turrets = vehicle:FindFirstChild("Turrets")
    if turrets then
        for _, turret in ipairs(turrets:GetChildren()) do
            local weapons = turret:FindFirstChild("Weapons")
            if weapons then
                for _, weapon in ipairs(weapons:GetChildren()) do
                    if weapon:FindFirstChild("CurrentlyLoaded") then
                        freezeValue(weapon.CurrentlyLoaded)
                    end
                    if weapon:FindFirstChild("Mag") then
                        weapon.Mag.Value = 100000
                    end
                end
            end
        end
    end

    vehicle.AncestryChanged:Connect(function(_, parent)
        if not parent then
            active = false
            script:Destroy()
        end
    end)
end

LocalPlayer.CharacterAdded:Connect(function()
    repeat task.wait() until LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    freezeWeapons(getClosestVehicle())
end)

if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
    freezeWeapons(getClosestVehicle())
end

SpawnedVehicles.ChildAdded:Connect(function() freezeWeapons(getClosestVehicle()) end)
SpawnedVehicles.ChildRemoved:Connect(function() freezeWeapons(getClosestVehicle()) end)

LocalPlayer.CharacterRemoving:Connect(function()
    active = false
    script:Destroy()
end)

RunService.Stepped:Connect(function()
    if not active then return end
    local closest = getClosestVehicle()
    if not closest then
        active = false
        script:Destroy()
    elseif closest ~= currentClosestVehicle then
        freezeWeapons(closest)
    end
end)
