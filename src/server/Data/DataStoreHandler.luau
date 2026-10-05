--!strict
-- Lida com DataStoreService (salvamento, carregamento, retries)
local DataStoreService = game:GetService("DataStoreService")

local PlayerDataStore = DataStoreService:GetDataStore("PlayerData_v1")

local MAX_RETRIES = 3

local DataStoreHandler = {}

-- Estrutura de dados padrão do jogador
export type PlayerDataConfig = {
	Fase: number,
	Moedas: number,
	Mortes: number,
	Vitorias: number,
	MundoAtual: string,
}

function DataStoreHandler.GetDefaultData(): PlayerDataConfig
	return {
		Fase = 1,
		Moedas = 0,
		Mortes = 0,
		Vitorias = 0,
		MundoAtual = "Tecelão",
	}
end

-- Preenche campos novos que não existiam em saves antigos
local function Reconcile(data: { [string]: any }): PlayerDataConfig
	for key, value in pairs(DataStoreHandler.GetDefaultData() :: any) do
		if data[key] == nil then
			data[key] = value
		end
	end
	return data :: any
end

-- Retorna (dados, carregouComSucesso).
-- Se falhar, retorna dados padrão e `false`: esses dados NÃO devem ser salvos,
-- senão sobrescreveriam o progresso real do jogador.
function DataStoreHandler.LoadData(player: Player): (PlayerDataConfig, boolean)
	local data = nil
	local attempts = 0
	local success = false

	while not success and attempts < MAX_RETRIES do
		attempts += 1
		success, data = pcall(function()
			return PlayerDataStore:GetAsync(tostring(player.UserId))
		end)

		if not success then
			warn("Falha ao carregar dados do jogador " .. player.Name .. " (Tentativa " .. attempts .. "): " .. tostring(data))
			task.wait(2)
		end
	end

	if not success then
		return DataStoreHandler.GetDefaultData(), false
	end

	if type(data) == "table" then
		return Reconcile(data), true
	end

	return DataStoreHandler.GetDefaultData(), true
end

function DataStoreHandler.SaveData(userId: number, data: PlayerDataConfig): boolean
	local attempts = 0
	local success = false

	while not success and attempts < MAX_RETRIES do
		attempts += 1
		local err
		success, err = pcall(function()
			PlayerDataStore:SetAsync(tostring(userId), data)
		end)

		if not success then
			warn("Falha ao salvar dados do UserId " .. userId .. " (Tentativa " .. attempts .. "): " .. tostring(err))
			task.wait(2)
		end
	end

	return success
end

return DataStoreHandler
