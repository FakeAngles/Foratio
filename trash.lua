--Settings--
local ESP = {
    Enabled = false,
    Boxes = true,
    BoxShift = CFrame.new(0,-1.5,0),
	BoxSize = Vector3.new(4,6,0),
    Color = Color3.fromRGB(255, 170, 0),
    FaceCamera = false,
    Names = true,
    TeamColor = true,
    Thickness = 2,
    AttachShift = 1,
    TeamMates = true,
    Players = true,
    
    Objects = setmetatable({}, {__mode="kv"}),
    Overrides = {}
}

--Declarations--
local cam = workspace.CurrentCamera
local plrs = game:GetService("Players")
local plr = plrs.LocalPlayer
local mouse = plr:GetMouse()

local V3new = Vector3.new
local WorldToViewportPoint = cam.WorldToViewportPoint

--Functions--
local function Draw(obj, props)
	local new = Drawing.new(obj)
	
	props = props or {}
	for i,v in pairs(props) do
		new[i] = v
	end
	return new
end

function ESP:GetTeam(p)
	local ov = self.Overrides.GetTeam
	if ov then
		return ov(p)
	end
	
	return p and p.Team
end

function ESP:IsTeamMate(p)
    local ov = self.Overrides.IsTeamMate
	if ov then
		return ov(p)
    end
    
    return self:GetTeam(p) == self:GetTeam(plr)
end

function ESP:GetColor(obj)
	local ov = self.Overrides.GetColor
	if ov then
		return ov(obj)
    end
    local p = self:GetPlrFromChar(obj)
	return p and self.TeamColor and p.Team and p.Team.TeamColor.Color or self.Color
end

function ESP:GetPlrFromChar(char)
	local ov = self.Overrides.GetPlrFromChar
	if ov then
		return ov(char)
	end
	
	return plrs:GetPlayerFromCharacter(char)
end

function ESP:Toggle(bool)
    self.Enabled = bool
    if not bool then
        for i,v in pairs(self.Objects) do
            if v.Type == "Box" then --fov circle etc
                if v.Temporary then
                    v:Remove()
                else
                    for i,v in pairs(v.Components) do
                        v.Visible = false
                    end
                end
            end
        end
    end
end

function ESP:GetBox(obj)
    return self.Objects[obj]
end

function ESP:AddObjectListener(parent, options)
    if not parent then
        warn("Parent is nil. Ensure the folder or object exists before adding a listener.")
        return
    end

    local function NewListener(c)
		if type(options.Type) == "string" and c:IsA(options.Type) or options.Type == nil then
			if type(options.Name) == "string" and c.Name == options.Name or options.Name == nil then
				if not options.Validator or options.Validator(c) then
					if c.Parent and workspace:IsAncestorOf(c) then
						local box = ESP:Add(c, {
							PrimaryPart = type(options.PrimaryPart) == "string" and c:WaitForChild(options.PrimaryPart) or type(options.PrimaryPart) == "function" and options.PrimaryPart(c),
							Color = type(options.Color) == "function" and options.Color(c) or options.Color,
							ColorDynamic = options.ColorDynamic,
							Name = type(options.CustomName) == "function" and options.CustomName(c) or options.CustomName,
							IsEnabled = options.IsEnabled,
							RenderInNil = options.RenderInNil
						})
						if options.OnAdded then
							coroutine.wrap(options.OnAdded)(box)
						end
					else
						warn(c.Name .. " has no parent, skipping ESP addition.")
					end
				end
			end
		end
	end
	
    if options.Recursive then
		parent.DescendantAdded:Connect(NewListener)
		for i, v in pairs(parent:GetDescendants()) do
			NewListener(v)  -- убрали coroutine.wrap()
		end
	else
		parent.ChildAdded:Connect(NewListener)
		for i, v in pairs(parent:GetChildren()) do
			NewListener(v)  -- убрали coroutine.wrap()
		end
	end
end
local boxBase = {}
boxBase.__index = boxBase

function boxBase:Remove()
    ESP.Objects[self.Object] = nil
    for i, v in pairs(self.Components) do
        if v then
            v.Visible = false
            v:Remove()
            self.Components[i] = nil
        end
    end
end

function boxBase:Update()
    if not self.PrimaryPart then
        return self:Remove()
    end

    local allow = true

    if ESP.Overrides.UpdateAllow and not ESP.Overrides.UpdateAllow(self) then
        allow = false
    end
    if self.Player and not ESP.TeamMates and ESP:IsTeamMate(self.Player) then
        allow = false
    end
    if self.Player and not ESP.Players then
        allow = false
    end
    if self.IsEnabled and (type(self.IsEnabled) == "string" and not ESP[self.IsEnabled] or type(self.IsEnabled) == "function" and not self:IsEnabled()) then
        allow = false
    end
    if not workspace:IsAncestorOf(self.PrimaryPart) and not self.RenderInNil then
        allow = false
    end

    -- Если не разрешено отображать бокс, скрываем все компоненты
    if not allow then
        for i, v in pairs(self.Components) do
            if v then
                v.Visible = false
            end
        end
        return
    end

    -- Проверяем видимость центральной части с помощью WorldToViewportPoint
    local screenPos, isOnScreen = WorldToViewportPoint(cam, self.PrimaryPart.Position)

    -- Если объект не виден, скрываем все компоненты
    if not isOnScreen then
        for i, v in pairs(self.Components) do
            if v then
                v.Visible = false
            end
        end
        return
    end

    -- Определение, лежит ли игрок
    local upVector = self.PrimaryPart.CFrame.UpVector
    local isLyingDown = math.abs(upVector.Y) < 0.5  -- Если Y компонент UpVector небольшой, то объект лежит (ориентирован горизонтально)

    local size = self.Size
    if isLyingDown then
        size = Vector3.new(size.X * 1.5, size.Y * 0.5, size.Z)  -- Увеличиваем ширину и уменьшаем высоту для лежащего персонажа
    end

    -- Обновление позиции и видимости боксов
    local cf = self.PrimaryPart.CFrame

    -- Определяем позиции углов бокса
    local locs = {
        TopLeft = cf * ESP.BoxShift * CFrame.new(size.X / 2, size.Y / 2, 0),
        TopRight = cf * ESP.BoxShift * CFrame.new(-size.X / 2, size.Y / 2, 0),
        BottomLeft = cf * ESP.BoxShift * CFrame.new(size.X / 2, -size.Y / 2, 0),
        BottomRight = cf * ESP.BoxShift * CFrame.new(-size.X / 2, -size.Y / 2, 0)
    }

    -- Проверяем видимость каждого из углов и скрываем, если объект не виден
    local TopLeft, Vis1 = WorldToViewportPoint(cam, locs.TopLeft.p)
    local TopRight, Vis2 = WorldToViewportPoint(cam, locs.TopRight.p)
    local BottomLeft, Vis3 = WorldToViewportPoint(cam, locs.BottomLeft.p)
    local BottomRight, Vis4 = WorldToViewportPoint(cam, locs.BottomRight.p)

    -- Если хотя бы один угол виден, показываем бокс
    if Vis1 or Vis2 or Vis3 or Vis4 then
        if self.Components.Quad then
            self.Components.Quad.Visible = true
            -- Обновление точек для отображения бокса
            self.Components.Quad.PointA = Vector2.new(TopRight.X, TopRight.Y)
            self.Components.Quad.PointB = Vector2.new(TopLeft.X, TopLeft.Y)
            self.Components.Quad.PointC = Vector2.new(BottomLeft.X, BottomLeft.Y)
            self.Components.Quad.PointD = Vector2.new(BottomRight.X, BottomRight.Y)
            self.Components.Quad.Color = self.Color or ESP.Color
        end
    else
        if self.Components.Quad then
            self.Components.Quad.Visible = false
        end
    end

    -- Обновление имен и расстояний
    if ESP.Names then
        local TagPos, Vis5 = WorldToViewportPoint(cam, cf.p + Vector3.new(0, size.Y / 2, 0))

        if Vis5 then
            if self.Components.Name then
                self.Components.Name.Visible = true
                self.Components.Name.Position = Vector2.new(TagPos.X, TagPos.Y)
                self.Components.Name.Text = self.Name
            end
            if self.Components.Distance then
                self.Components.Distance.Visible = true
                self.Components.Distance.Position = Vector2.new(TagPos.X, TagPos.Y + 14)
                self.Components.Distance.Text = math.floor((cam.CFrame.p - cf.p).Magnitude) .. "m"
            end
        else
            if self.Components.Name then
                self.Components.Name.Visible = false
            end
            if self.Components.Distance then
                self.Components.Distance.Visible = false
            end
        end
    else
        if self.Components.Name then
            self.Components.Name.Visible = false
        end
        if self.Components.Distance then
            self.Components.Distance.Visible = false
        end
    end

    -- Обновление трейсеров
    if ESP.Tracers and isOnScreen then
        local TorsoPos, Vis6 = WorldToViewportPoint(cam, cf.p)

        if Vis6 then
            if self.Components.Tracer then
                self.Components.Tracer.Visible = true
                self.Components.Tracer.From = Vector2.new(TorsoPos.X, TorsoPos.Y)
                self.Components.Tracer.To = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / ESP.AttachShift)
                self.Components.Tracer.Color = self.Color or ESP.Color
            end
        else
            if self.Components.Tracer then
                self.Components.Tracer.Visible = false
            end
        end
    else
        if self.Components.Tracer then
            self.Components.Tracer.Visible = false
        end
    end
end

function ESP:Add(obj, options)
    if not obj.Parent and not options.RenderInNil then
        warn(obj.Name .. " has no parent, skipping ESP addition.")
        return
    end

    local box = setmetatable({
        Name = options.Name or obj.Name,
        Type = "Box",
        Color = options.Color,
        Size = options.Size or self.BoxSize,
        Object = obj,
        Player = options.Player or plrs:GetPlayerFromCharacter(obj),
        PrimaryPart = options.PrimaryPart or obj.ClassName == "Model" and (obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")) or obj:IsA("BasePart") and obj,
        Components = {},
        IsEnabled = options.IsEnabled,
        Temporary = options.Temporary,
        ColorDynamic = options.ColorDynamic,
        RenderInNil = options.RenderInNil
    }, boxBase)

    if not box.PrimaryPart then
        warn("PrimaryPart not found for object:", obj.Name)
        return
    end

    if self:GetBox(obj) then
        self:GetBox(obj):Remove()
    end

    box.Components["Quad"] = Draw("Quad", {
        Thickness = self.Thickness,
        Color = box.Color,
        Transparency = 1,
        Filled = false,
        Visible = self.Enabled and self.Boxes
    })
    box.Components["Name"] = Draw("Text", {
        Text = box.Name,
        Color = box.Color,
        Center = true,
        Outline = true,
        Size = 19,
        Visible = self.Enabled and self.Names
    })
    box.Components["Distance"] = Draw("Text", {
        Color = box.Color,
        Center = true,
        Outline = true,
        Size = 19,
        Visible = self.Enabled and self.Names
    })

    box.Components["Tracer"] = Draw("Line", {
        Thickness = ESP.Thickness,
        Color = box.Color,
        Transparency = 1,
        Visible = self.Enabled and self.Tracers
    })
    self.Objects[obj] = box

    obj.AncestryChanged:Connect(function(_, parent)
        if parent == nil and ESP.AutoRemove ~= false then
            box:Remove()
        end
    end)
    obj:GetPropertyChangedSignal("Parent"):Connect(function()
        if obj.Parent == nil and ESP.AutoRemove ~= false then
            box:Remove()
        end
    end)

    local hum = obj:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Died:Connect(function()
            if ESP.AutoRemove ~= false then
                box:Remove()
            end
        end)
    end

    return box
end
  -- Добавляем end здесь

local function CharAdded(char)
    local p = plrs:GetPlayerFromCharacter(char)
    if not char:FindFirstChild("HumanoidRootPart") then
        local ev
        ev = char.ChildAdded:Connect(function(c)
            if c.Name == "HumanoidRootPart" then
                ev:Disconnect()
                print("Adding ESP for character:", char.Name)
                ESP:Add(char, {
                    Name = p.Name,
                    Player = p,
                    PrimaryPart = c
                })
            end
        end)
    else
        print("Adding ESP for character:", char.Name)
        ESP:Add(char, {
            Name = p.Name,
            Player = p,
            PrimaryPart = char.HumanoidRootPart
        })
    end
end

local function PlayerAdded(p)
    p.CharacterAdded:Connect(CharAdded)
    if p.Character then
        coroutine.wrap(CharAdded)(p.Character)
    end
end
plrs.PlayerAdded:Connect(PlayerAdded)
for i,v in pairs(plrs:GetPlayers()) do
    if v ~= plr then
        PlayerAdded(v)
    end
end

game:GetService("RunService").RenderStepped:Connect(function()
    cam = workspace.CurrentCamera
    for i, v in pairs(ESP.Objects) do
        if v.Update then
            local s, e = pcall(v.Update, v)
            if not s then
                warn("[ESP Update Error]", e)
            end
        end
    end
end)

-- Default settings 
ESP:Toggle(true)
ESP.Players = false 
ESP.Tracers = false 
ESP.Boxes = true 
ESP.Names = false

local charBodies

-- Поиск всех папок с именем "Folder" и проверка наличия нужных частей
for _, folder in pairs(workspace:GetChildren()) do
    if folder:IsA("Folder") then
        local humanoidFound = false
        for _, model in pairs(folder:GetChildren()) do
            if model:FindFirstChildOfClass("Humanoid") then
                humanoidFound = true
                break
            end
        end
        if humanoidFound then
            charBodies = folder
            break
        end
    end
end

if charBodies then 
    print("Got charBodies folder")
else
    print("Failed to get charBodies folder...")
end

-- Add ESP listener 
ESP:AddObjectListener(charBodies, {
    Name = nil, -- Оставим nil, чтобы выбрать все модели
    Type = "Model",
    Color = Color3.fromRGB(255, 0, 4),
    PrimaryPart = function(obj)
        return obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildOfClass("BasePart")
    end, 
    Validator = function(obj)
        if obj:FindFirstChild("friendlyTag") then 
            return false 
        else
            task.wait(1)
            if obj:FindFirstChild("friendlyTag") then 
                return false 
            else
                return true 
            end
        end
    end, 
    CustomName = function(obj)
        return obj.Name
    end,
    IsEnabled = "player"
}); ESP.player = true

-- Periodic check for misapplied ESPs
task.spawn(function()
    while true do task.wait(3)
        pcall(function()
            for obj, box in pairs(ESP.Objects) do
                if box.Type == "Box" and obj:IsA("Model") then
                    local torso = obj:FindFirstChild("torso")
                    if torso and torso:FindFirstChild("friendlyTag") then
                        box:Remove()
                        print("Removed ESP from friendlyTagged torso")
                    end
                end
            end
        end) 
    end
end)
