local RSGCore = exports['rsg-core']:GetCoreObject()

local playerSpawn = false
local spawnRadius = 100.0--100.0
local prePlayerPosition = 0
local eventLoot = {PlCoords = nil, Model = nil}
local spawnedScenariopoint = {}


function CreateScenarioPoints()
	for index, herb in pairs(deleted_herbs) do
		if not spawnedScenariopoint[index] then
			local newScenPoint = CreateScenarioPointHash(joaat(herb.hash), herb.point.x, herb.point.y, herb.point.z, herb.point.w, herb.radius, 0.0, true)--0.0 radius
			spawnedScenariopoint[index] = newScenPoint
			if DoesScenarioPointExist(newScenPoint) and IsScenarioPointActive(newScenPoint) then
				--print("NewScenario = " .. newScenPoint)
				--print("hash = " .. herb.hash)
			else
				print("No scenario [" .. index .. "] index")				
			end
		end
	end
	Citizen.Wait(500)
end

--BOOL DOES_SCENARIO_POINT_EXIST ( int scenario )  //0x841475AC96E794D1
--void _SET_SCENARIO_POINT_ACTIVE ( int scenario, BOOL active )  //0xEEE4829304F93EEE

function CreateScenarioPointHash(scenarioHash, x, y, z, heading, radius, p6, bool_p7)
	return Citizen.InvokeNative(0x94B745CE41DB58A1, scenarioHash, x, y, z, heading, radius, p6, bool_p7, Citizen.ResultAsInteger())
end

RegisterNetEvent('rsg-composite:client:playerCompositeLoaded')
AddEventHandler('rsg-composite:client:playerCompositeLoaded', function(compositeData)
    -- Обработка полученных данных о координатах
    Config.FullLootedScenarioPoint = compositeData
	startPointCheck()
end)


AddEventHandler('RSGCore:Client:OnPlayerLoaded', function()	
	Wait(1000)
	TriggerServerEvent('rsg-composite:server:loadPlayerComposite')
	playerSpawn = true
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload')
AddEventHandler('RSGCore:Client:OnPlayerUnload', function()
    playerSpawn = false
end)

function getLootScenarioHash(playerPosition, spawnRadius, buffSize, foundNums)
    local scenarios = {}
	local DataStruct = DataView.ArrayBuffer(buffSize)
	local is_data_exists = GetScenarioPointsInArea(playerPosition, spawnRadius, DataStruct:Buffer(), foundNums)
	
	if is_data_exists then
		for i = 1, is_data_exists, 1 do
			local scenario = DataStruct:GetInt32(8 * i)			
			local hash = GetScenarioPointType(scenario)
			local herbsScenarioPoint = Config.composite_scenario[hash] or nil

			if DoesScenarioPointExist(scenario) then
				if herbsScenarioPoint and herbsScenarioPoint ~= nil  and IsScenarioPointActive(scenario) then					
					table.insert(scenarios, {scenario = scenario, herbsScenarioPoint = herbsScenarioPoint})
					--print("scenario = " .. scenario .. ", hash = " .. hash .. ", herbsScenarioPoint = " .. tostring(herbsScenarioPoint))
				end
			end
		end
		return scenarios
	end
end

function startPointCheck()	
	--void NETWORK_SET_SCRIPT_IS_SAFE_FOR_NETWORK_GAME ()  //0x3D0EAC6385DD6100
	Citizen.InvokeNative(0x3D0EAC6385DD6100)
	CreateScenarioPoints()
	while not playerSpawn do -- Ждать, пока игрок не заспавнится
		Citizen.Wait(1000)		
		return
	end

	Citizen.CreateThread(function()
	Citizen.Wait(0)
		while playerSpawn do
			Citizen.Wait(2000) -- 2 sec
			local playerPosition = GetEntityCoords(PlayerPedId())
			
			if PlayerMovedTooFar(playerPosition, prePlayerPosition, 3.0) then
	
				local scenarios = getLootScenarioHash(playerPosition, spawnRadius, 8192, 600)
				for _, scenarioData in ipairs(scenarios) do
					local pointCoords = GetScenarioPointCoords(scenarioData.scenario, true)
					local pointHeading = GetScenarioPointHeading(scenarioData.scenario, true)
					local herbHash = scenarioData.herbsScenarioPoint.herbHesh
					local herbID = scenarioData.herbsScenarioPoint.HerbID
					if herbHash == "COMPOSITE_LOOTABLE_GATOR_EGG_3_DEF" then
						local gattorEggNum = 0
						gattorEggNum = math.random(0, 2)
						herbID = herbID + gattorEggNum
						herbHash = "COMPOSITE_LOOTABLE_GATOR_EGG_" .. 3 + gattorEggNum .. "_DEF"
					end
					CreateServerComposite(herbID, herbHash, pointCoords, pointHeading)
				end
			prePlayerPosition = playerPosition
			end			
		end
	end)
end

function PlayerMovedTooFar(currentPos, prevPos, radius)
    local dist = #(currentPos - prevPos)  -- вычисляем расстояние между текущей и предыдущей позициями
    return dist > radius  -- возвращаем true, если расстояние больше заданного радиуса, иначе false
end

local Eat = false
local player = 0

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
		if playerSpawn then
		
		player = PlayerPedId()
		if HasAnimEventFired(player, joaat("EFFECTPLANTBLIP")) then
			eventLoot.PlCoords = GetEntityCoords(player)--срабатывает и при съедани вначале этот ивент потом EATPLANT
			--print("EFFECTPLANTBLIP")
		end
					
		if HasAnimEventFired(player, joaat("EATPLANT")) then
			Eat = true
		end
		
		local size = GetNumberOfEvents(0)
		if size > 0 then				
			for i = 0, size - 1 do
				local eventAtIndex = GetEventAtIndex(0, i)
				--player = PlayerPedId()
				
				if eventAtIndex == joaat("EVENT_LOOT_PLANT_START") then
					--if eventLoot.PlCoords == nil then
					--	local playerPosition = GetEntityCoords(player)
					--	eventLoot.PlCoords = playerPosition
					--end
					--print(json.encode(GetHerbCompositeNumEntities3(10.0)))
					
				elseif eventAtIndex == joaat("EVENT_LOOT") then
				--if eventAtIndex == joaat("EVENT_LOOT") then
					local view = exports["rsg-composite"]:DataViewNativeGetEventDataT(0, i, 36)
					local model = view["56"]
					--print("unk1 = " .. tostring(view["48"]))
					--print("unk2 = " .. tostring(view["50"]))
					--print("unk3 = " .. tostring(view["52"]))
					--print("unk4 = " .. tostring(view["54"]))
					--print("unk5 = " .. tostring(view["56"]))
					--print("unk6 = " .. tostring(view["58"]))
					eventLoot.Model = model
				elseif eventAtIndex == joaat("EVENT_LOOT_COMPLETE") then
					local view = exports["rsg-composite"]:DataViewNativeGetEventDataT(0, i, 3)
					local ped = view["0"] --прилетает наш Ped-Player
					print("lootCompliteEnt = " .. tostring(view["2"]))
					if eventLoot.Model == nil or eventLoot.Model == 0 then
						local entity = view["2"]						
						local model = GetEntityModel(entity)
						eventLoot.Model = model						
						
						--print("model " .. model)
					end
					--для яиц
					if eventLoot.PlCoords == nil then
						local playerPosition = GetEntityCoords(player)
						eventLoot.PlCoords = playerPosition
					end
					
					if ped ~= player then
						eventLoot = {PlCoords = nil, Model = nil}
					else
						PickupOrEaten()--стоит здесь потому что срабатывает последним
					end					
				end
			end
		end
		end
	end
end)


function PickupOrEaten()
	if eventLoot.PlCoords and eventLoot.Model ~= 0 then
		if Eat == false then--Pickup
			FindPicupCompositeAndCoords(eventLoot.PlCoords, eventLoot.Model, true)
			--print("Мы собрали " .. eventLoot.Model)
			Eat = false
		else --Eat
			FindPicupCompositeAndCoords(eventLoot.PlCoords, eventLoot.Model, false)
			--print("Мы съели " .. eventLoot.Model)
			Eat = false
		end
	else
		--print("ERROR: no model or Coords or it's not composite")
	end
	eventLoot = {PlCoords = nil, Model = nil}
end

function DumpTable(tbl)
    for k, v in pairs(tbl) do
        print(k, v)
    end
end

function GetScenarioPointType(id)
    return Citizen.InvokeNative(0xA92450B5AE687AAF, id)
end
--вот так работает. Правильно возвращает вектор
function GetScenarioPointCoords(scenario, bool_p1)
	return Citizen.InvokeNative(0xA8452DD321607029, scenario, bool_p1, Citizen.ResultAsVector())
end

function GetScenarioPointHeading(scenario, bool_p1)
	return Citizen.InvokeNative(0xB93EA7184BAA85C3, scenario, bool_p1, Citizen.ResultAsFloat())
end



function GetScenarioPointsInArea(posX, posY, posZ, radius, scenariosInRadius, size)
	return Citizen.InvokeNative(0x345EC3B7EBDE1CB5, posX, posY, posZ, radius, scenariosInRadius, size, Citizen.ResultAsInteger())
end


function DoesScenarioPointExist(scenario)
    return Citizen.InvokeNative(0x841475AC96E794D1, scenario)
end

function IsScenarioPointActive(scenario)
    return Citizen.InvokeNative(0x0CC36D4156006509, scenario)
end

function SetScenarioPointActive(scenario, toggle)
    return Citizen.InvokeNative(0xEEE4829304F93EEE, scenario, toggle)
end



function FindScenarioOfTypeHash(posX, posY, posZ, scenarioType, distance) --FIND_SCENARIO_OF_TYPE_HASH
	return Citizen.InvokeNative(0xF533D68FF970D190, posX, posY, posZ, scenarioType, distance, 0, false, Citizen.ResultAsInteger())
end

function DoesScenarioOfTypeExistInAreaHash(posX, posY, posZ, scenarioType, distance) --DOES_SCENARIO_OF_TYPE_EXIST_IN_AREA_HASH
	return Citizen.InvokeNative(0x6EEAD6AF637DA752, posX, posY, posZ, scenarioType, distance, false)
end

function GetScenarioPointRadius(id)
    return Citizen.InvokeNative(0x6718F40313A2B5A6, id, Citizen.ResultAsFloat())
end


--При перезагрузке очищает все что вносили в таблицу
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
		playerSpawn = false
		--void _DELETE_SCENARIO_POINT ( int scenario )  //0x81948DFE4F5A0283
		for index, scenariopointId in pairs(spawnedScenariopoint) do
			if DoesScenarioPointExist(scenariopointId) then
				Citizen.InvokeNative(0x81948DFE4F5A0283, scenariopointId)
				spawnedScenariopoint[index] = nil
				--print("Индекс:", index, "ID точки сценария:", scenariopointId)				
			end
		end
end)

AddEventHandler('onResourceStart', function(resource)
	if resource == GetCurrentResourceName() then
		if LocalPlayer.state.isLoggedIn then
			TriggerEvent('RSGCore:Client:OnPlayerLoaded')
			--print("onResourceStart")
		end
	end
end)