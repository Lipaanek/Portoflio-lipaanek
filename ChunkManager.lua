-- Chunk manager for backrooms level 0 level procedural generation
local Utils = {}

local ChunkSize : number = 75
local loadedChunks =  {} :: {
	instance : Instance,
	data : {},
}
local serverSessionSeed : number = nil
local chunkFolder : Folder = game.ReplicatedStorage.MazeTemplates

local function coordToString(coord : Vector2) : string
	return tostring(coord.X) .. "," .. tostring(coord.Y)
end

local function generateChunkPart(coord : Vector2, rng : Random, yPosition : number) : Instance
	local chunkModels = chunkFolder:GetChildren()
	local randomChunk = chunkModels[rng:NextInteger(1, #chunkModels)]:Clone()
	local chunkPosition = Vector3.new(coord.X * ChunkSize, yPosition, coord.Y * ChunkSize)

	randomChunk:PivotTo(CFrame.new(chunkPosition))

	randomChunk.Parent = workspace
	return randomChunk
end

Utils.UpdateSeed = function(serverIncomeSeed : number) : ()
	serverSessionSeed = serverIncomeSeed
end

Utils.getChunkCoord = function(position : Vector3) : Vector2
	local x = math.floor(position.X / ChunkSize)
	local z = math.floor(position.Z / ChunkSize)
	return Vector2.new(x, z)
end

Utils.getVisibleChunks = function(centerChunk : Vector2, renderDistance : number) : {Vector2}
	local visible = {}
	local radius = math.ceil(renderDistance / ChunkSize)
	for dx = -radius, radius do
		for dz = -radius, radius do
			local coord = centerChunk + Vector2.new(dx, dz)
			table.insert(visible, coord)
		end
	end
	return visible
end

Utils.updateChunks = function(playerPos: Vector3) : ()
	local center = Utils.getChunkCoord(playerPos)
	local visible = Utils.getVisibleChunks(center, 150)

	for coordStr : string, _ in pairs(loadedChunks) do
		local coord = Vector2.new(
			tonumber(coordStr:match("^(%-?%d+),")),
			tonumber(coordStr:match(",(-?%d+)$"))
		)

		if not Utils.isCoordVisible(coord, visible) then
			Utils.unloadChunk(coord)
		end
	end

	for _, coord : Vector2 in ipairs(visible) do
		local coordStr = coordToString(coord)
		if not loadedChunks[coordStr] then
			Utils.loadChunk(coord)
		end
	end
end

Utils.isCoordVisible = function(coord : Vector2, visible : {Vector2}) : true | false
	for _, v in ipairs(visible) do
		if v.X == coord.X and v.Y == coord.Y then
			return true
		end
	end
	return false
end

Utils.loadChunk = function(coord : Vector2) : ()
	local coordStr = coordToString(coord)
	if loadedChunks[coordStr] then return end

	local seed = serverSessionSeed + coord.X * 10007 + coord.Y * 32497
	local rng = Random.new(seed)
	local part = generateChunkPart(coord, rng, 50)

	loadedChunks[coordStr] = { instance = part, data = {} }
end

Utils.unloadChunk = function(coord : Vector2) : ()
	local coordStr = coordToString(coord)

	if loadedChunks[coordStr] then
		loadedChunks[coordStr].instance:Destroy()
		loadedChunks[coordStr] = nil
	end
end

return Utils
