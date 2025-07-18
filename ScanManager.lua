-- this script scans the area ahead for information
local ScanDataManager = {}

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- Datatypes and server logger
local globalTypes = require(ReplicatedStorage.globalTypes)
local serverLogger = require(ServerStorage.ServerLogger)
local globalEnums = require(ReplicatedStorage.globalEnums)

local scannedParents : {[Player] : {Instance}} = {}

-- Remotes
local ScanRF = ReplicatedStorage.Networking.ScanRF :: RemoteFunction

-- Get info from the part
-- @param part BasePart is the part to extract info from
-- @return string or nil
local function getInfoText(part: BasePart): string?
	local strVal = part:FindFirstChildOfClass("StringValue")
	return strVal and strVal.Value or nil
end

-- Get position from the part's parent
-- @param part BasePart is the part to extract parent and its position from
-- @return Vector3 or nil
local function getPosition(part: BasePart): Vector3?
	local objVal = part:FindFirstChildOfClass("ObjectValue")
	return objVal and objVal.Value and objVal.Value.Position or nil
end


-- Returns data releated to the object
-- @param player Player is the requester of the data
-- @param part BasePart is the part that has been scanned
-- @return globalTypes.scanData or nil
ScanDataManager.OnRequestObjectInfo = function(player : Player, part : BasePart) : globalTypes.scanData
	if not part then serverLogger.Warn("Part wasn't delivered through network.", "ScanDataManager") return nil end
	if part:GetAttribute("Coins") == nil then return nil end

	local coinsAttribute = part:GetAttribute("Coins")
	local coins = coinsAttribute and 25 or 0
	return {
		coins = coins,
		infoText = getInfoText(part),
		position = getPosition(part),
	}
end

-- Checks for the part if it's been scanned before, saves it in table and returns true if it has, false if it hasn't
-- @param player Player is the requester of the data
-- @param part BasePart is the part that has been scanned
-- @return boolean
ScanDataManager.OnHasBeenScanned = function(player : Player, part : BasePart) : boolean
	if not part then serverLogger.Warn("Part wasn't delivered through network.", "ScanDataManager") return nil end
	if not part:FindFirstChildOfClass("ObjectValue") then serverLogger.Warn("Invalid BasePart.", "ScanDataManager") return nil end

	if not scannedParents[player] then scannedParents[player] = {} end

	local partParent : ObjectValue? = part:FindFirstChildOfClass("ObjectValue")
	if typeof(partParent.Parent) ~= "Instance" then return nil end
	
	local elementFound = table.find(scannedParents[player], partParent.Value)
	if elementFound then
		return true
	else
		table.insert(scannedParents[player], partParent.Value)
		return false
	end
end

-- This function handles requests from clients, it's invoked by remote and calls other functions depending on the enum value
-- @param player Player is the requester
-- @param enum globalEnums.ScanRequest is the enum to check for the request
-- @param part BasePart is the part to be scanned
-- @return boolean or globalTypes.scanData
ScanDataManager.HandleRequests = function(player : Player, enum : string, part : BasePart)
	if not part then serverLogger.Warn("Part was not sent.", "ScanDataManager") return end
	if enum == globalEnums.ScanRequest.RequestObjectInfo then
		return ScanDataManager.OnRequestObjectInfo(player, part)
	elseif enum == globalEnums.ScanRequest.HasBeenScanned then
		return ScanDataManager.OnHasBeenScanned(player, part)
	end
end

ScanRF.OnServerInvoke = function(player : Player, enum : string, part : BasePart) return ScanDataManager.HandleRequests(player, enum, part) end

return ScanDataManager
