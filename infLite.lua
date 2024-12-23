local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local SpawnedVehicles = workspace:WaitForChild("SpawnedVehicles")
local RunService = game:GetService("RunService")

local active = true
local currentClosestVehicle = nil

local function getDistance(pointA, pointB)
    return (pointA - pointB).Magnitude
end

local function getClosestVehicle()
    local closestVehicle = nil
    local shortestDistance = math.huge
    local playerPosition = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position

    if playerPosition then
        for _, vehicle in pairs(SpawnedVehicles:GetChildren()) do
            if vehicle:FindFirstChild("HumanoidRootPart") or vehicle.PrimaryPart then
                local vehiclePosition = (vehicle:FindFirstChild("HumanoidRootPart") or vehicle.PrimaryPart).Position
                local distance = getDistance(playerPosition, vehiclePosition)
                if distance < shortestDistance then
                    closestVehicle = vehicle
                    shortestDistance = distance
                end
            end
        end
    end
    
    return closestVehicle
end

local function freezeValue(property)
    local originalValue = property.Value
    property.Changed:Connect(function()
        if active and property.Value ~= originalValue then
            property.Value = originalValue
        end
    end)
    property.Value = originalValue
end

local function freezeWeaponsForClosestVehicle()
    if not active then return end
    local closestVehicle = getClosestVehicle()

    if closestVehicle ~= currentClosestVehicle then
        currentClosestVehicle = closestVehicle
    else
        return
    end

    if currentClosestVehicle and currentClosestVehicle:FindFirstChild("Turrets") then
        for _, turret in pairs(currentClosestVehicle.Turrets:GetChildren()) do
            if turret:FindFirstChild("Weapons") then
                for _, weapon in pairs(turret.Weapons:GetChildren()) do
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

    if currentClosestVehicle then
        currentClosestVehicle.AncestryChanged:Connect(function(_, parent)
            if not parent then
                active = false
                script:Destroy() 
            end
        end)
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    repeat wait() until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    freezeWeaponsForClosestVehicle()
end)

if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
    freezeWeaponsForClosestVehicle()
end

workspace.SpawnedVehicles.ChildAdded:Connect(freezeWeaponsForClosestVehicle)
workspace.SpawnedVehicles.ChildRemoved:Connect(freezeWeaponsForClosestVehicle)

LocalPlayer.CharacterRemoving:Connect(function()
    active = false
    script:Destroy()
end)

RunService.Stepped:Connect(function()
    if not active then return end
    local closestVehicle = getClosestVehicle()
    if not closestVehicle then
        active = false
        script:Destroy()
    elseif closestVehicle ~= currentClosestVehicle then
        freezeWeaponsForClosestVehicle()
    end
end)
