--!strict
-- Ponto de entrada do servidor
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local PlayerData = require(script.Parent.Data.PlayerData)
local Leaderstats = require(script.Parent.Core.Leaderstats)
local CheckpointSystem = require(script.Parent.Core.CheckpointSystem)
local MapInteractions = require(script.Parent.Core.MapInteractions)
local StageGenerator = require(script.Parent.Map.StageGenerator)

-- Gera o mapa antes de qualquer jogador interagir
StageGenerator.Generate()
MapInteractions.Init()
CheckpointSystem.Init()

local function OnPlayerAdded(player: Player)
	MapInteractions.OnPlayerAdded(player)

	-- Inicializa os dados (pode demorar: chama o DataStore)
	PlayerData.Init(player)

	-- O jogador pode ter saído enquanto os dados carregavam
	if not player.Parent then
		PlayerData.SaveAndRemove(player)
		return
	end

	-- Configura a UI do Leaderstats (Tab list)
	Leaderstats.Setup(player)

	-- Configura sistema de respawn e mortes
	CheckpointSystem.OnPlayerAdded(player)
end

local function OnPlayerRemoving(player: Player)
	MapInteractions.OnPlayerRemoving(player)
	CheckpointSystem.OnPlayerRemoving(player)
	-- Salva os dados antes de sair
	PlayerData.SaveAndRemove(player)
end

-- Conexões de Eventos Principais
Players.PlayerAdded:Connect(OnPlayerAdded)
Players.PlayerRemoving:Connect(OnPlayerRemoving)

-- Jogadores que entraram antes deste script rodar (comum no Studio)
for _, player in Players:GetPlayers() do
	task.spawn(OnPlayerAdded, player)
end

-- Salvamento automático
task.spawn(function()
	while true do
		task.wait(GameConfig.IntervaloAutosave)
		PlayerData.SaveAll()
	end
end)

-- BindToClose para salvar dados se o servidor desligar
game:BindToClose(function()
	print("Servidor fechando, salvando dados...")
	PlayerData.SaveAll()
end)

print("Obby dos Heróis: Servidor Iniciado com Sucesso!")
