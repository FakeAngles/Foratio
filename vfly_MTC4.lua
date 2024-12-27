local Players = game:GetService("Players")
local workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local flySpeed = 350 -- Fly speed
local toggleKey = Enum.KeyCode.N -- Bind key

local flying = false 
local currentVehicle = nil
local bodyGyroTank, bodyVelocity, stabilizingPlatform = nil, nil, nil
local flyConnection, noclipConnection = nil, nil
local controlModule = require(Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")).controls -- Получаем модуль управления

local function getVehicleMainPart(vehicle)
    if vehicle.PrimaryPart then
        return vehicle.PrimaryPart
    elseif vehicle:FindFirstChild("Hull") then
        return vehicle.Hull
    elseif vehicle:FindFirstChild("Chassis") then
        return vehicle.Chassis
    else
        return vehicle:FindFirstChildWhichIsA("BasePart")
    end
end

local function isLocalPlayerInVehicle(vehicle)
    for _, seat in pairs(vehicle:GetDescendants()) do
        if seat:IsA("VehicleSeat") or seat:IsA("Seat") then
            local occupant = seat.Occupant
            if occupant and occupant.Parent == Players.LocalPlayer.Character then
                return true
            end
        end
    end
    return false
end

local function createStabilizingPlatform(mainPart)
    local platform = Instance.new("Part")
    platform.Size = Vector3.new(20, 1, 20)
    platform.Anchored = false
    platform.CanCollide = false 
    platform.Transparency = 1 
    platform.Position = mainPart.Position - Vector3.new(0, mainPart.Size.Y / 2 + 1, 0) 
    platform.Parent = workspace

    local weld = Instance.new("Weld")
    weld.Part0 = mainPart
    weld.Part1 = platform
    weld.C0 = CFrame.new(0, -(mainPart.Size.Y / 2 + 1), 0) 
    weld.Parent = platform

    return platform
end

local function enableFly(vehicle)
    if flying then return end

    local mainPart = getVehicleMainPart(vehicle)
    if not mainPart or not mainPart:IsA("BasePart") then
        return
    end

    if flying then
        disableFly()
    end

    currentVehicle = vehicle

    stabilizingPlatform = createStabilizingPlatform(mainPart)

    bodyVelocity = Instance.new("BodyVelocity", stabilizingPlatform)
    bodyVelocity.MaxForce = Vector3.new(1e7, 1e7, 1e7)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)

    bodyGyroTank = Instance.new("BodyGyro", mainPart)
    bodyGyroTank.MaxTorque = Vector3.new(1e7, 1e7, 1e7)
    bodyGyroTank.P = 5e5
    bodyGyroTank.CFrame = mainPart.CFrame

    flying = true

    noclipConnection = RunService.RenderStepped:Connect(function()
        if flying then
            local character = Players.LocalPlayer.Character
            local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
            humanoidRootPart.CanCollide = false
            humanoidRootPart.Anchored = false

            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end

            for _, part in ipairs(vehicle:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end)

    flyConnection = RunService.RenderStepped:Connect(function()
        if flying then
            local direction = controlModule:GetMoveVector()
            local camera = workspace.CurrentCamera
            local newVelocity = Vector3.new(0, 0, 0)

            if direction.X ~= 0 then
                newVelocity = newVelocity + camera.CFrame.RightVector * (direction.X * flySpeed)
            end
            if direction.Z ~= 0 then
                newVelocity = newVelocity - camera.CFrame.LookVector * (direction.Z * flySpeed)
            end

            bodyVelocity.Velocity = newVelocity
            bodyGyroTank.CFrame = CFrame.new(bodyGyroTank.CFrame.Position, bodyGyroTank.CFrame.Position + camera.CFrame.LookVector)
        end
    end)

    Players.LocalPlayer.CharacterAdded:Connect(function(character)
        character:WaitForChild("Humanoid").Died:Connect(function()
            disableFly()
        end)
    end)
end

local function disableFly()
    if not flying then return end

    flying = false

    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end

    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end

    local character = Players.LocalPlayer.Character
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    
    humanoidRootPart.CanCollide = true
    humanoidRootPart.Anchored = false

    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
        end
    end

    for _, part in ipairs(currentVehicle:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
        end
    end

    if bodyGyroTank then
        bodyGyroTank:Destroy()
        bodyGyroTank = nil
    end

    if bodyVelocity then
        bodyVelocity:Destroy()
        bodyVelocity = nil
    end

    if stabilizingPlatform then
        stabilizingPlatform:Destroy()
        stabilizingPlatform = nil
    end

    currentVehicle = nil
end

UserInputService.InputBegan:Connect(function(input, isProcessed)
    if isProcessed then return end

    if input.KeyCode == toggleKey then
        if not flying then
            for _, vehicle in pairs(workspace.SpawnedVehicles:GetChildren()) do
                if isLocalPlayerInVehicle(vehicle) then
                    enableFly(vehicle)
                    break
                end
            end
        else
            disableFly()
        end
    end
end)
