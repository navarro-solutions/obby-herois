--!strict
-- Lida com spawn, mortes, checkpoints e a linha de chegada
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Networking.Remotes)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Leaderstats = require(script.Parent.Leaderstats)
local StageGenerator = require(script.Parent.Parent.Map.StageGenerator)

local Notificar = Remotes.GetRemoteEvent("Notificar")

local CheckpointSystem = {}

-- Evita que ficar parado na chegada conte várias vitórias (reseta ao respawnar)
local ChegouNestaVida: { [Player]: boolean } = {}

local function GetPlayer(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	return model and Players:GetPlayerFromCharacter(model)
end

function CheckpointSystem.TeleportToCurrentPhase(player: Player)
	local data = PlayerData.GetData(player)
	local character = player.Character
	if not data or not character then
		return
	end

	local destino = StageGenerator.GetSpawnCFrame(data.Fase)
	if not destino then
		return
	end

	-- Com StreamingEnabled, garante que o chão já exista no cliente antes do teleporte
	pcall(function()
		player:RequestStreamAroundAsync(destino.Position)
	end)
	character:PivotTo(destino)
end

local function OnCharacterAdded(player: Player, character: Model)
	ChegouNestaVida[player] = nil

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		local data = PlayerData.GetData(player)
		if data then
			data.Mortes += 1
			Leaderstats.Update(player, "Mortes", data.Mortes)
		end
	end)

	character:WaitForChild("HumanoidRootPart")
	task.wait(0.1)
	CheckpointSystem.TeleportToCurrentPhase(player)
end

function CheckpointSystem.OnPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		OnCharacterAdded(player, character)
	end)
	-- O personagem pode ter nascido enquanto os dados carregavam
	if player.Character then
		task.spawn(OnCharacterAdded, player, player.Character)
	end
end

function CheckpointSystem.OnPlayerRemoving(player: Player)
	ChegouNestaVida[player] = nil
end

function CheckpointSystem.ReachCheckpoint(player: Player, novaFase: number)
	local data = PlayerData.GetData(player)
	-- Só avança uma fase por vez (impede pular fases)
	if not data or novaFase ~= data.Fase + 1 then
		return
	end

	data.Fase = novaFase
	data.Moedas += GameConfig.MoedasPorFase
	Leaderstats.Update(player, "Fase", data.Fase)
	Leaderstats.Update(player, "Moedas", data.Moedas)
	Notificar:FireClient(player, string.format("Fase %d! +%d moedas", novaFase, GameConfig.MoedasPorFase))
end

function CheckpointSystem.ReachFinish(player: Player)
	local data = PlayerData.GetData(player)
	if not data or data.Fase < GameConfig.TotalFases or ChegouNestaVida[player] then
		return
	end

	ChegouNestaVida[player] = true
	data.Vitorias += 1
	data.Moedas += GameConfig.MoedasPorVitoria
	Leaderstats.Update(player, "Moedas", data.Moedas)
	Notificar:FireClient(
		player,
		string.format("Você completou o mundo %s! +%d moedas", GameConfig.MundoNome, GameConfig.MoedasPorVitoria)
	)
end

function CheckpointSystem.Init()
	for _, inst in CollectionService:GetTagged("Checkpoint") do
		local pad = inst :: BasePart
		local fase = pad:GetAttribute("Fase") :: number
		pad.Touched:Connect(function(hit)
			local player = GetPlayer(hit)
			if player then
				CheckpointSystem.ReachCheckpoint(player, fase)
			end
		end)
	end

	for _, inst in CollectionService:GetTagged("Finish") do
		(inst :: BasePart).Touched:Connect(function(hit)
			local player = GetPlayer(hit)
			if player then
				CheckpointSystem.ReachFinish(player)
			end
		end)
	end
end

return CheckpointSystem
