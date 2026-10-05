--!strict
-- Configurações gerais do jogo (compartilhadas entre servidor e cliente)

local GameConfig = {
	MundoNome = "Tecelão",
	TotalFases = 30,
	Seed = 1337, -- Mesma seed = mesmo mapa em todos os servidores

	-- Recompensas
	MoedasPorMoeda = 1,
	MoedasPorFase = 5,
	MoedasPorVitoria = 50,

	-- Salvamento automático (segundos)
	IntervaloAutosave = 120,

	-- Ponto onde o mapa começa a ser gerado
	OrigemMapa = Vector3.new(0, 50, 0),
}

return GameConfig
