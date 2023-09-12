--[[
	A spawner module script for the monsters in the mine. Controls all monster spawns / despawns.
--]]

local module = {}

function module.loadMonsterSpawnSystem(scriptObject)
	local floorNum = (tonumber(string.sub(scriptObject.Parent.Name, 6)))
	local remoteEvents = scriptObject.Parent.Parent.RemoteEvents
	local floorEnteredEvent = remoteEvents.FloorEntered
	local currentPlayers = {}
	local monstersActive = false
	
	local function rollMonster()
		local picked = ""
		local roll = (math.random(0, 100000)) / 1000
		local sum = 0
		local monsterData = {}
		for i,v in pairs(scriptObject.Parent.MonsterSpawns:GetChildren()) do
			local monsterName = v.Name
			local monsterMin = sum
			local monsterMax = sum + ((math.floor(v.Value * 100000)) / 100000)
			local data = {monsterName, monsterMin, monsterMax}
			table.insert(monsterData, data)
			sum = monsterMax
		end
		for i,v in pairs(monsterData) do
			if roll >= v[2] and roll <= v[3] then
				picked = v[1]
				break
			end
		end
		return picked
	end

	local function rollMonsterF(folder)
		local picked = ""
		local roll = (math.random(0, 100000)) / 1000
		local sum = 0
		local monsterData = {}
		for i,v in pairs(folder:GetChildren()) do
			local monsterName = v.Name
			local monsterMin = sum
			local monsterMax = sum + ((math.floor(v.Value * 100000)) / 100000)
			local data = {monsterName, monsterMin, monsterMax}
			table.insert(monsterData, data)
			sum = monsterMax
		end
		for i,v in pairs(monsterData) do
			if roll >= v[2] and roll <= v[3] then
				picked = v[1]
				break
			end
		end
		return picked
	end

	local monsters = {}

	local function createMonster(spawnPart)
		local pickedMonster
		local function conditionsMet(pickedMonster)
			if game.ReplicatedStorage.Monsters:FindFirstChild(pickedMonster).Config:FindFirstChild("AquaticOnly") then
				if game.ReplicatedStorage.Monsters:FindFirstChild(pickedMonster).Config:FindFirstChild("AquaticOnly").Value == true then
					local foundWater = false
					local waterRay = Ray.new(spawnPart.Position + Vector3.new(0, 15, 0), Vector3.new(0,-10,0)*100)
					local objecthit, hitposition = workspace:FindPartOnRay(waterRay, spawnPart, false, false)
					if objecthit.Name == "Terrain" then
						foundWater = true
					end
					if foundWater == false then
						return false
					end
				end
			end
			return true
		end
		if spawnPart:FindFirstChild("OSpawnF") then
			repeat
				pickedMonster = rollMonsterF(spawnPart:FindFirstChild("OSpawnF"))
			until conditionsMet(pickedMonster)			
		else
			repeat
				pickedMonster = rollMonster()
			until conditionsMet(pickedMonster)		
		end
		local clone = game.ReplicatedStorage.Monsters:FindFirstChild(pickedMonster):Clone()
		if game.ReplicatedStorage.Monsters:FindFirstChild(pickedMonster).Config.NeedsWelding.Value == true then
			local welding = game.ReplicatedStorage.EnemyScripts.Welding:Clone()
			welding.Parent = clone
			welding.Disabled = false
		end
		wait()
		if clone.PrimaryPart == nil then
			clone.PrimaryPart = clone:FindFirstChild("HumanoidRootPart")
		end
		clone:SetPrimaryPartCFrame(spawnPart.CFrame + Vector3.new(0, 2, 0))
		clone.Parent = spawnPart
		table.insert(monsters, clone)
		if clone:FindFirstChild("ScriptImporter") then
			clone:FindFirstChild("ScriptImporter").Disabled = false
		end
	end

	local spawns = {}

	for i,v in pairs(scriptObject.Parent.MonsterSpawnFolder:GetChildren()) do
		if v:IsA("BasePart") and v.Name == "Spawn" then
			v.Transparency = 1
			table.insert(spawns, v)
		end
	end

	local removedConnections = {}

	local function spawnMonsters()
		for i,v in pairs(spawns) do
			createMonster(v)
			local removedConnection = v.ChildRemoved:Connect(function(monsterRemoved)
				local children = v:GetChildren()
				local childrenCount = #children
				if childrenCount == 0 then
					wait(monsterRemoved.Config.RespawnTime.Value)
					if #currentPlayers > 0 then
						createMonster(v)
					end
				end
			end)
			table.insert(removedConnections, removedConnection)
		end
	end

	local function monsterSpawnCheck()
		if #currentPlayers > 0 then
			if monstersActive == false then
				monstersActive = true
				spawnMonsters()
				print("SPAWNED MONSTERS ON ", scriptObject.Parent.Name)
			end
		else
			for i,v in pairs(removedConnections) do
				v:Disconnect()
			end
			removedConnections = {}
			for i,v in pairs(monsters) do
				v:Destroy()
			end
			monstersActive = false
			print("DESPAWNED MONSTERS ON ", scriptObject.Parent.Name)
		end
	end

	local teleportChangeConnection = nil
	local diedConnection = nil
	local leftConnection = nil
	
	floorEnteredEvent.OnServerEvent:Connect(function(player, enterNum)
		if enterNum == floorNum and table.find(currentPlayers, player) == nil then
			table.insert(currentPlayers, player)
			local function playerFailsafeCheck()
				for i,v in pairs(currentPlayers) do
					if v and game.Players:FindFirstChild(v.Name) == nil then
						table.remove(currentPlayers, i)
					end
				end
			end
			local function removePlayerFromTable()
				local position = table.find(currentPlayers, player)
				while position ~= nil do
					table.remove(currentPlayers, position)
					position = table.find(currentPlayers, player)
				end
				playerFailsafeCheck()
				monsterSpawnCheck()
			end
			local function disconnectConnections()
				if diedConnection ~= nil then
					diedConnection:Disconnect()
					diedConnection = nil
				end
				if teleportChangeConnection ~= nil then
					teleportChangeConnection:Disconnect()
					teleportChangeConnection = nil
				end			
				if leftConnection ~= nil then
					leftConnection:Disconnect()
					leftConnection = nil
				end
			end
			teleportChangeConnection = game.ReplicatedStorage.LastTeleportChanged.OnServerEvent:Connect(function(changeplayer, enteredFloorNum)
				if changeplayer == player and enteredFloorNum ~= floorNum then
					disconnectConnections()
					removePlayerFromTable()
				end
			end)
			diedConnection = player.Character.Humanoid.Died:Connect(function()	
				disconnectConnections()	
				wait(5)
				removePlayerFromTable()
			end)
			leftConnection = game.Players.PlayerRemoving:Connect(function(remPlayer)
				if player == remPlayer then
					disconnectConnections()
					removePlayerFromTable()						
				end
			end)
			monsterSpawnCheck()
		end
	end)
end

return module
