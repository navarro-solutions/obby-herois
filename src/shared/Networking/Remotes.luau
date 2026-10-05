--!strict
-- Gerenciador de eventos remotos
-- O servidor cria os remotes; o cliente apenas espera que eles existam.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "RemoteEvents"

local Remotes = {}

local function GetFolder(): Folder
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME) :: Folder?
		if not folder then
			local newFolder = Instance.new("Folder")
			newFolder.Name = FOLDER_NAME
			newFolder.Parent = ReplicatedStorage
			return newFolder
		end
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

function Remotes.GetRemoteEvent(name: string): RemoteEvent
	local folder = GetFolder()

	if RunService:IsServer() then
		local remote = folder:FindFirstChild(name) :: RemoteEvent?
		if not remote then
			local newRemote = Instance.new("RemoteEvent")
			newRemote.Name = name
			newRemote.Parent = folder
			return newRemote
		end
		return remote
	end

	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
