--!strict
-- Comportamento das peças do mapa: kill bricks, moedas e plataformas que somem
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Networking.Remotes)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Leaderstats = require(script.Parent.Leaderstats)

local MoedaColetada = Remotes.GetRemoteEvent("MoedaColetada")

local MapInteractions = {}

-- Moedas coletadas na sessão atual, por jogador
local Coletadas: { [Player]: { [number]: boolean } } = {}

local function ForEachTagged(tag: string, callback: (Instance) -> ())
	for _, inst in CollectionService:GetTagged(tag) do
		task.spawn(callback, inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(callback)
end

local function GetHumanoid(hit: BasePart): Humanoid?
	local model = hit:FindFirstAncestorOfClass("Model")
	return model and model:FindFirstChildOfClass("Humanoid")
end

local function GetPlayer(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	return model and Players:GetPlayerFromCharacter(model)
end

local function SetupKillBrick(inst: Instance)
	local part = inst :: BasePart
	part.Touched:Connect(function(hit)
		local humanoid = GetHumanoid(hit)
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = 0
		end
	end)
end

local function SetupCoin(inst: Instance)
	local part = inst :: BasePart
	local coinId = part:GetAttribute("CoinId") :: number
	part.Touched:Connect(function(hit)
		local player = GetPlayer(hit)
		if not player then
			return
		end
		local coletadas = Coletadas[player]
		local data = PlayerData.GetData(player)
		if not coletadas or not data or coletadas[coinId] then
			return
		end

		coletadas[coinId] = true
		data.Moedas += GameConfig.MoedasPorMoeda
		Leaderstats.Update(player, "Moedas", data.Moedas)
		MoedaColetada:FireClient(player, coinId)
	end)
end

local function SetupFading(inst: Instance)
	local part = inst :: BasePart
	local visivel = (part:GetAttribute("TempoVisivel") :: number?) or 3
	local invisivel = (part:GetAttribute("TempoInvisivel") :: number?) or 1.5
	local atraso = (part:GetAttribute("Atraso") :: number?) or 0
	local AVISO = 0.6

	task.wait(atraso)
	while part.Parent do
		part.Transparency = 0
		part.CanCollide = true
		task.wait(math.max(visivel - AVISO, 0.1))

		-- Pisca antes de sumir
		part.Transparency = 0.5
		task.wait(AVISO)

		part.Transparency = 1
		part.CanCollide = false
		task.wait(invisivel)
	end
end

function MapInteractions.Init()
	ForEachTagged("KillBrick", SetupKillBrick)
	ForEachTagged("Coin", SetupCoin)
	ForEachTagged("Fading", SetupFading)
end

function MapInteractions.OnPlayerAdded(player: Player)
	Coletadas[player] = {}
end

function MapInteractions.OnPlayerRemoving(player: Player)
	Coletadas[player] = nil
end

return MapInteractions
