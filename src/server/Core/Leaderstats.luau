--!strict
-- Gerencia a interface de status no leaderboard do Roblox
local PlayerData = require(script.Parent.Parent.Data.PlayerData)

local Leaderstats = {}

function Leaderstats.Setup(player: Player)
	local data = PlayerData.GetData(player)
	if not data then return end

	local leaderstatsFolder = Instance.new("Folder")
	leaderstatsFolder.Name = "leaderstats"
	leaderstatsFolder.Parent = player

	local faseValue = Instance.new("IntValue")
	faseValue.Name = "Fase"
	faseValue.Value = data.Fase
	faseValue.Parent = leaderstatsFolder

	local moedasValue = Instance.new("IntValue")
	moedasValue.Name = "Moedas"
	moedasValue.Value = data.Moedas
	moedasValue.Parent = leaderstatsFolder

	local mortesValue = Instance.new("IntValue")
	mortesValue.Name = "Mortes"
	mortesValue.Value = data.Mortes
	mortesValue.Parent = leaderstatsFolder
end

function Leaderstats.Update(player: Player, stat: string, value: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local statValue = leaderstats:FindFirstChild(stat) :: IntValue
		if statValue then
			statValue.Value = value
		end
	end
end

return Leaderstats
