--!strict
-- Gera as fases do mundo de forma procedural (seed fixa = mapa igual em todo servidor)
--
-- Convenção: o "cursor" é um ponto na SUPERFÍCIE de cima, na borda de trás
-- de onde o próximo elemento começa. O mapa avança no eixo +Z.
--
-- Tags usadas (CollectionService):
--   KillBrick  -> mata ao tocar
--   Coin       -> moeda (atributo CoinId)
--   Checkpoint -> início de fase (atributo Fase)
--   Finish     -> linha de chegada do mundo
--   Fading     -> plataforma que some e volta
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local StageGenerator = {}

local Checkpoints: { [number]: BasePart } = {}
local proximoCoinId = 0

local CORES = {
	Plataforma = Color3.fromRGB(110, 120, 220),
	Trave = Color3.fromRGB(230, 170, 80),
	Lava = Color3.fromRGB(255, 60, 40),
	Sumir = Color3.fromRGB(80, 220, 230),
	Checkpoint = Color3.fromRGB(70, 210, 110),
	Chegada = Color3.fromRGB(255, 205, 50),
	Moeda = Color3.fromRGB(255, 215, 0),
	Pilar = Color3.fromRGB(60, 60, 70),
}

type Segmento = (folder: Folder, cursor: Vector3, rng: Random, d: number) -> Vector3

local function MakePart(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, className: string?): BasePart
	local part = Instance.new(className or "Part") :: BasePart
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- CFrame de uma peça cuja borda de trás/topo fica no cursor
local function PlaceFrom(cursor: Vector3, size: Vector3): CFrame
	return CFrame.new(cursor + Vector3.new(0, -size.Y / 2, size.Z / 2))
end

local function AddCoin(parent: Instance, position: Vector3)
	proximoCoinId += 1
	local coin = MakePart(
		parent,
		Vector3.new(0.4, 2.4, 2.4),
		CFrame.new(position) * CFrame.Angles(0, math.rad(90), 0),
		CORES.Moeda,
		Enum.Material.Neon,
		"Part"
	);
	(coin :: Part).Shape = Enum.PartType.Cylinder
	coin.CanCollide = false
	coin.Name = "Moeda"
	coin:SetAttribute("CoinId", proximoCoinId)
	CollectionService:AddTag(coin, "Coin")
end

local function AddLabel(part: BasePart, text: string)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextTransparency = 0.2
	label.Parent = gui
	gui.Parent = part
end

---------------------------------------------------------------------
-- Segmentos de obstáculo
---------------------------------------------------------------------

-- Plataformas com pulos (fica menor e mais distante com a dificuldade)
local function Saltos(folder: Folder, cursor: Vector3, rng: Random, d: number): Vector3
	local tamanho = 6 - 2.5 * d
	for _ = 1, rng:NextInteger(3, 5) do
		local gap = 3 + 3 * d + rng:NextNumber() * 0.8
		local dy = rng:NextInteger(-1, 2)
		if dy > 0 then
			gap = math.min(gap, 5)
		end
		cursor += Vector3.new(rng:NextNumber(-2, 2), dy, gap)

		local size = Vector3.new(tamanho, 1, tamanho)
		MakePart(folder, size, PlaceFrom(cursor, size), CORES.Plataforma)
		if rng:NextNumber() < 0.4 then
			AddCoin(folder, cursor + Vector3.new(0, 3, tamanho / 2))
		end
		cursor += Vector3.new(0, 0, tamanho)
	end
	return cursor
end

-- Corredor com faixas de lava para pular
local function Lava(folder: Folder, cursor: Vector3, rng: Random, d: number): Vector3
	cursor += Vector3.new(0, 0, 3)
	local comprimento = rng:NextInteger(20, 28)
	local chao = Vector3.new(8, 1, comprimento)
	MakePart(folder, chao, PlaceFrom(cursor, chao), CORES.Plataforma)

	local z = 4
	while z < comprimento - 5 do
		local profundidade = 1.5 + 2 * d
		local faixa = Vector3.new(8, 0.4, profundidade)
		local lava = MakePart(folder, faixa, PlaceFrom(cursor + Vector3.new(0, 0.2, z), faixa), CORES.Lava, Enum.Material.Neon)
		lava.Name = "Lava"
		CollectionService:AddTag(lava, "KillBrick")
		z += profundidade + rng:NextNumber(4, 6)
	end

	AddCoin(folder, cursor + Vector3.new(0, 4, comprimento / 2))
	return cursor + Vector3.new(0, 0, comprimento)
end

-- Traves estreitas com um descanso no meio
local function Trave(folder: Folder, cursor: Vector3, rng: Random, d: number): Vector3
	local largura = math.max(2 - 1.2 * d, 0.8)
	cursor += Vector3.new(0, 0, 3)

	for i = 1, 2 do
		local trave = Vector3.new(largura, 1, rng:NextInteger(12, 18))
		MakePart(folder, trave, PlaceFrom(cursor, trave), CORES.Trave, Enum.Material.Wood)
		cursor += Vector3.new(0, 0, trave.Z)

		if i == 1 then
			local descanso = Vector3.new(5, 1, 5)
			MakePart(folder, descanso, PlaceFrom(cursor, descanso), CORES.Plataforma)
			AddCoin(folder, cursor + Vector3.new(0, 3, 2.5))
			cursor += Vector3.new(rng:NextNumber(-1.5, 1.5), 0, 5)
		end
	end
	return cursor
end

-- Plataformas que somem e reaparecem
local function Sumir(folder: Folder, cursor: Vector3, rng: Random, d: number): Vector3
	for i = 1, rng:NextInteger(3, 4) do
		cursor += Vector3.new(0, 0, 3 + 1.5 * d)
		local size = Vector3.new(5, 1, 5)
		local plat = MakePart(folder, size, PlaceFrom(cursor, size), CORES.Sumir, Enum.Material.Glass)
		plat.Name = "PlataformaSumir"
		plat:SetAttribute("TempoVisivel", 3 - 1.5 * d)
		plat:SetAttribute("TempoInvisivel", 1.5)
		plat:SetAttribute("Atraso", (i - 1) * 0.6)
		CollectionService:AddTag(plat, "Fading")
		cursor += Vector3.new(0, 0, 5)
	end
	return cursor
end

-- Plataforma redonda com uma barra giratória mortal
local function Giratoria(folder: Folder, cursor: Vector3, _rng: Random, d: number): Vector3
	cursor += Vector3.new(0, 0, 3)
	local chao = Vector3.new(18, 1, 18)
	MakePart(folder, chao, PlaceFrom(cursor, chao), CORES.Plataforma)
	local centro = cursor + Vector3.new(0, 0, 9)

	local pilar = MakePart(folder, Vector3.new(2, 4, 2), CFrame.new(centro + Vector3.new(0, 2, 0)), CORES.Pilar, Enum.Material.Metal)
	local barra = MakePart(folder, Vector3.new(16, 1, 1), CFrame.new(centro + Vector3.new(0, 1.5, 0)), CORES.Lava, Enum.Material.Neon)
	barra.Name = "BarraGiratoria"
	barra.Anchored = false
	barra.CanCollide = false
	CollectionService:AddTag(barra, "KillBrick")

	-- Rotacionar 90° no Z faz o eixo X da attachment (eixo da dobradiça) apontar para cima
	local att0 = Instance.new("Attachment")
	att0.CFrame = CFrame.new(0, -0.5, 0) * CFrame.Angles(0, 0, math.rad(90))
	att0.Parent = pilar
	local att1 = Instance.new("Attachment")
	att1.CFrame = CFrame.Angles(0, 0, math.rad(90))
	att1.Parent = barra

	local hinge = Instance.new("HingeConstraint")
	hinge.Attachment0 = att0
	hinge.Attachment1 = att1
	hinge.ActuatorType = Enum.ActuatorType.Motor
	hinge.AngularVelocity = 1.2 + 1.8 * d
	hinge.MotorMaxTorque = math.huge
	hinge.MotorMaxAcceleration = math.huge
	hinge.Parent = barra

	-- Servidor controla a física da barra para todos verem igual
	barra:SetNetworkOwner(nil)

	return cursor + Vector3.new(0, 0, chao.Z)
end

-- Segmentos liberados conforme a fase
local SEGMENTOS: { { fn: Segmento, aPartirDe: number } } = {
	{ fn = Saltos, aPartirDe = 1 },
	{ fn = Lava, aPartirDe = 1 },
	{ fn = Trave, aPartirDe = 4 },
	{ fn = Sumir, aPartirDe = 8 },
	{ fn = Giratoria, aPartirDe = 12 },
}

---------------------------------------------------------------------

local function CreateCheckpoint(folder: Folder, cursor: Vector3, fase: number): Vector3
	local size = Vector3.new(12, 1, 12)
	local pad = MakePart(
		folder,
		size,
		PlaceFrom(cursor, size),
		CORES.Checkpoint,
		Enum.Material.Neon,
		if fase == 1 then "SpawnLocation" else "Part"
	)
	if pad:IsA("SpawnLocation") then
		pad.Duration = 0
		pad.Neutral = true
	end
	pad.Name = "Checkpoint"
	pad:SetAttribute("Fase", fase)
	CollectionService:AddTag(pad, "Checkpoint")
	AddLabel(pad, tostring(fase))
	Checkpoints[fase] = pad
	return cursor + Vector3.new(0, 0, size.Z)
end

local function CreateFinish(folder: Instance, cursor: Vector3)
	local size = Vector3.new(16, 1, 16)
	local pad = MakePart(folder, size, PlaceFrom(cursor, size), CORES.Chegada, Enum.Material.Neon)
	pad.Name = "Chegada"
	CollectionService:AddTag(pad, "Finish")
	AddLabel(pad, "FIM!")
end

function StageGenerator.Generate(): Folder
	local antigo = workspace:FindFirstChild("Mapa")
	if antigo then
		antigo:Destroy()
	end
	table.clear(Checkpoints)
	proximoCoinId = 0

	-- O mapa precisa estar no workspace antes de construir (SetNetworkOwner exige)
	local mapa = Instance.new("Folder")
	mapa.Name = "Mapa"
	mapa.Parent = workspace

	local total = GameConfig.TotalFases
	local cursor = GameConfig.OrigemMapa

	for fase = 1, total do
		local rng = Random.new(GameConfig.Seed + fase)
		local d = (fase - 1) / math.max(total - 1, 1)

		local folder = Instance.new("Folder")
		folder.Name = string.format("Fase_%02d", fase)
		folder.Parent = mapa

		cursor = CreateCheckpoint(folder, cursor, fase)

		local disponiveis = {}
		for _, seg in SEGMENTOS do
			if fase >= seg.aPartirDe then
				table.insert(disponiveis, seg.fn)
			end
		end

		for _ = 1, math.min(2 + fase // 6, 5) do
			local seg = disponiveis[rng:NextInteger(1, #disponiveis)]
			cursor = seg(folder, cursor, rng, d)
		end

		cursor += Vector3.new(0, 0, 4)
	end

	CreateFinish(mapa, cursor)
	print(string.format("Mapa gerado: %d fases, %d moedas", total, proximoCoinId))
	return mapa
end

function StageGenerator.GetSpawnCFrame(fase: number): CFrame?
	local total = GameConfig.TotalFases
	local pad = Checkpoints[math.clamp(fase, 1, total)]
	if not pad then
		return nil
	end
	local pos = pad.Position + Vector3.new(0, 4, 0)
	return CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1))
end

return StageGenerator
