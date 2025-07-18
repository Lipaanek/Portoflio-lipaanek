-- Generates dungeon of Lipaanek's game
local generation = 0 :: number
local maxGens = 250 :: number
local roomStart : Model = game.Workspace.Start

local MAX_ATTEMPTS = 3 :: number

local lastRoom : Model = nil
local wrongRoomCount = 0 :: number

local placementHistory : {[number] : Instance} = {}
local historyNumber = 1 :: number

local weightedChances = require(script.WeightedRandom)

local generatedFolder = workspace.Generated :: Folder

local rooms : {{any : number}} = {
	{value=game.ReplicatedStorage.Rooms.Room, weight=30/100},
	{value=game.ReplicatedStorage.Rooms.Hallway, weight=25/100},
	{value=game.ReplicatedStorage.Rooms.Room2, weight=20/100},
	{value=game.ReplicatedStorage.Rooms.Turn, weight=15/100},
	{value=game.ReplicatedStorage.Rooms.Turn2, weight=14/100},
}

local function addToIgnoreList(ignoreList: {BasePart}, ...) : {BasePart}
	for _, part in ipairs(...) do
		if not part:IsA("BasePart") then continue end
		table.insert(ignoreList, part)
	end
	return ignoreList
end


local function isSpaceFree(roomModel : Model, currentRoom : Model) : boolean

	if not roomModel.PrimaryPart then 
		warn("No PrimaryPart in room "..roomModel.Name)
		return false 
	end

	local cframe, size = roomModel:GetBoundingBox()
	if not cframe or not size then
		warn("Invalid bounding box for room "..roomModel.Name)
		return false
	end

	local checkPart = Instance.new("Part")
	checkPart.Anchored = true
	checkPart.CanCollide = true
	checkPart.Transparency = 1
	checkPart.Size = size
	checkPart.CFrame = cframe
	checkPart.Parent = workspace

	local ignoreList : {BasePart} = {checkPart}
	ignoreList = addToIgnoreList(ignoreList, currentRoom:GetDescendants())

	local overlapParams = OverlapParams.new()
	overlapParams.FilterDescendantsInstances = ignoreList
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude

	local overlappingParts = workspace:GetPartsInPart(checkPart, overlapParams)
	checkPart:Destroy()

	return (#overlappingParts == 0)
end

local function placeRoom(exit : BasePart, currentRoom : Model) : Model | nil
	for attempt = 1, MAX_ATTEMPTS do
		local roomTemplate = weightedChances.pick(rooms) :: Model
		if not roomTemplate then return nil end

		local room = roomTemplate:Clone() :: Model

		local entrance = room:FindFirstChild("Entrance") :: BasePart
		if entrance and room.PrimaryPart then
			local offset = room.PrimaryPart.CFrame * entrance.CFrame:Inverse()
			room:PivotTo(exit.CFrame * offset)
		elseif room.PrimaryPart then
			room:PivotTo(exit.CFrame)
		else
			warn("Room has no PrimaryPart or Entrance")
			return nil
		end

		if isSpaceFree(room, currentRoom) then
			room.Parent = generatedFolder
			return room
		else
			wrongRoomCount += 1
			room:Destroy()
		end
	end
	return nil
end

local function checkIfLimitReached() : boolean
	return generation >= maxGens
end


local function generateLevel(currentRoom : Model) : nil
	if checkIfLimitReached() then return nil end
	if wrongRoomCount > 15 and placementHistory[historyNumber] then
		if placementHistory[historyNumber] then
			placementHistory[historyNumber]:Destroy()
			placementHistory[historyNumber] = nil
		else
			warn("No room at placementHistory[" .. historyNumber .. "] to destroy")
		end

		historyNumber -= 1

		local levelfornext = placementHistory[historyNumber]
		if not levelfornext then warn("No previous room at placementHistory[" .. historyNumber .. "] to generate") return end
		generateLevel(levelfornext)
		return nil
	end

	generation += 1

	local exits = currentRoom:GetChildren() :: {Instance}
	for _, part in exits do
		if part.Name ~= "Exit" then continue end

		local placedRoom = placeRoom(part, currentRoom)
		if not placedRoom then continue end

		placementHistory[historyNumber] = placedRoom
		historyNumber+= 1
		coroutine.wrap(generateLevel)(placedRoom)
	end
end

local function addHighlight(room : Model) : nil
	local highlight = Instance.new("Highlight")
	highlight.Parent = room
	return nil
end

local function resetAndGenerateFromExistingRoom(pickedRooms : {[string] : Model})
	local generatedRooms = generatedFolder:GetChildren()
	if #generatedRooms == 0 then
		warn("No generated rooms found to pick from!")
		return
	end


	-- Pick one random room from generated rooms
	--local pickedRoom = generatedRooms[math.random(1, #generatedRooms)]
	for _, room in pairs(pickedRooms) do
		addHighlight(room)
	end

	task.wait(3)
	-- Delete all other rooms except pickedRoom
	for _, room in ipairs(generatedRooms) do
		local keep = false
		for _, pickedRoom in pairs(pickedRooms) do
			if pickedRoom == room then
				keep = true
				break
			end
		end
		if not keep then
			room:Destroy()
		end
	end

	-- Reset generation state and history
	generation = 0
	wrongRoomCount = 0
	placementHistory = {}
	historyNumber = 1

	for _, room in pairs(pickedRooms) do
		coroutine.wrap(generateLevel)(room)
	end
end

local function getPlayerPositionInsideRooms() : {[string] : Model}
	local players = game.Players:GetPlayers() :: {Player}
	if #players == 0 then return end

	local positions : {[string] : Model} = {}

	for _, player in ipairs(players) do
		local character = player.Character
		if not character or not character.PrimaryPart then continue end
		local charPos = character.PrimaryPart.Position

		-- Check which generated room the player is inside
		for _, room in ipairs(generatedFolder:GetChildren()) do
			if not room:IsA("Model") then continue end
			local cframe, size = room:GetBoundingBox()
			local min = cframe.Position - (size * 0.5)
			local max = cframe.Position + (size * 0.5)

			if
				charPos.X >= min.X and charPos.X <= max.X and
				charPos.Y >= min.Y and charPos.Y <= max.Y and
				charPos.Z >= min.Z and charPos.Z <= max.Z
			then
				positions[player.Name] = room
				break
			end
		end
	end

	return positions
end


generateLevel(roomStart)
while task.wait(15) do
	local playerPositions = getPlayerPositionInsideRooms()
	if not playerPositions then continue end

	local hasPlayers = false
	for _, _ in pairs(playerPositions) do
		hasPlayers = true
		break
	end

	if hasPlayers then
		resetAndGenerateFromExistingRoom(playerPositions)
	else
		warn("No players found inside any room, skipping regeneration to prevent deletion.")
	end
end
