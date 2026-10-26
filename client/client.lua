local RSGCore = exports['rsg-core']:GetCoreObject()

playerSpawn = false
--local playerSpawn = false
local SPAWN_RADIUS = 100.0--100.0
local prePlayerPosition = nil
local eventLoot = {PlCoords = nil, Model = nil, Eat = false}
local spawnedScenariopoint = {}
local SCENARIO_BUF_SIZE = 8192
local scenarioBuf = DataView.ArrayBuffer(SCENARIO_BUF_SIZE)


RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
	Wait(1000)
	RSGCore.Functions.TriggerCallback('rsg-composite:server:GetPlayerComposites', function(compositeData)
		Config.FullLootedScenarioPoint = compositeData
		TriggerEvent('rsg-composite:client:CompositeDataLoaded')
		playerSpawn = true	
		startPointCheck()
	end)	
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    playerSpawn = false
    TriggerEvent('rsg-composite:client:CompositeDataUnloaded')
end)

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
	Wait(500)
end

--BOOL DOES_SCENARIO_POINT_EXIST ( int scenario )  //0x841475AC96E794D1
--void _SET_SCENARIO_POINT_ACTIVE ( int scenario, BOOL active )  //0xEEE4829304F93EEE

function CreateScenarioPointHash(scenarioHash, x, y, z, heading, radius, p6, bool_p7)
	return Citizen.InvokeNative(0x94B745CE41DB58A1, scenarioHash, x, y, z, heading, radius, p6, bool_p7, Citizen.ResultAsInteger())
end

function getLootScenarioHash(playerPosition, spawnRadius, foundNums)
    local scenarios = {}
	--local DataStruct = DataView.ArrayBuffer(buffSize)
	-- GetScenarioPointsInArea expects separate X/Y/Z values. Each returned point
	-- occupies an 8-byte buffer slot; Lua's first loop index is 1.
	local is_data_exists = GetScenarioPointsInArea(
		playerPosition.x, playerPosition.y, playerPosition.z,
		spawnRadius, scenarioBuf:Buffer(), foundNums
	)
	
	if is_data_exists and is_data_exists > 0 then
		local scenarioCount = math.min(is_data_exists, foundNums, math.floor(SCENARIO_BUF_SIZE / 8) - 1)
		for i = 1, scenarioCount, 1 do
			local scenario = scenarioBuf:GetInt32(8 * i)
			if DoesScenarioPointExist(scenario) then
				local hash = GetScenarioPointType(scenario)
				local herbsScenarioPoint = Config.composite_scenario[hash]
				if herbsScenarioPoint and IsScenarioPointActive(scenario) then
					table.insert(scenarios, {scenario = scenario, herbsScenarioPoint = herbsScenarioPoint})
				end
			end
		end
	end
	return scenarios
end

function ResolveEggScenario(scenarioData)
    local herbID = scenarioData.herbsScenarioPoint.HerbID
    local compositeHash = scenarioData.herbsScenarioPoint.herbHesh

    -- The world has one alligator-egg scenario hash. Choose the clutch size per spawn.
    if compositeHash == "COMPOSITE_LOOTABLE_GATOR_EGG_3_DEF" then
        local clutchSize = math.random(3, 5)
        herbID = 54 + clutchSize - 3
        compositeHash = ("COMPOSITE_LOOTABLE_GATOR_EGG_%d_DEF"):format(clutchSize)
    end

    return herbID, compositeHash
end

function startPointCheck()	
	--void NETWORK_SET_SCRIPT_IS_SAFE_FOR_NETWORK_GAME ()  //0x3D0EAC6385DD6100
	Citizen.InvokeNative(0x3D0EAC6385DD6100)
	CreateScenarioPoints()
	--while not playerSpawn do -- Ждать, пока игрок не заспавнится
	--	Wait(1000)
	--end

	CreateThread(function()
		Wait(1)
		while playerSpawn do
			Wait(2000) -- 2 sec
			local playerPosition = GetEntityCoords(PlayerPedId())
			
			if PlayerMovedTooFar(playerPosition, prePlayerPosition, 3.0) then
				-- Запускаем дистанционную очистку даже если рядом больше нет активных точек.
				-- Если все очищено - то ничего не будет очищать и грузить систему потому что стоит условие if spawnCompositeNum > 0 then
				checkRecordAndClear(playerPosition)																																 
				local scenarios = getLootScenarioHash(playerPosition, SPAWN_RADIUS, 600)
				for _, scenarioData in ipairs(scenarios) do
					local pointCoords = GetScenarioPointCoords(scenarioData.scenario, true)
					local pointHeading = GetScenarioPointHeading(scenarioData.scenario, true)
					local herbID, herbHash
					if isEggs(scenarioData.herbsScenarioPoint.HerbID) then
						herbID, herbHash = ResolveEggScenario(scenarioData)
					else
						herbID = scenarioData.herbsScenarioPoint.HerbID
						herbHash = scenarioData.herbsScenarioPoint.herbHesh
					end
					CreateServerComposite(herbID, herbHash, pointCoords, pointHeading)
				end
			prePlayerPosition = playerPosition
			end			
		end
	end)
end

function PlayerMovedTooFar(currentPos, prevPos, radius)
	if not prePlayerPosition then return true end --защита от нулевого вектора.
    local dist = #(currentPos - prevPos)  -- вычисляем расстояние между текущей и предыдущей позициями
    return dist > radius  -- возвращаем true, если расстояние больше заданного радиуса, иначе false
end

--local Eat = false
local player = 0

CreateThread(function()
	while true do		
		if not playerSpawn then
            Wait(500)
        else
			player = PlayerPedId()
			if HasAnimEventFired(player, `EFFECTPLANTBLIP`) or HasAnimEventFired(player, `ADDEGG`) then
				eventLoot.PlCoords = GetEntityCoords(player)--срабатывает и при съедани вначале этот ивент потом EATPLANT
				--print("EFFECTPLANTBLIP")
				--local value = Citizen.InvokeNative(0x678D3226CF70B9C8, player, false) --на самом деле получем Entity кого собрали.
			end
	
			if HasAnimEventFired(player, `EATPLANT`) then
				eventLoot.Eat = true
				--print("EATPLANT")
			end
	
			local size = GetNumberOfEvents(0)
			if size > 0 then
				for i = 0, size - 1 do
					local eventAtIndex = GetEventAtIndex(0, i)
			
					if eventAtIndex == `EVENT_CALCULATE_LOOT` then
						if eventLoot.PlCoords == nil then
							eventLoot.PlCoords = GetEntityCoords(player)
						end
						--print("<----EVENT_CALCULATE_LOOT---->")
					elseif eventAtIndex == `EVENT_LOOT` then
						if IsPedOnMount(player) == false then
							local view = exports["rsg-composite"]:DataViewNativeGetEventDataT(0, i, 36)
							eventLoot.Model = view["56"]
						end
						--print("<----EVENT_LOOT---->")
					elseif eventAtIndex == `EVENT_LOOT_COMPLETE` then
						local view = exports["rsg-composite"]:DataViewNativeGetEventDataT(0, i, 3)
						local ped = view["0"] --прилетает наш Ped-Player
						local lootedEntity = view["2"]
						local lootSuccess = view["4"] == true or view["4"] == 1
						local targetModel = lootedEntity and lootedEntity ~= 0 and GetEntityModel(lootedEntity) or 0
						if eventLoot.Model == nil or eventLoot.Model == 0 then
							eventLoot.Model = targetModel
							--print("EVENT_LOOT_COMPLETE MODEL = " .. tostring(eventLoot.Model))
						end
						--для яиц и для сбора на лошади
						if eventLoot.PlCoords == nil then
							eventLoot.PlCoords = GetEntityCoords(player)
						end
			
						if ped == player then
							if HandleTreeEggLootComplete then
								HandleTreeEggLootComplete(ped, lootedEntity, targetModel, lootSuccess)
							end
							if eventLoot.PlCoords and eventLoot.Model then
								local pickupCoords = eventLoot.PlCoords
								local lootedModel = eventLoot.Model
								local isPickup = not eventLoot.Eat
								
								if IsValidHerbModel(lootedModel) then
									CreateThread(function()
										FindPicupCompositeAndCoords(pickupCoords, lootedModel, isPickup)
									end)
								end
							end
						end						
						eventLoot.PlCoords = nil
						eventLoot.Model = nil
						eventLoot.Eat = false
						--print("<----EVENT_LOOT_COMPLETE---->")
					--elseif eventAtIndex == `EVENT_LOOT_PLANT_START` then						
					--	local view = exports["rsg-composite"]:DataViewNativeGetEventDataT(0, i, 72)
					--	print("<----EVENT_LOOT_PLANT_START---->" .. tostring(view["0"]), tostring(view["1"]), tostring(view["2"]), tostring(view["3"]), tostring(view["4"]))
					--	--срабатывает только когда съедает растение или поднимает- но только мелкие- кусты не срабатывают
					--end
					----------------------------------------------------------------------------
					------------------------------------РАКИ------------------------------------
					----------------------------------------------------------------------------
					elseif Config.EnableCrayFish then
						if eventAtIndex == `EVENT_ITEM_PROMPT_INFO_REQUEST` then
							local view = exports["rsg-composite"]:DataViewNativeGetEventDataT(0, i, 2)
							local entity = view["0"]
							local inventoryItem = view["2"]
							
							if inventoryItem == `UPGRADE_FSH_BAIT_CRAYFISH` then
							
								local struct = DataView.ArrayBuffer(8*12)
								struct:SetInt32(8*0, entity)
								struct:SetInt32(8*1, inventoryItem)
								struct:SetInt32(8*2, inventoryItem)
								struct:SetInt64(8*3, 0) --сюда наверное можно поставить название предмета свое
								struct:SetInt32(8*4, 0) --тут должна быть цена предмета ItemdatabaseGetCostItem(inventoryItem, -915411861, 0)
								struct:SetInt32(8*5, 0) --тут тоже цена прилетает, но с множителем на количесвто
								struct:SetInt32(8*6, 3) -- 0 -проверить 3 - только взять 3 | 4 - только взять затемнена кнопка 3 | 8 -проверить 3 | 16 -осмотреть и взять активны
								struct:SetInt32(8*7, 1)
								struct:SetInt32(8*8, 0)
								struct:SetInt32(8*9, 0)
								struct:SetInt32(8*10, 0)
								struct:SetInt32(8*11, 0)
							
								Citizen.InvokeNative(0xFD41D1D4350F6413, struct:Buffer())
							end
						elseif eventAtIndex == `EVENT_INVENTORY_ITEM_PICKED_UP` then
							local view = exports["rsg-composite"]:DataViewNativeGetEventDataT(0, i, 5)
							local inventoryItem = view["0"] --UPGRADE_FSH_BAIT_CRAYFISH(149706141)
							local model = view["2"] --p_crayfish01x(-445365508)
							local targetEntity = view["8"] --target_entity
							
							if inventoryItem == `UPGRADE_FSH_BAIT_CRAYFISH` and model == `p_crayfish01x` then
								PrintDebug("[crayfish] inventoryItem = " .. tostring(inventoryItem), "model = " .. tostring(model), "targetEntity = " .. tostring(targetEntity))
								
								local holeIndex = FindHoleByCrayfishEntity(targetEntity)
								
								if holeIndex then
									local state = GetHoleState(holeIndex)
						
									if not state.exhausted and not state.pending then
										state.pending = true
									
										state.collected = state.collected + 1
										state.exhausted = state.collected >= state.limit
										
										DeleteCrayfishAtHole(holeIndex)
										DeleteCrayfishScenario(holeIndex)
									
										PrintDebug(('[crayfish] Нора %d: добыто %d/%d, exhausted=%s'):format(holeIndex, state.collected, state.limit, tostring(state.exhausted)))

										-- Здесь выдача награды и т.д.
										TriggerServerEvent('rsg-composite:server:Gathered', 200, 1)
										
										--если точка полностью собрана - отсылаем в БД
										if state.exhausted then
											Config.FullLootedScenarioPoint[state.key] = 0									
											TriggerServerEvent('rsg-composite:server:SaveGatheredPoint', state.key,	0)
										end
									
										state.pending = false
									end
								else
									print(('[crayfish] Подбор не сопоставлен с нашей норой: entity=%s'):format(
										tostring(targetEntity)
									))
								end
							end
						end
					end
					----------------------------------------------------------------------------
					------------------------------------РАКИ------------------------------------
					----------------------------------------------------------------------------
				end
			end
			Wait(1)
		end
	end
end)

function IsValidHerbModel(model)
    -- Проверяем что это именно хеш растения (например из GetHerbIDFromLootedModel)
    if model and model ~= 0 then
        local herbID = GetHerbIDFromLootedModel(model)
        return herbID ~= 0  -- Если найден ID - это растение
    end
    return false
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
		if LocalPlayer.state.isLoggedIn then --это для перезапуска если в игре
			--TriggerEvent('RSGCore:Client:OnPlayerLoaded')
			RSGCore.Functions.TriggerCallback('rsg-composite:server:GetPlayerComposites', function(compositeData)
				Config.FullLootedScenarioPoint = compositeData
				TriggerEvent('rsg-composite:client:CompositeDataLoaded')
				playerSpawn = true	
				startPointCheck()
			end)
		end
	end
end)
