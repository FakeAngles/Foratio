local playerName = game.Players.LocalPlayer.Name

local standingSlip1 = workspace:FindFirstChild("SpawnedPlayers") and workspace.SpawnedPlayers:FindFirstChild(playerName) and workspace.SpawnedPlayers[playerName]:FindFirstChild("StandingSlip")
if standingSlip1 then standingSlip1:Destroy() end

local standingSlip2 = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacterScripts") and game:GetService("StarterPlayer").StarterCharacterScripts:FindFirstChild("StandingSlip")
if standingSlip2 then standingSlip2:Destroy() end
