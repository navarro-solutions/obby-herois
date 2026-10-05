--!strict
-- Ponto de entrada do cliente: HUD, notificações e moedas
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Networking"):WaitForChild("Remotes"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

---------------------------------------------------------------------
-- HUD
---------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local status = Instance.new("TextLabel")
status.AnchorPoint = Vector2.new(0.5, 0)
status.Position = UDim2.new(0.5, 0, 0, 12)
status.Size = UDim2.fromOffset(320, 44)
status.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
status.BackgroundTransparency = 0.25
status.TextColor3 = Color3.new(1, 1, 1)
status.Font = Enum.Font.FredokaOne
status.TextSize = 24
status.Parent = gui
Instance.new("UICorner").Parent = status

local toast = Instance.new("TextLabel")
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 64)
toast.Size = UDim2.fromOffset(480, 40)
toast.BackgroundTransparency = 1
toast.TextColor3 = Color3.fromRGB(255, 220, 80)
toast.Font = Enum.Font.FredokaOne
toast.TextSize = 28
toast.TextTransparency = 1
toast.TextStrokeTransparency = 1
toast.Parent = gui

local leaderstats = player:WaitForChild("leaderstats")
local fase = leaderstats:WaitForChild("Fase") :: IntValue
local moedas = leaderstats:WaitForChild("Moedas") :: IntValue

local function AtualizarStatus()
	status.Text = string.format("Fase %d/%d   🪙 %d", fase.Value, GameConfig.TotalFases, moedas.Value)
end
fase.Changed:Connect(AtualizarStatus)
moedas.Changed:Connect(AtualizarStatus)
AtualizarStatus()

local toastId = 0
local function MostrarNotificacao(texto: string)
	toastId += 1
	local meuId = toastId
	toast.Text = texto
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.4
	task.delay(2.5, function()
		if toastId ~= meuId then
			return
		end
		TweenService:Create(toast, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

Remotes.GetRemoteEvent("Notificar").OnClientEvent:Connect(MostrarNotificacao)

---------------------------------------------------------------------
-- Moedas (giram localmente e somem só para quem coletou)
---------------------------------------------------------------------
local coletadas: { [number]: boolean } = {}
local moedasVisiveis: { [BasePart]: CFrame } = {}

local function RegistrarMoeda(inst: Instance)
	local part = inst :: BasePart
	if coletadas[part:GetAttribute("CoinId") :: number] then
		part.Transparency = 1
	else
		moedasVisiveis[part] = part.CFrame
	end
end

for _, inst in CollectionService:GetTagged("Coin") do
	RegistrarMoeda(inst)
end
CollectionService:GetInstanceAddedSignal("Coin"):Connect(RegistrarMoeda)
-- Com StreamingEnabled, moedas entram e saem do cliente
CollectionService:GetInstanceRemovedSignal("Coin"):Connect(function(inst)
	moedasVisiveis[inst :: BasePart] = nil
end)

Remotes.GetRemoteEvent("MoedaColetada").OnClientEvent:Connect(function(coinId: number)
	coletadas[coinId] = true
	for part in moedasVisiveis do
		if part:GetAttribute("CoinId") == coinId then
			part.Transparency = 1
			moedasVisiveis[part] = nil
		end
	end
end)

RunService.RenderStepped:Connect(function()
	local giro = CFrame.Angles(0, os.clock() * 2, 0)
	for part, base in moedasVisiveis do
		part.CFrame = CFrame.new(base.Position) * giro * base.Rotation
	end
end)
