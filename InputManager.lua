local ServerInputManager = {}

local Settings = require(game.ServerStorage.Settings.RunSettings)

local ServerTypes = require(game.ServerStorage.ServerTypes)

local serverLogger = require(game.ServerStorage.ServerLogger)

local globalTypes = require(game.ReplicatedStorage.globalTypes)

local playerStatus: {[number]: ServerTypes.playerData} = {} -- data structure to keep track of player's running status

local InputActions = {
	RunStart = "RunStart",
	RunEnd = "RunEnd",
	ZoomIn = "ZoomIn",
	ZoomOut = "ZoomOut",
	ThrowProjectile = "ThrowProjectile",
}


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UpdateCamera = ReplicatedStorage.Networking.UpdateCamera :: RemoteEvent
local isInscan = ReplicatedStorage.Networking.IsInScan :: RemoteFunction
local inputRemote = ReplicatedStorage.Networking.Input :: RemoteEvent
local launchProjectile = ReplicatedStorage.Networking.LaunchProjectile :: BindableEvent

ServerInputManager.OnPlayerJoined = function(player : Player) : nil
	playerStatus[player.UserId] = {
		running = false,
		keyDown = false,
		cutscene = false,
		isInScan = false,
	}
end

ServerInputManager.OnPlayerRemoving = function(player : Player) : nil
	playerStatus[player.UserId] = nil
end


ServerInputManager.OnRunInput = function(player : Player, key : string) : nil
	if not key then serverLogger.Warn("Input key is missing, input was requested.", "InputManager") return end
	if not playerStatus[player.UserId] then serverLogger.Error("Missing player data.", "InputManager/PlayerStatus") return end

	local oxygenValue : number = player:FindFirstChild("StatsFolder"):FindFirstChild("OxygenLvl").Value

	local humanoid : Humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	
	if key == InputActions.RunStart then
		if humanoid.Health <= 0 or oxygenValue < 20 then return end
		playerStatus[player.UserId].keyDown = true
		playerStatus[player.UserId].running = true
		humanoid.WalkSpeed = Settings.runSpeed

		UpdateCamera:FireClient(player, {FieldOfView = Settings.runFOV}, {
			Time = 0.5,
			EasingStyle = Enum.EasingStyle.Linear,
			EasingDirection = Enum.EasingDirection.InOut,
			RepeatCount = 0,
			Reverses = false,
			DelayTime = 0
		} :: globalTypes.tweenInfo)
		
		local oxygen = player:FindFirstChild("StatsFolder"):FindFirstChild("OxygenLvl") :: NumberValue
		
		local function drainOxygen()
			while playerStatus[player.UserId] and playerStatus[player.UserId].running and playerStatus[player.UserId].keyDown do
				if oxygen.Value <= 0 then
					warn("Player ran out of oxygen")
					break
				end
				oxygen.Value -= 1
				task.wait(2)
			end
		end
		task.spawn(drainOxygen)

	elseif key == InputActions.RunEnd then
		playerStatus[player.UserId].keyDown = false
		playerStatus[player.UserId].running = false
		humanoid.WalkSpeed = Settings.normalSpeed
		UpdateCamera:FireClient(player, {FieldOfView = Settings.normalFOV}, {
			Time = 0.5,
			EasingStyle = Enum.EasingStyle.Linear,
			EasingDirection = Enum.EasingDirection.InOut,
			RepeatCount = 0,
			Reverses = false,
			DelayTime = 0
		} :: globalTypes.tweenInfo)
		
	elseif key == InputActions.ZoomIn then
		if playerStatus[player.UserId].running == true then return end
		playerStatus[player.UserId].isInScan = true
		UpdateCamera:FireClient(player, {FieldOfView = 25}, {
			Time = 0.4,
			EasingStyle = Enum.EasingStyle.Exponential,
			EasingDirection = Enum.EasingDirection.InOut,
			RepeatCount = 0,
			Reverses = false,
			DelayTime = 0
		} :: globalTypes.tweenInfo)
		
	elseif key == InputActions.ZoomOut then
		if playerStatus[player.UserId].running == true then return end 
		playerStatus[player.UserId].isInScan = false
		UpdateCamera:FireClient(player, {FieldOfView = Settings.normalFOV}, {
			Time = 0.4,
			EasingStyle = Enum.EasingStyle.Exponential,
			EasingDirection = Enum.EasingDirection.InOut,
			RepeatCount = 0,
			Reverses = false,
			DelayTime = 0
		} :: globalTypes.tweenInfo)
	elseif key == InputActions.ThrowProjectile then
		launchProjectile:Fire(player)
	end
end

ServerInputManager.OnRequestScanState = function(player : Player)
	if not playerStatus[player.UserId] then serverLogger.Error("Missing player data.", "InputManager/RequestScanState") return end
	return playerStatus[player.UserId].isInScan
end

inputRemote.OnServerEvent:Connect(ServerInputManager.OnRunInput)
game.Players.PlayerAdded:Connect(ServerInputManager.OnPlayerJoined)
game.Players.PlayerRemoving:Connect(ServerInputManager.OnPlayerRemoving)
isInscan.OnServerInvoke = function(player : Player) return ServerInputManager.OnRequestScanState(player) end


return ServerInputManager
