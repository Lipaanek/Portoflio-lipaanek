local RockBounceManager = {}

local RunService = game:GetService("RunService")

local LaunchProjectile = game.ReplicatedStorage.Networking.LaunchProjectile
-- Settings
local gravity = Vector3.new(0, -workspace.Gravity, 0) :: Vector3
local bounceDamping = 0.6 :: number -- 0 = full stop, 1 = perfect bounce
local groundFriction = 0.8 :: number
local curveForce = 10 :: number -- adjust to control how hard the rock curves midair
local lifetime = 10 :: number -- seconds before cleanup

-- this function performs a raycast from the origin in the given direction, ignoring the given object
-- @param origin Vector3 the origin of the raycast
-- @param direction Vector3 the direction of the raycast
-- @param ignoreList {BasePart} is all the parts that are ignored
-- @return RaycastResult the result of the raycast
local function performRaycast(origin : Vector3, direction : Vector3, ignoreList : {BasePart}) : RaycastResult
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = ignoreList
	rayParams.IgnoreWater = true

	return workspace:Raycast(origin, direction, rayParams)
end

-- this function simulates a rock throwing and bouncing on the ground
-- @param rock BasePart the rock to bounce
-- @param velocity Vector3 the velocity of the rock
-- @param speed number the speed of the rock
-- @return nil
function RockBounceManager.ThrowRock(rock : BasePart, velocity : Vector3, speed : number) : nil
	local connection : RBXScriptConnection
	local startTime = tick() :: number
	local direction = velocity.Unit * speed :: Vector3
	local currentVelocity = direction :: Vector3
	local curveDirection = velocity:Cross(Vector3.new(0, 1, 0)).Unit * curveForce :: Vector3

	local lastPosition = rock.Position :: Vector3
	local ignoreList = {rock} :: {BasePart}

	connection = RunService.Heartbeat:Connect(function(dt : number)
		local age = tick() - startTime :: number
		if age > lifetime then
			connection:Disconnect()
			connection = nil
			rock.Anchored = true
			return
		end

		currentVelocity = currentVelocity + gravity * dt -- Apply gravity
		currentVelocity = currentVelocity + curveDirection * dt -- Apply curve force while in air
		-- Move the rock
		local nextPosition = rock.Position + currentVelocity * dt :: Vector3 

		-- Raycast to check for bounce
		local directionVector = nextPosition - lastPosition :: Vector3
		local rayResult = performRaycast(lastPosition, directionVector, ignoreList) :: RaycastResult

		if not rayResult then rock.Position = lastPosition else
			local normal = rayResult.Normal :: Vector3
			local position = rayResult.Position :: Vector3

			currentVelocity = currentVelocity - (1 + bounceDamping) * currentVelocity:Dot(normal) * normal	-- Reflect velocity with damping

			-- Apply friction on the tangential components
			local tangent = currentVelocity - currentVelocity:Dot(normal) * normal
			currentVelocity = tangent * groundFriction + normal * currentVelocity:Dot(normal)

			rock.Position = position + normal * 0.1 -- offset to prevent clipping

			rock.Position = nextPosition
		end
		
		lastPosition = rock.Position
	end)
end

LaunchProjectile.Event:Connect(function(player : Player)
	local camCFrame : CFrame = game.ReplicatedStorage.Remotes.RequestCamPos:InvokeClient(player)
	local projectile = Instance.new("Part", workspace) :: BasePart
	projectile.Size = Vector3.new(1,1,1)
	projectile.Anchored = true
	projectile.CanCollide = false
	projectile.Position = player.Character:FindFirstChild("Head").Position + player.Character:FindFirstChild("Head").CFrame.LookVector * 2
	RockBounceManager.ThrowRock(projectile, camCFrame.LookVector * 4, 85)
end)

return RockBounceManager
