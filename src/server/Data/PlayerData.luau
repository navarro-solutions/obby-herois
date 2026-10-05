--!strict
-- Gerencia o cache local dos dados no servidor
local DataStoreHandler = require(script.Parent.DataStoreHandler)

local PlayerData = {}
local SessionData: { [number]: DataStoreHandler.PlayerDataConfig } = {}
-- Jogadores cujo carregamento falhou: não salvamos para não apagar o progresso real
local NaoSalvar: { [number]: boolean } = {}

function PlayerData.Init(player: Player)
	local data, loaded = DataStoreHandler.LoadData(player)
	if not loaded then
		NaoSalvar[player.UserId] = true
		warn("Dados de " .. player.Name .. " não carregaram; progresso desta sessão não será salvo.")
	end
	SessionData[player.UserId] = data
	return data
end

function PlayerData.GetData(player: Player): DataStoreHandler.PlayerDataConfig?
	return SessionData[player.UserId]
end

function PlayerData.SetData(player: Player, key: string, value: any)
	if SessionData[player.UserId] then
		(SessionData[player.UserId] :: any)[key] = value
	end
end

local function Save(userId: number)
	local data = SessionData[userId]
	if data and not NaoSalvar[userId] then
		DataStoreHandler.SaveData(userId, data)
	end
end

function PlayerData.SaveAndRemove(player: Player)
	Save(player.UserId)
	SessionData[player.UserId] = nil
	NaoSalvar[player.UserId] = nil
end

-- Salva dados de todos os jogadores em paralelo (útil para BindToClose e autosave)
function PlayerData.SaveAll()
	local pendentes = 0
	for userId in pairs(SessionData) do
		pendentes += 1
		task.spawn(function()
			Save(userId)
			pendentes -= 1
		end)
	end
	while pendentes > 0 do
		task.wait()
	end
end

return PlayerData
