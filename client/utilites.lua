local RSGCore = exports['rsg-core']:GetCoreObject()

local playerSpawn = false
local Composite = {}
--local FullLootedScenarioPoint = {}
local DELETE_DISTANCE = 2900.0
local NEARBY_DISTANCE = 150.0
local EMERGENCY_DESPAWN_DISTANCE = 625.0
local MAX_SPAWN_COMPOSITE = 170
local PlaySoundCoordsTable = {}
local PlayEffectCoordsTable = {}
local MAX_RECORD_IN_TABLE = 500 --на самом деле 500 точек держится в таблице.
local isBusy = false
local isPickUp = false

local CompositePointCol = 0
local spawnCompositeNum = 1 --на случай если слишком много заспавнено и не очистилось

function checkRecordAndClear(playerPosition)
	local playerPos = playerPosition.xy
	
	-- Режим 1: Emergency - если критично много точек
	if CompositePointCol > MAX_RECORD_IN_TABLE then		
		for key, value in pairs(Composite) do
			local dist = #(playerPos - key)
			if dist > DELETE_DISTANCE then --должна быть больше чем радиус спавна и радиус скрытия заспавненых которые в таблице
				--print("Delete point = " .. key)
				deleteComposite(key, value.CompositeId, value.VegModifierHandle, value.Entitys)
				Composite[key] = nil
				CompositePointCol = CompositePointCol - 1
				if CompositePointCol < 1 then CompositePointCol = 1	end
			end
		end
		return
	end
	
	-- Режим 2: Normal - деспаун дальних
	for key, value in pairs(Composite) do
		local dist = #(playerPos - key)--150.0
		if dist > NEARBY_DISTANCE and value.PointSpawn then --должна быть больше чем радиус спавна и и меньше чем радиус для удаления из таблицы
			deleteComposite(key, value.CompositeId, value.VegModifierHandle, value.Entitys)
			--проверяем если еще есть composite на точке не собранные- то просто обнуляем
			--а если все собрали то удаляем запись
			if not HerbsRemains(key) then
				Composite[key] = nil--убираем запись.
				CompositePointCol = CompositePointCol - 1
				if CompositePointCol < 1 then CompositePointCol = 1	end
				if Config.Debug then
					print("No more composite in point. Delete record in Composite")
				end
			else				
				Composite[key].CompositeId = {}
				Composite[key].VegModifierHandle = {}
				Composite[key].PointSpawn = false
				--print("Despawn point = " .. key)
			end
		end
	end

	--Экстренный деспавн если слишком много заспавненых composite
	--максимум можно показать сразу 180 composite
	if spawnCompositeNum >= MAX_SPAWN_COMPOSITE then
		for key, value in pairs(Composite) do
			local dist = #(playerPos - key)
			if dist >= EMERGENCY_DESPAWN_DISTANCE then --должна быть больше чем радиус спавна и и меньше чем радиус для удаления из таблицы
				print("Emergency Despawn point = " .. key)
				deleteComposite(key, value.CompositeId, value.VegModifierHandle, value.Entitys)
				Composite[key].CompositeId = {}
				Composite[key].VegModifierHandle = {}
				Composite[key].PointSpawn = false
			end
		end
	end
	
	--if Config.Debug then
	--	print("Spawn composite num = " .. tostring(spawnCompositeNum))
	--end
end

function countComposites()
    local count = 0
    for _ in pairs(Composite) do
        count = count + 1
    end
    return count
end

function DeactivatePoints(scenario)
	SetScenarioPointActive(scenario, false)
end

function StartCreateComposite(sHerbID, sCompositeHash, sPointCoords, sHeading, sPackedSlots)
	local playerPosition = GetEntityCoords(PlayerPedId())
	local pointCoords = sPointCoords
	local herbCoords = {}
	local SpawnCol = 0
	local haveRecord = false
	local HerbID = sHerbID
	local compositeHash = sCompositeHash	
	local packedSlots = sPackedSlots
	local key = KeyFromCoords(pointCoords.xy)
	
	--если уже точка собрана ничего не делаем.
	if Config.FullLootedScenarioPoint[key] then
		local scenario = Config.FullLootedScenarioPoint[key]
		if IsScenarioPointActive(scenario) then
			SetScenarioPointActive(scenario, false)
		end
		return
	end	
	-- Если записи нет в Composite, создаем её
	if not Composite[pointCoords.xy] then
		Composite[pointCoords.xy] = {HerbID = HerbID, CompositeHash = compositeHash,
            PointSpawn = false, CompositeId = {}, PackedSlots = packedSlots, HerbCoords = {},
            VegModifierHandle = {}, AttachEntity = nil, Entitys = {}, GroupPromt = nil, PickupPrompt = nil
        }
		CompositePointCol = CompositePointCol + 1
		haveRecord = false
	else
		HerbID = Composite[pointCoords.xy].HerbID
		compositeHash = Composite[pointCoords.xy].CompositeHash
		packedSlots = Composite[pointCoords.xy].PackedSlots
		SpawnCol = GetSpawnCol(HerbID)
		if SpawnCol ~= 3 then--Это для заполнения всех растений кроме одиночных
			herbCoords = Composite[pointCoords.xy].HerbCoords
		else--Это для одиночных
			herbCoords[1] = pointCoords
		end
		haveRecord = true
	end
	
	checkRecordAndClear(playerPosition)		
	-- Проверка на день и ночь
	local HOURS = GetClockHours()
	if HOURS < 22 and HOURS >= 5 and Config.Composites[HerbID].spawn.isNightHerb then
		--deleteComposite(&Var0);--если день то надо удалять эти растения
		--очищаем запись потому что сейчас день и не надо создавать ночные растения
		Composite[pointCoords.xy] = nil
		return
	end
	
	if HerbID ~= 0 and haveRecord == false then
		--print("First Spawn")
		-- Первоначальный спаун растений
		herbCoords = CreateHerbsCoords(pointCoords, packedSlots)
		Composite[pointCoords.xy].HerbCoords = herbCoords
		spawnCompositeEntities(compositeHash, herbCoords, sHeading, HerbID, packedSlots, pointCoords)
	elseif HerbID ~= 0 and haveRecord == true and Composite[pointCoords.xy].PointSpawn == false then--проверка на заспавненую точку
		--print("Second Spawn")
		-- Повторный спаун
		spawnCompositeEntities(compositeHash, herbCoords, sHeading, HerbID, packedSlots, pointCoords)
	elseif HerbID == 0 or HerbID == nil then
		print("No HerbID for " .. compositeHash)
	elseif HerbHash == 0 then
		return
	end	
end

-- Функция для спауна композитных объектов
function spawnCompositeEntities(compositeHash, herbCoords, sHeading, HerbID, packedSlots, pointCoords)
    for index = 1, #packedSlots do
        if packedSlots[index] ~= nil then
            RequestAndWaitForComposite(compositeHash)
            local compositeId, vegModifierHandle = CreateComposite(index, compositeHash, herbCoords, sHeading, HerbID, packedSlots, pointCoords)
            if compositeId and compositeId > 0 then
                Composite[pointCoords.xy].CompositeId[index] = compositeId
                Composite[pointCoords.xy].VegModifierHandle[index] = vegModifierHandle
                Composite[pointCoords.xy].PointSpawn = true
            end
        end
    end
end

function CreateServerComposite(herbID, hash, pointCoords, pointHeading)
	--local serverComposite = {}
	if not Composite[pointCoords.xy] then
		local packedSlots = {}		
	
		local HerbID = herbID
		local compositeHash = joaat(hash)
	
		local spawnData = Config.Composites[HerbID] and Config.Composites[HerbID].spawn
		if not spawnData then print("Error spawn data ID: " .. HerbID) return end
		
		local SpawnCol = GetSpawnCol(HerbID)	--Возращает кол-во сколько на точке(т.е. одинарные растения или нет)
		local variantMax = GetVariantMax(HerbID)			--кроме 52(Тысячелистник) = 4 все остальное 0
		--local MinCol = GetMinCol(HerbID)		--мин кол-во
		--local MaxCol = GetMaxCol(HerbID)		--мах кол-во
		--local SpawnCol = Config.compositeOptionsSpawn[HerbID].spawnCol
		local MinCol = spawnData.minCol
		local MaxCol = spawnData.maxCol
						
		if SpawnCol ~= 3 then--Это для заполнения всех растений кроме одиночных
			packedSlots = GeneratePackedCompositeSlots(SpawnCol, MinCol, MaxCol, variantMax)
		else--Это для одиночных
			packedSlots = GenerateSinglePackedCompositeSlot(SpawnCol, variantMax)
		end	
		--serverComposite[pointCoords.xy] = { HerbID = HerbID, CompositeHash = compositeHash, PointCoords = pointCoords, PointHeading = pointHeading, PackedSlots = packedSlots }
		--TriggerServerEvent("rsg-composite:server:AddToServerPoint", pointCoords.xy, serverComposite[pointCoords.xy])
		TriggerServerEvent("rsg-composite:server:AddToServerPoint", 
		pointCoords.xy, 
		{
            HerbID = HerbID,
            CompositeHash = compositeHash,
            PointCoords = pointCoords,
            PointHeading = pointHeading,
            PackedSlots = packedSlots
        })
	elseif Composite[pointCoords.xy].PointSpawn == false then
		StartCreateComposite(Composite[pointCoords.xy].HerbID, Composite[pointCoords.xy].CompositeHash, pointCoords, pointHeading, Composite[pointCoords.xy].PackedSlots)
	end
end

function CreatePrompts()
	local str = CreateVarString(10, 'LITERAL_STRING', Config.PromtName)
	PickupPrompt = PromptRegisterBegin()
	PromptSetControlAction(PickupPrompt, joaat("INPUT_LOOT3"))
	PromptSetText(PickupPrompt, str)
	PromptSetEnabled(PickupPrompt, 0)
	PromptSetVisible(PickupPrompt, 0)
	PromptSetHoldMode(PickupPrompt, 350)
	PromptRegisterEnd(PickupPrompt)
	--print("Create Prompt")
	return PickupPrompt
end

function GeneratePackedCompositeSlots(spawnCol, minSlots, maxSlots, variantMax)
    local rotationPool, offsetPool = BuildCompositeRotationPool(spawnCol)
    local slotCount = 0
    local offset = 0
    local variant = 0
	local packedSlots = {}

    if maxSlots > 4 then
        maxSlots = 4
    end
    if minSlots <= 0 then
        minSlots = 1
    end

	slotCount = math.random(minSlots, maxSlots + 1)
    for index = 1, slotCount do
		--проверка на nil почему-то иногда получаем nil и ошибку
		if rotationPool[index] == nil  then
			rotationPool[index] = 0			
			print("ERROR: rotationPool[" .. index .. "] == nil")
        end
		
		if rotationPool[index] == 0 then
            offset = 0			
        else
            offset = offsetPool[math.random(1, 3)]
        end
		
        if variantMax > 0 then
            variant = math.random(0, variantMax)
        else
			variant = 0
		end

		local packedValue = ((rotationPool[index] | (offset << 9)) | (variant << 13)) | 1073741824

		packedSlots[index] = packedValue --заполнили packedSlots
    end
	return packedSlots
end

function GenerateSinglePackedCompositeSlot(spawnCol, variantMax)
	local rotationPool, offsetPool = BuildCompositeRotationPool(spawnCol)
	local variant = 0
	local packedSlots = {}

	if variantMax > 0 then	--тут только тысячелистник 4 - но это для создания одночных функция
		variant = math.random(0, variantMax)
	end

	local packedValue = ((rotationPool[1] | (0 << 9)) | (variant << 13)) | 1073741824

	packedSlots[1] = packedValue --заполнили packedSlots
	return packedSlots
end

function BuildCompositeRotationPool(spawnCol)
    local rotationPool = {}
    local offsetPool = {}

    if spawnCol == 0 then
        offsetPool[1] = 1
        offsetPool[2] = 2
        offsetPool[3] = 3
    elseif spawnCol == 1 then
        offsetPool[1] = 2
        offsetPool[2] = 3
        offsetPool[3] = 4
    elseif spawnCol == 2 then
        offsetPool[1] = 3
        offsetPool[2] = 4
        offsetPool[3] = 5
    elseif spawnCol == 3 then
        offsetPool[1] = 2
        offsetPool[2] = 3
        offsetPool[3] = 4
    else
        offsetPool[1] = 2
        offsetPool[2] = 3
        offsetPool[3] = 4
    end

    rotationPool[1] = 0
    rotationPool[2] = 67
    rotationPool[3] = 139
    rotationPool[4] = 223
    rotationPool[5] = 293
    rotationPool[6] = 359

    local lastIndex = 6
    while lastIndex > 1 do
        local j = math.random(1, lastIndex)--Тут возможно надо + 2
        local tmp = rotationPool[j]
        rotationPool[j] = rotationPool[lastIndex]
        rotationPool[lastIndex] = tmp
        lastIndex = lastIndex - 1
    end
	
    return rotationPool, offsetPool
end

function CreateHerbsCoords(ScenarioPointCoords, packedSlots)
	local herbCoords = {}

    for index = 1, 4 do
        local Offset, Rotation, variant = GetRotationOffset(index, packedSlots)
		
		if packedSlots[index] ~= nil then
			herbCoords[index] = vector3(ScenarioPointCoords.x + ((Offset) * math.cos(math.rad(Rotation))),
				ScenarioPointCoords.y + (Offset * math.sin(Rotation)),
				ScenarioPointCoords.z)
			--print("GeneratedHerbCoords " .. herbCoords[index])
		else
			herbCoords[index] = vector3(0.0, 0.0, 0.0)
		end
    end

    return herbCoords
end

function GetGroundZFor3DCoord(x, y, z)
    if x == 0.0 and y == 0.0 and z == 0.0 then 
		return false
	end
	--local x, y, z = table.unpack(coords)
    local retval, groundz, normal = GetGroundZAndNormalFor_3dCoord(x, y, z)

	if retval then
        return true
    else
        return false
    end
end

function GetRotationOffset(slotIndex, packedSlots)
	local packedValue = packedSlots[slotIndex]
	
	if packedValue == nil then
        return 0, 0, 0
    end
	
	local rotation = packedValue & 511
    local offset   = (packedValue & 3584) >> 9
    local variant  = (packedValue & 57344) >> 13

    return offset, rotation, variant
end

function CreateComposite(index, compositeHash, herbCoords, Heading, HerbID, packedSlots, pointCoords)
    local compositeId = 0
	local vegModifierHandle = 0
	if index <= 4 then		
        if not isVectorEmpty(herbCoords[index]) then
            local onGround = 0
            if HerbID == 1 or HerbID == 9 or HerbID == 10 or HerbID == 17 or HerbID == 21 or HerbID == 25 or HerbID == 32 or HerbID == 36 then
                onGround = 2
				Heading = Heading * 0.01745329
                herbCoords[index] = herbCoords[index] + correctCoords(vector3(0.0, 0.737008, 1.81999), Heading)
            end
            if HerbID == 37 then					
                onGround = 2
				Heading = Heading * 0.01745329
                herbCoords[index] = herbCoords[index] + correctCoords(vector3(0.0, 0.5, 1.81999), Heading)
            end
			if packedSlots[index] ~= nil then
				if packedSlots[index] & 4096 ~= 0 then
					onGround = 1
				end
			end
			if onGround ~= 2 then
				Heading = correctHeading(Heading + (index * math.random(0.0, 90.0)))
			end
            compositeId = exports["rsg-composite"]:NativeCreateComposite(compositeHash, herbCoords[index].x, herbCoords[index].y, herbCoords[index].z, Heading, onGround, -1)

			--если глючный composite - то удаляем его сразу
			if compositeId == -1 then
				NativeDeleteComposite(compositeId)
				print("ERROR: Composite not spawn(check spawnCompositeNum)")
			else
				--получаем все Entitys у композита чтобы потом его можно было найти в ивенте
				--print(compositeId, json.encode(GetHerbCompositeNumEntities(compositeId, 25)))
				
				--print(compositeId, json.encode(GetHerbCompositeNumEntities2(herbCoords[index], 10.0)))
			
				if HerbID == 61 then --для лука
					vegModifierHandle = AddVegModifierSphere(herbCoords[index], 0.35, 2, 314, 0)
				end
				if isMushroom(HerbID) then --для грибов
					vegModifierHandle = AddVegModifierSphere(herbCoords[index], 0.37, 4, 27, 0)
				end
				if HerbID == 38 then --Фиолетовый подснежник
					vegModifierHandle = AddVegModifierSphere(herbCoords[index], 0.15, 4, -1, 0)
				end			
				if index == 1 then
					if isEggs(HerbID) then --для яиц
						vegModifierHandle = AddVegModifierSphere(herbCoords[index], 0.75, 1, 511, 0)
						addEffectAndCheck(pointCoords, HerbID)
						--AttachFXEffect(pointCoords)
					end
					RareHerbs(HerbID, herbCoords[index], pointCoords)
					SPHerbs(HerbID, herbCoords[index], pointCoords)
				end
				spawnCompositeNum = spawnCompositeNum + 1
				return compositeId, vegModifierHandle
			end
        end
    end
end

--Despawn herbs
function deleteComposite(coordsXY, compositeId, vegModifierHandle, entitys)
	--при удалении composite останавливаем звук и удаляем запись.
	--нет composite - нет звука	
	DeleteSound(coordsXY)	
	DeleteEffect(coordsXY)
	
	for i = 1, 4 do
		if compositeId[i] and compositeId[i] ~= 0 then
			NativeDeleteComposite(compositeId[i])
			if compositeId[i] > 0 then
				spawnCompositeNum = spawnCompositeNum - 1
				if spawnCompositeNum < 1 then spawnCompositeNum = 1 end
				--print(spawnCompositeNum)
			end
		end
	end
	for i = 1, 4 do
		if vegModifierHandle[i] and vegModifierHandle[i] ~= 0 then
			RemoveVegModifierSphere(vegModifierHandle[i], 1)
		end
	end
	--удаляем композит от орхидей
	--потому что они состоят из 2 entity
	for _, value in ipairs(entitys) do
		if value then
			--SetEntityAsMissionEntity(value, true, true)
			SetEntityAsNoLongerNeeded(value)
			DeleteEntity(value)
		end
	end
	DeletePromptAndGroup(coordsXY)
	Composite[coordsXY].Entitys = {}
end

function DeleteSound(coordsXY)
	local soundID = PlaySoundCoordsTable[coordsXY]
	if soundID then
		stopSound(soundID)
		PlaySoundCoordsTable[coordsXY] = nil
	end
end

function DeleteEffect(coordsXY)
	local effectID = PlayEffectCoordsTable[coordsXY]
	if effectID and DoesParticleFxLoopedExist(effectID) then
		RemoveParticleFx(effectID, false)
		PlayEffectCoordsTable[coordsXY] = nil
	end
end

function playSound(pointCoords)--звук рядом с коллекционными предметами спавнить когда расстояние меньше 10.0
	--if Citizen.InvokeNative(0xD9130842D7226045, "RDRO_Collectible_Sounds_Travelling_Saleswoman", 0) then
	local i = 1
	while not PrepareSoundset("RDRO_Collectible_Sounds_Travelling_Saleswoman", 0) and i <= 100 do
		i = i + 1
		Wait(0)
	end
	
	local soundID = GetSoundId(Citizen.ResultAsInteger())
	if soundID and soundID > 0 then
		PlaySoundFromPositionWithId(soundID, "collectible_lure", pointCoords, "RDRO_Collectible_Sounds_Travelling_Saleswoman", 0, 0, true)
		PlaySoundCoordsTable[pointCoords.xy] = soundID
	else
		PlaySoundCoordsTable[pointCoords.xy] = nil
	end
end

function stopSound(soundID) --удаляет звук если расстояние больше 10 метров или если сорвали растение
	if soundID and soundID > 0 then
		StopSoundWithName("collectible_lure", "RDRO_Collectible_Sounds_Travelling_Saleswoman")--Any STOP_SOUND_WITH_NAME ( char* audioName, char* audioRef )  //0x0F2A2175734926D8
		ReleaseSoundId(soundID)
	end
	ReleaseSoundset("RDRO_Collectible_Sounds_Travelling_Saleswoman")--void _RELEASE_SOUNDSET ( const char* soundsetName )  //0x531A78D6BF27014B
end

function RareHerbs(HerbID, HerbCoords, pointCoords)
	if Config.Composites[HerbID].spawn.isUnique then
		local foundEntities = CreateVolumeAndGetEntity(HerbCoords, 0.5)
		for _, entity in ipairs(foundEntities) do
			if DoesEntityExist(entity) then
				--if isRareHerbs(HerbID) then
				--if Config.compositeOptionsSpawn[HerbID].isNightHerb then
					Composite[pointCoords.xy].AttachEntity = entity
					if Config.Composites[HerbID].spawn.isUnique then
						EagleEyeSetCustomEntityTint(entity, 255, 255, 0)
					end
				--end
			end
		end
		
		local lastEntity = foundEntities[#foundEntities]
		if lastEntity and DoesEntityExist(lastEntity) then
			if HerbID == 44 then
				Citizen.InvokeNative(0x7563CBCA99253D1A, lastEntity, `BLIP_MP_ROLE_NATURALIST`) --SetBlipIconToLockonEntityPrompt(entity, blipIcon)
			else
				Citizen.InvokeNative(0x7563CBCA99253D1A, lastEntity, `BLIP_MP_ROLE_COLLECTOR_ILO`)
			end
		end
	end
end

CreateThread(function()
    while true do
		Wait(150)
		if playerSpawn then
			local playerPosition = GetEntityCoords(PlayerPedId())
			local scenarios = getLootScenarioHash(playerPosition, 25.0, 100)
			if scenarios and #scenarios > 0 then
				for _, scenarioData in ipairs(scenarios) do
					local HerbID = scenarioData.herbsScenarioPoint.HerbID
					local pointCoords = GetScenarioPointCoords(scenarioData.scenario, true)
					local key = KeyFromCoords(pointCoords.xy)
					--print("pointCoords = " .. json.encode(pointCoords))
					local distance = #(playerPosition.xy - pointCoords.xy)
					if Composite[pointCoords.xy] and not Config.FullLootedScenarioPoint[key] then
						if isSPHerbs(HerbID) then
							if distance <= 2.0 then
								local pickTime = Config.AutoEquipKnife and equipKnife(HerbID) or getPickupTime(HerbID)
								local prompt = Composite[pointCoords.xy].PickupPrompt
								
								PicUpOrchid(pointCoords, prompt, pickTime, HerbID)
							end
						end
						--elseif isRareHerbs(HerbID) or isEggs(HerbID) then
						local herbCfg = Config.Composites[HerbID]
						if herbCfg and herbCfg.spawn and herbCfg.spawn.isUnique and not Config.FullLootedScenarioPoint[key] then
							if distance <= 20.0 and not PlaySoundCoordsTable[pointCoords.xy] then						
								playSound(pointCoords)
							elseif distance > 20.0 and PlaySoundCoordsTable[pointCoords.xy] then
								DeleteSound(pointCoords.xy)
							end					
						end
					--если точка залутана и есть запись со звуком - удаляем звук
					elseif Config.FullLootedScenarioPoint[key] and PlaySoundCoordsTable[pointCoords.xy] then
						DeleteSound(pointCoords.xy)
					end
				end
			end
			--отключение звука при тп.
			for soundPointCoords, soundID in pairs(PlaySoundCoordsTable) do
				if soundID then  -- ✓ Проверяем что soundID существует
					local distance = #(playerPosition.xy - soundPointCoords)
					if distance > 20.0 then
						DeleteSound(soundPointCoords)
					end
				end
			end
		end
    end
end)

function PromptsSetGroup(PickupPrompt, group_Promt)
	if PickupPrompt and PromptIsValid(PickupPrompt) then
		PromptSetEnabled(PickupPrompt, true)
		PromptSetVisible(PickupPrompt, true)
		PromptSetGroup(PickupPrompt, group_Promt)
	end
end

function DeletePromptAndGroup(pointCoords)
	if Composite[pointCoords].PickupPrompt then
		PromptRemoveGroup(Composite[pointCoords].PickupPrompt, Composite[pointCoords].GroupPromt)
		PromptDelete(Composite[pointCoords].PickupPrompt)
		Composite[pointCoords].GroupPromt = nil
		Composite[pointCoords].PickupPrompt = nil		
	end
end

function PicUpOrchid(pointCoords, pickupPrompt, pickTime, herbID)
	--local picking = false
	if isPickUp then return end
	if PromptHasHoldModeCompleted(pickupPrompt) then		
		local PlayerPed = PlayerPedId()
		local comp = Composite[pointCoords.xy]
		if not comp then return end
		local entity = comp.AttachEntity
		if not (entity and DoesEntityExist(entity)) then return end
		isPickUp = true --именно после проверки entity
		--удаляем prompt
		DeletePromptAndGroup(pointCoords.xy)
		
		
		--print("Нажали")
		local picking = true
		
		CreateThread(function()
			while picking do
				Wait(0) -- Продолжаем выполнение других тиков
				local ped = PlayerId()
				-- Отключаем орлиный глаз (может быть и не нужно, если уже отключено выше)
				Citizen.InvokeNative(0x64FF4BF9AF59E139, ped, true) -- _SECONDARY_SPECIAL_ABILITY_SET_DISABLED
				Citizen.InvokeNative(0xC0B21F235C02139C, ped)       -- _SPECIAL_ABILITY_SET_EAGLE_EYE_DISABLED
				
				DisableControlAction(0, `INPUT_SECONDARY_SPECIAL_ABILITY_SECONDARY`, true)
				DisableControlAction(0, `INPUT_SPECIAL_ABILITY`, true)
			end
		end)
		
		local model = GetEntityModel(entity)
		local playerPosition = GetEntityCoords(PlayerPed)
		TaskLootEntity(PlayerPed, entity) --этой командой лутает цветки и т.д.
		--SetModelAsNoLongerNeeded(model)
        --SetEntityAsNoLongerNeeded(entity)
		comp.AttachEntity = nil
		
		local herbType = Config.Composites[herbID].herbNameHash
		if herbType ~= 0 then
			TelemetryHerbPicked(herbType)
			CompendiumHerbPicked(herbType, pointCoords)
		end
		
		Wait(pickTime * 1000) -- чтобы не было повторных нажатий
		ClearPedTasks(PlayerPed)
		ClearPedSecondaryTask(PlayerPed)

		FindPicupCompositeAndCoords(playerPosition, model, true)
		picking = false
		Wait(0)
		EnableControlAction(0, `INPUT_SECONDARY_SPECIAL_ABILITY_SECONDARY`, true)
		EnableControlAction(0, `INPUT_SPECIAL_ABILITY`, true)
		isPickUp = false		
	end	
end

function SPHerbs(HerbID, herbCoords, pointCoords)
	if isSPHerbs(HerbID) then
		local attachEntity = nil
		local foundEntities = CreateVolumeAndGetEntity(herbCoords, 0.5)
		if foundEntities then
			if #foundEntities > 1 then
				for _, entity in ipairs(foundEntities) do
					--BOOL IS_ENTITY_ATTACHED ( Entity entity )  //0xEE6AD63ABF59C0B7
					if IsEntityAttached(entity) then
						attachEntity = entity
					end
				end
			elseif isSPHerbsOneEntities(HerbID) and foundEntities[1] then
				attachEntity = foundEntities[1]
			end

			if DoesEntityExist(attachEntity) then
				Composite[pointCoords.xy].AttachEntity = attachEntity
				Composite[pointCoords.xy].Entitys = foundEntities
				if Config.Composites[HerbID].spawn.isUnique then
					EagleEyeSetCustomEntityTint(attachEntity, 255, 255, 0)
				end
				
				--добавляем наш промпт к SP растению
				local groupPromt = UiPromptGetGroupIdForTargetEntity(attachEntity, Citizen.ResultAsInteger())
				local pickupPrompt = CreatePrompts()
				PromptsSetGroup(pickupPrompt, groupPromt)
				Composite[pointCoords.xy].GroupPromt = groupPromt
				Composite[pointCoords.xy].PickupPrompt = pickupPrompt
			else
				print("ERROR: attachEntity not exist.")
			end
		end
	end
end

function addEffectAndCheck(pointCoords, HerbID)
	local foundEntities = CreateVolumeAndGetEntity(pointCoords, 0.5)
	local is_particle_effect_active = false
    local current_ptfx_handle_id = false
	local player = PlayerId()
		
	if DoesEntityExist(foundEntities[2]) then -- 2 индекс это яйца- их когда собрал то эффект пропадает потому что нет entiti
		Composite[pointCoords.xy].AttachEntity = foundEntities[2]
		if Config.Composites[HerbID].spawn.isUnique then
			EagleEyeSetCustomEntityTint(foundEntities[1], 255, 255, 0)
		end
		
		CreateThread(function()
			while true do
			Wait(100)			
				if Citizen.InvokeNative(0x45AB66D02B601FA7, player) then
                    -- Eagle Eyes : ON
                    if not is_particle_effect_active then
                        if not Citizen.InvokeNative(0x65BB72F29138F5D6, joaat("eagle_eye")) then                         -- HasNamedPtfxAssetLoaded
                            Citizen.InvokeNative(0xF2B2353BBC0D4E8F, joaat("eagle_eye"))                                 -- RequestNamedPtfxAsset
                            local counter = 0
                            while not Citizen.InvokeNative(0x65BB72F29138F5D6, joaat("eagle_eye")) and counter <= 300 do -- while not HasNamedPtfxAssetLoaded
                                Wait(0)
                            end							
                        end
                        if Citizen.InvokeNative(0x65BB72F29138F5D6, joaat("eagle_eye")) then -- HasNamedPtfxAssetLoaded
                            Citizen.InvokeNative(0xA10DB07FC234DD12, "eagle_eye")                 -- UseParticleFxAsset
                            current_ptfx_handle_id = Citizen.InvokeNative(0x8F90AB32E1944BDE, "eagle_eye_clue", foundEntities[2], 0.0, 0.0, 0.35, 0.0, 0.0, 0.0, 0.55, false, false, false) -- StartNetworkedParticleFxLoopedOnEntity
							Citizen.InvokeNative(0x239879FC61C610CC, current_ptfx_handle_id, 255.0, 255.0, 0.0, false) --Color
							PlayEffectCoordsTable[pointCoords.xy] = current_ptfx_handle_id
							is_particle_effect_active = true
                        end
                    end
                else
                    -- Eagle Eyes : OFF
                    if current_ptfx_handle_id then
                        DeleteEffect(pointCoords.xy)
                    end
                    current_ptfx_handle_id = false
                    is_particle_effect_active = false
                end
			end				
		end)	
	end	
end

function CreateVolumeAndGetEntity(herbCoords, scale) --scale = 5.0
	local volumeArea = CreateVolumeSphere(herbCoords.x, herbCoords.y, herbCoords.z, 0.0, 0.0, 0.0, scale, scale, scale) -- _CREATE_VOLUME_SPHERE
	local itemSet = CreateItemset(true)
	local itemCount = GetEntitiesInVolume(volumeArea, itemSet, 3) -- Get volume items into itemset
	local foundEntities = {}
	if itemCount then	
		for index = 0, itemCount - 1 do
			local entity = GetIndexedItemInItemset(index, itemSet)
			--print("entity = " .. entity)
			if IsEntityAnObject(entity) then--IS_ENTITY_AN_OBJECT
				table.insert(foundEntities, entity) -- Добавляем найденный Entity в таблицу
			end
		end	
	end
	ClearItemset(itemSet) -- Empty Item Set
	DestroyItemset(itemSet)
	if DoesVolumeExist(volumeArea) then --BOOL DOES_VOLUME_EXIST ( Volume volume )  //0x92A78D0BEDB332A3
		DeleteVolume(volumeArea) --void _DELETE_VOLUME ( Volume volume )  //0x43F867EF5C463A53
	end
	return foundEntities
end



function isVectorEmpty(herbVector)
	return (herbVector == nil) or (herbVector.x == 0.0 and herbVector.y == 0.0 and herbVector.z == 0.0)
end

function correctCoords(coords, heading)
    local sinYaw = math.sin(heading)
    local cosYaw = math.cos(heading)
    local rotX = (coords.x * cosYaw) - (coords.y * sinYaw)
    local rotY = (coords.x * sinYaw) + (coords.y * cosYaw)

	local correct = vector3(rotX, rotY, coords.z)
    return correct
end

function correctHeading(scenarioPointHeading)
    return (scenarioPointHeading * 0.01745329)
end

--так можно устроить проверку на сорваных растений на точке
function func_79(iParam1)
    return (f_4[iParam1 + 1] & 4096) ~= 0
end
function HasOnGroundFlag(packedSlots, slotIndex)
    return (packedSlots[slotIndex] >> 1) & 4096 > 0
end

function IsControlAlwaysPressed(inputGroup, control)
    return IsControlPressed(inputGroup, control) or IsDisabledControlPressed(inputGroup, control)
end

-- Пытается найти ближайший scenario/слот после лута и применить результат:
-- выдача награды/поедание + очистка слота + отключение точки если пусто.
function FindPicupCompositeAndCoords(pickupCoords, lootedModel, isPickup)
    -- 1) Откуда искать: если на маунте, лучше искать от игрока
    local searchCoords = pickupCoords
	local ped = PlayerPedId()
    if IsPedOnMount(ped) and not IsPedInAnyVehicle(ped) then
        searchCoords = GetEntityCoords(ped)
    end

    -- 2) Пытаемся найти scenario/слот (иногда нужен небольшой “догон” после TaskLootEntity)
    local maxRetries, retryDelayMs = 2, 500
    local nearestScenario, pointCoords, HerbID, slotIndex = nil, nil, nil, nil

    for attempt = 1, (maxRetries + 1) do
        nearestScenario, pointCoords, HerbID, slotIndex = GetNearestScenario(searchCoords, lootedModel)
        if nearestScenario then break end
        if attempt <= maxRetries then Wait(retryDelayMs) end
    end

    if not nearestScenario then
        if Config.Debug then print("FindPicupCompositeAndCoords: nearestScenario not found") end
        return
    end

    if not slotIndex then
        if Config.Debug then print("ERROR: No slotIndex for nearestScenario point") end
        return
    end	

    -- 3) Работаем с записью композита
    local key = pointCoords.xy
    local comp = Composite[key]
    if not comp then
        if Config.Debug then  print("ERROR: Composite record missing for point") end
        return
    end
	
	local nearestCompositeId = Composite[key].CompositeId[slotIndex]

    -- 4) Если уникальные — выключаем эффекты/звуки на точке
    if Config.Composites[HerbID].spawn.isUnique then
        comp.AttachEntity = nil
        DeleteEffect(key)
    end
    if PlaySoundCoordsTable[key] then
        DeleteSound(key)
    end

    -- 5) Серверная логика: pickup vs eat
    local amount = GetHerbPicupAmountID(HerbID)
    if isPickup then
		--мы собрали
        TriggerServerEvent("rsg-composite:server:Gathered", HerbID, amount)
		if Config.Debug then
			print("Мы собрали: HerbID = " .. HerbID .. " compositeIndex = " .. slotIndex .. " nearestCompositeId = " .. nearestCompositeId .. " num = " .. amount)
		end
    else
		--мы съели
        Eating(HerbID)
        TriggerServerEvent("rsg-composite:server:Eating", HerbID)
        if not Config.Composites[HerbID].eat.isPoison then
            PlaySoundFrontend("Core_Full", "Consumption_Sounds", true, 0)
        end
    end
	
	local herbType = Config.Composites[HerbID].herbNameHash
	if herbType ~= 0 then
		TelemetryHerbPicked(herbType)
		CompendiumHerbPicked(herbType, searchCoords)
	end

    -- 6) Помечаем конкретный слот пустым
    comp.HerbCoords[slotIndex] = vector3(0.0, 0.0, 0.0)
	--Citizen.InvokeNative(0x5758B1EE0C3FD4AC, nearestCompositeId, false) --удаляем композит. Только для дебага
	--Composite[pointCoords].HerbCoords[compositeIndex] = {x = 0.0, y = 0.0, z = 0.0}
	--удалять не надо. Они сами деспавнятся когда игрок далеко отойдет
	--иначе кусты пропадаю прямо перед игроком.

    -- 7) Если точка вычищена полностью — отключаем scenario и сохраняем в “вылутанные”
    if not HerbsRemains(key) then
        SetScenarioPointActive(nearestScenario, false)

        Config.FullLootedScenarioPoint[KeyFromCoords(key)] = nearestScenario
        TriggerServerEvent("rsg-composite:serverSaveGatheredPoint", KeyFromCoords(key), nearestScenario)
		if Config.Debug then
			print("No more composite in point. Add record to Config.FullLootedScenarioPoint")
		end
    end
end

function GetNearestScenario(PickUpPlayerCoords, Model)
	local radius = 30.0 --не меньше 15 потому что яйца тогда при отходе не берутся.
	local minDistance = radius
	local scenar = nil
	local pCoords = nil
	local herbId = nil
	local compositeIndex = nil
	local lootHerb = GetHerbIDFromLootedModel(Model)
	local scenarios = getLootScenarioHash(PickUpPlayerCoords, radius, 200)
	local pickupCoords = PickUpPlayerCoords
	
	-- Теперь пройдемся по всем точкам и найдем ближайшую в момент взятия
	for _, scenarioData in ipairs(scenarios) do
		local HerbID = scenarioData.herbsScenarioPoint.HerbID
		if lootHerb == 	HerbID then
			local pointCoords = GetScenarioPointCoords(scenarioData.scenario, true)
			local dist = #(pickupCoords - pointCoords)
			if dist < minDistance then
				minDistance = dist
				scenar = scenarioData.scenario
				pCoords = pointCoords
			end
		end	
	end
	if pCoords then
		herbId = Composite[pCoords.xy].HerbID
		minDistance = radius
		local herbCoords = Composite[pCoords.xy].HerbCoords
		for index, compositeCoords in ipairs(herbCoords) do
			if not isVectorEmpty(herbCoords[index]) then
				local dist = #(pickupCoords - compositeCoords)
				if dist < minDistance then
					minDistance = dist
					compositeIndex = index
				end
			end
		end
		
		return scenar, pCoords, herbId, compositeIndex
	end
	return nil, nil, nil, nil
end

function HerbsRemains(nearestScenarioPointIndex)
	-- Теперь пройдемся по всем координатам растений и найдем ближайшую
	for index = 1, 4 do
		if not isVectorEmpty(Composite[nearestScenarioPointIndex].HerbCoords[index]) then
			return true
		end
	end
	return false
end

function Eating(herbID)
	--local Options = Config.compositeOptionsEat[herbID]
	local Options = Config.Composites[herbID].eat
	if Options then
		local player = PlayerPedId()
		if Options.param then
			local health = GetAttributeValue(Options.param.Health)
			local stamina = GetAttributeValue(Options.param.Stamina)
			local stress = GetAttributeValue(Options.param.Stress)
			local hunger = GetAttributeValue(Options.param.Hunger)
			local thirst = GetAttributeValue(Options.param.Thirst)
			local clean = GetAttributeValue(Options.param.Clean)
			--print("health = " .. health, "stamina = " .. stamina, "stress = " .. stress, "hunger = " .. hunger, "thirst = " .. thirst, "clean = " .. clean)
			ChangePlayerStats(health, stamina, stress, hunger, thirst, clean)
		end

		if Options.isPoison then
			if GetEntityHealth(player) > 0 and IsEntityDead(player) == false then
				PlayAnimScenesVomit()
				--SetPedToRagdoll(PlayerPedId(), 5000, 5000, 0, false, false, false);
			end
		end
	end
end

RegisterNetEvent("rsg-composite:client:Eating", function(herbID, itemName)
    if isBusy then
        return
    else
        isBusy = not isBusy
        SetCurrentPedWeapon(PlayerPedId(), joaat("weapon_unarmed"))
        Wait(100)
        if not IsPedOnMount(PlayerPedId()) and not IsPedInAnyVehicle(PlayerPedId()) then
			local dict = loadAnimDict('mech_inventory@eating@multi_bite@sphere_d8-4_fruit')
            TaskPlayAnim(PlayerPedId(), dict, 'quick_right_hand_throw', 5.0, 5.0, -1, 1, false, false, false)
        end
        Wait(750)        
        Eating(herbID)
		TriggerServerEvent("rsg-composite:server:Eating", herbID)
		TriggerEvent("rsg-inventory:client:ItemBox", RSGCore.Shared.Items[itemName], "remove")
		if not Config.Composites[herbID].eat.isPoison then
			PlaySoundFrontend("Core_Full", "Consumption_Sounds", true, 0)
		end
        ClearPedTasks(PlayerPedId())
        isBusy = not isBusy
    end
end)

function loadAnimDict(dict, anim)
    while not HasAnimDictLoaded(dict) do Wait(0) RequestAnimDict(dict) end
    return dict
end

-- Универсальная функция для получения значения параметра (float)
function GetAttributeValue(attribute)
	if type(attribute) == "table" and attribute.Min and attribute.Max then
		local min = tonumber(attribute.Min)
		local max = tonumber(attribute.Max)

		-- Защита: если случайно Min больше Max, меняем местами
		if min > max then
			min, max = max, min
		end

		-- Возвращаем случайное float-значение в диапазоне
		--return min + math.random() * (max - min) * 1.0--так будет возвращать дробное значение т.е. 1.245
		return math.random(min, max) * 1.0 --так просто float 3.0 или -5.0
	
	elseif type(attribute) == "number" then
		-- Если просто число — возвращаем как float
		return attribute * 1.0
	end

	-- Если ничего не подошло — возвращаем 0.0
	return 0.0
end



--Надо разобраться с чистотой- почему-то то прибавляет то отнимает
function ChangePlayerStats(health, stamina, stress, hunger, thirst, clean)
	local player = PlayerPedId()

	SetPlayerHealth(health)

	if stamina ~= 0 then
		ChangePedStamina(player, stamina)
	end
	if stress ~= 0 then
		TriggerEvent('hud:client:UpdateStress', LocalPlayer.state.stress + stress)
		--TriggerEvent(stress > 0 and 'hud:client:GainStress' or 'hud:client:RelieveStress', math.abs(stress))
	end
	if hunger ~= 0 then
		TriggerEvent('hud:client:UpdateHunger', LocalPlayer.state.hunger + hunger)
		--TriggerServerEvent("RSGCore:Server:SetMetaData", "hunger", RSGCore.Functions.GetPlayerData().metadata["hunger"] + hunger)
	end
	if thirst ~= 0 then
		TriggerEvent('hud:client:UpdateThirst', LocalPlayer.state.thirst + thirst)
		--TriggerServerEvent("RSGCore:Server:SetMetaData", "thirst", RSGCore.Functions.GetPlayerData().metadata["thirst"] + thirst)
	end
	if clean ~= 0 then
		TriggerEvent('hud:client:UpdateCleanliness', LocalPlayer.state.cleanliness + clean)
		--TriggerServerEvent("RSGCore:Server:SetMetaData", "cleanliness", RSGCore.Functions.GetPlayerData().metadata["cleanliness"] + clean)
	end
end

--в общем 600
function SetPlayerHealth(health)
	local player = PlayerPedId()
	local currentHealth = GetEntityHealth(player)
	local ostatok = health
	if health > 0 then --если добавляем жизней
		--если ядро не полное - вначале заполняем ядро
		local healthCore = Citizen.InvokeNative(0x36731AC041289BB1, PlayerPedId(), 0, Citizen.ResultAsInteger()) --если ядро не полное то восполняем вначале ядро
		if healthCore < 100 then
			local currentNeedCore = 100 - healthCore --сколько добавить чтобы ядро наполнилось
			ostatok = ostatok - currentNeedCore --получили остаток от того что пришло
			Citizen.InvokeNative(0xC6258F41D86676E0, player, 0, math.floor(healthCore + currentNeedCore)) --заполнили ядро			
		end
	elseif health < 0 then --если убавляем
		if currentHealth <= math.abs(health) then
			ostatok = currentHealth * -1
		end		
	end
	SetEntityHealth(player, math.floor(currentHealth + ostatok)) --остаток направляем в полоску(можно превышать)
end

--анимация рвоты
function PlayAnimScenesVomit()
	local player = PlayerPedId()
	local animscene = nil
	if IsPedMale(player) and Config.UseArthurVomitAnimSceneForMen then
		animscene = CreateAnimScene("script@story@sal1@ig@sal1_ig12_wake_up@sal1_ig12_wake_up", 0, "Herb_PL", false, true)
		SetAnimSceneEntity(animscene, "ARTHUR", player, 0)		
	else		
		animscene = CreateAnimScene("script@MPSTORY@MP_PoisonHerb@IG@IG1_CommonBullrush@IG1_CommonBullrush", 0, "Herb_PL", false, true)
		if IsPedMale(player) then
			SetAnimSceneEntity(animscene, "MP_Male", player, 0)
		else
			SetAnimSceneEntity(animscene, "MP_Female", player, 0)
		end
	end
	LoadAnimScene(animscene)
	while not Citizen.InvokeNative(0x477122B8D05E7968, animscene, 1, 0) do Wait(10) end --// _IS_ANIM_SCENE_LOADED
	StartAnimScene(animscene)
	while not Citizen.InvokeNative(0xD8254CB2C586412B, animscene, true) do Wait(0) end		
	if Citizen.InvokeNative(0x25557E324489393C, animscene) then --//DOES_ANIM_SCENE_EXIST
		Citizen.InvokeNative(0x84EEDB2C6E650000, animscene) --// _DELETE_ANIM_SCENE
	end
end

function isMushroom(HerbID)
    if HerbID == 4 or HerbID == 8 or HerbID == 28 or HerbID == 31 then
        return true
    end
    return false
end

function isEggs(HerbID)
    if HerbID == 54 or HerbID == 55 or HerbID == 56 or HerbID == 57 or HerbID == 58 or HerbID == 59 or HerbID == 60 then
        return true
    end
    return false
end

function isRareHerbs(HerbID)
	if (HerbID == 45 or HerbID == 47 or HerbID == 48 or HerbID == 46 or HerbID == 49 or HerbID == 50 or HerbID == 51 or HerbID == 52 or HerbID == 53 or HerbID == 44) then
		return true
	end
	return false
end

function isSPHerbs(HerbID)
	if (HerbID == 1 or HerbID == 9 or HerbID == 10 or HerbID == 14 or HerbID == 17 or HerbID == 21 or HerbID == 22 or HerbID == 24 or HerbID == 25 or HerbID == 30 or HerbID == 32 or HerbID == 35 or HerbID == 36) then
		return true
	end
	return false
end

function isSPHerbsOneEntities(HerbID)
	if HerbID == 1 or HerbID == 9 or HerbID == 25 or HerbID == 32 or HerbID == 14 or HerbID == 24 or HerbID == 22 or HerbID == 30 or HerbID == 35 then
		return true
	end

	return false
end

--[[function CheckKnife()
	if RSGCore.Functions.HasItem('weapon_melee_knife', 1) then			
		Citizen.InvokeNative(0x5E3BDDBCB83F3D84, PlayerPedId(), joaat('weapon_melee_knife'), 0, false, true)
	else	
		TriggerServerEvent("rsg-composite:server:SendMessage", 'Купите нож', 'Вам нужно купить или создать нож!')
	end
end
--]]
function equipKnife(HerbID)
	if HerbID == 14 or HerbID == 24 or HerbID == 22 or HerbID == 30 or HerbID == 35 then
		Citizen.InvokeNative(0x5E3BDDBCB83F3D84, PlayerPedId(), joaat('weapon_melee_knife'), 0, false, true)
		return 12
	end
	return 9
end

function getPickupTime(HerbID)
	if HerbID == 14 or HerbID == 24 or HerbID == 22 or HerbID == 30 or HerbID == 35 then
		return 12
	end
	return 9
end

function GetSpawnCol(HerbID)
    if HerbID == 4 or HerbID == 6 or HerbID == 7 or HerbID == 8 or HerbID == 11 or HerbID == 12 or HerbID == 13 or HerbID == 15 or HerbID == 18 or HerbID == 19 or HerbID == 20 or HerbID == 23 or HerbID == 26 or HerbID == 27 or HerbID == 28 or HerbID == 29 or HerbID == 31 or HerbID == 34 or HerbID == 38 or HerbID == 39 or HerbID == 40 or HerbID == 41 or HerbID == 43     or HerbID == 61 or HerbID == 62 then
        return 0
    elseif HerbID == 5 or HerbID == 16 or HerbID == 33 or HerbID == 42 then
        return 1
    elseif HerbID == 2 or HerbID == 3 or HerbID == 37 or HerbID == 1 or HerbID == 9 or HerbID == 10 or HerbID == 14 or HerbID == 17 or HerbID == 21 or HerbID == 22 or HerbID == 24 or HerbID == 25 or HerbID == 30 or HerbID == 32 or HerbID == 35 or HerbID == 36 or HerbID == 44 or HerbID == 45 or HerbID == 46 or HerbID == 47 or HerbID == 48 or HerbID == 49 or HerbID == 50 or HerbID == 51 or HerbID == 52 or HerbID == 53
			 or HerbID == 54 or HerbID == 55 or HerbID == 56 or HerbID == 57 or HerbID == 58 or HerbID == 59 or HerbID == 60 then
        return 3
    else
        return -1
    end
end

function GetVariantMax(HerbID)
    if HerbID == 43 then
        return 4
    else
        return 0
    end
end
--[[
function GetMinCol(HerbID)
    if HerbID == 2 or HerbID == 3 or HerbID == 5 or HerbID == 16 or HerbID == 33 or HerbID == 37 or HerbID == 42 or HerbID == 1 or HerbID == 9 or HerbID == 10 or HerbID == 14 or HerbID == 17 or HerbID == 21 or HerbID == 22 or HerbID == 24 or HerbID == 25 or HerbID == 30 or HerbID == 32 or HerbID == 35 or HerbID == 36 or HerbID == 44 or HerbID == 45 or HerbID == 46 or HerbID == 47 or HerbID == 48 or HerbID == 49 or HerbID == 50 or HerbID == 51 or HerbID == 52 or HerbID == 53 
	  or HerbID == 54 or HerbID == 55 or HerbID == 56 or HerbID == 57 or HerbID == 58 or HerbID == 59 or HerbID == 60 then
        return 1
    elseif HerbID == 4 or HerbID == 6 or HerbID == 7 or HerbID == 8 or HerbID == 13 or HerbID == 15 or HerbID == 18 or HerbID == 19 or HerbID == 20 or HerbID == 23 or HerbID == 26 or HerbID == 28 or HerbID == 29 or HerbID == 31 or HerbID == 34 or HerbID == 38 or HerbID == 39 or HerbID == 40 or HerbID == 43 or HerbID == 27 or HerbID == 41    or HerbID == 61 or HerbID == 62then
        return 2
    elseif HerbID == 11 or HerbID == 12 then
        return 3
    else
        return 0
    end
end

function GetMaxCol(HerbID)
    if HerbID == 2 or HerbID == 3 or HerbID == 1 or HerbID == 9 or HerbID == 10 or HerbID == 14 or HerbID == 17 or HerbID == 21 or HerbID == 22 or HerbID == 24 or HerbID == 25 or HerbID == 30 or HerbID == 32 or HerbID == 35 or HerbID == 36 or HerbID == 37 or HerbID == 44 or HerbID == 45 or HerbID == 46 or HerbID == 47 or HerbID == 48 or HerbID == 49 or HerbID == 50 or HerbID == 51 or HerbID == 52 or HerbID == 53 or HerbID == 33 or HerbID == 16 or HerbID == 5
		 or HerbID == 54  or HerbID == 55  or HerbID == 56  or HerbID == 57  or HerbID == 58  or HerbID == 59  or HerbID == 60 then
        return 1
    elseif HerbID == 42 or HerbID == 7  or HerbID == 13 or HerbID == 18 or HerbID == 26 then
        return 2
    elseif HerbID == 6 or HerbID == 15 or HerbID == 19 or HerbID == 20 or HerbID == 23 or HerbID == 29 or HerbID == 34 or HerbID == 38 or HerbID == 39 or HerbID == 40 or HerbID == 43 or HerbID == 27 or HerbID == 41  or HerbID == 61 or HerbID == 62 then
        return 3
    elseif HerbID == 4 or HerbID == 8 or HerbID == 11 or HerbID == 12 or HerbID == 28 or HerbID == 31 then
        return 4
    else
        return 0
    end
end
--]]
function GetHerbIDFromLootedModel(Model)
	if Model == -1194833913 then
        return 2
    elseif Model == -781771732 then
        return 3
    elseif Model == -1202590500 then
        return 4
    elseif Model == -550091683 then
        return 5
    elseif Model == -190820666 then
        return 6
    elseif Model == 63835692 then
        return 7
    elseif Model == -1524011012 then
        return 8
    elseif Model == -1291682103 then
        return 11
    elseif Model == 2129486088 then
        return 12
    elseif Model == 1640283709 then
        return 13
    elseif Model == -177017064 then
        return 15
    elseif Model == -231430744 then
        return 16
    elseif Model == -1298766667 then
        return 18
    elseif Model == 68963282 then
        return 19
    elseif Model == 316930447 then
        return 20
    elseif Model == -1944784826 then
        return 23
    elseif Model == 454655011 then
        return 26
    elseif Model == 2033030310 then
        return 27
    elseif Model == 926616681 then
        return 28
    elseif Model == -423117050 then
        return 29
    elseif Model == 76556053 then
        return 31
    elseif Model == -1326233925 then
        return 33
    elseif Model == -1333051172 then
        return 34
    elseif Model == 1195604412 then
        return 37
    elseif Model == -1019761233 then
        return 38
    elseif Model == -780853522 then
        return 39
    elseif Model == 561391114 then
        return 40
    elseif Model == -351933124 then
        return 41
    elseif Model == 1057523711 then
        return 42
    elseif Model == 918835244 then
        return 43
    elseif Model == 2614345 then
        return 1
    elseif Model == -261261261 then
        return 9
    elseif Model == -119284366 then
        return 10
    elseif Model == -1526591198 then
        return 14
    elseif Model == 1850987651 then
        return 17
    elseif Model == 1893326554 then
        return 21
    elseif Model == 1189919405 then
        return 22
    elseif Model == 162932774 then
        return 24
    elseif Model == 651870162 then
        return 25
    elseif Model == 1814628154 then
        return 30
    elseif Model == 1924479630 then
        return 32
    elseif Model == -1258958223 then
        return 35
    elseif Model == 1830174769 then
        return 36
		
	elseif Model == -317883624 then
        return 44
	elseif Model == -834461873 then
        return 45
	elseif Model == -2015527411 then
        return 46
	elseif Model == -1697318509 then
        return 47
	elseif Model == -1490607613 then
        return 48
	elseif Model == 1175863601 then
        return 49
	elseif Model == 988637426 then
        return 50
	elseif Model == -1964504874 then
        return 51
	elseif Model == -2029085880 then
        return 52
	elseif Model == -204942356 then
        return 53
		
	elseif Model == -1214246086 then
        return 54
	elseif Model == -1214246086 then
        return 55
	elseif Model == -1214246086 then
        return 56
	elseif Model == 420299933 then
        return 57
	elseif Model == -1824227939 then
        return 58
	elseif Model == -235579763 then
        return 59
	elseif Model == -1327505904 then
        return 60

	elseif Model == 428150654 then
        return 61
	
    else
        return 0
    end
end

function GetHerbPicupAmountID(HerbID)
	local data = Config.Composites[HerbID]
	if data and data.pickupAmount then
		return data.pickupAmount
	else
		return 1
	end
end

function RequestAndWaitForComposite(compositeHash)
    Citizen.InvokeNative(0x73F0D0327BFA0812, compositeHash)  -- request COMPOSITE
	
    local i = 1
    while not Citizen.InvokeNative(0x5E5D96BE25E9DF68,compositeHash) and i < 500 do  -- has COMPOSITE loaded
        i = i + 1
        Wait(0)
    end
end

function AreCompositeLootableEntityDefAssetsLoaded(compositeHash)
	return Citizen.InvokeNative(0x5E5D96BE25E9DF68, compositeHash)
end

function RequestHerbCompositeAsset(compositeHash)
	return Citizen.InvokeNative(0x73F0D0327BFA0812, asset, Citizen.ResultAsInteger())
end

function NativeDisplayCompositePickuptThisFrame(composite, display)
    Citizen.InvokeNative(0x40D72189F46D2E15, composite, display)
	--TriggerServerEvent('rsg-composite:server:Gathered')
end

function EagleEyeSetCustomEntityTint(entity, red, green, blue)
	return Citizen.InvokeNative(0x62ED71E133B6C9F1, entity, red, green, blue)
end

function AddVegModifierSphere(coords, radius, modType, flags, p6)
    return Citizen.InvokeNative(0xFA50F79257745E74, coords, radius, modType, flags, p6)
end

function RemoveVegModifierSphere(vegModifierHandle, p1)
	Citizen.InvokeNative(0x9CF1836C03FB67A2, Citizen.PointerValueIntInitialized(vegModifierHandle), p1)
end

function NativeDeleteComposite(compositeId)
    Citizen.InvokeNative(0x5758B1EE0C3FD4AC, compositeId, false)
end

function DumpTable(tbl)
    for k, v in pairs(tbl) do
        print(k, v)
    end
end

--При перезагрузке очищает все что вносили в таблицу
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
		ResetComposites()
	end
)


function ResetComposites()
	for key, value in pairs(Composite) do
		for _, data in ipairs(value.CompositeId) do
			Citizen.InvokeNative(0x5758B1EE0C3FD4AC, data, 0) -- Удалить composite
		end
		for _, data in ipairs(value.VegModifierHandle) do
			RemoveVegModifierSphere(data, 1) -- Удалить сферу которая удаляет растения и т.д. вокруг композита
		end
		if value.Entitys then
			for _, data in ipairs(value.Entitys) do
				SetEntityAsMissionEntity(data, true, true)
				DeleteEntity(data)
			end
			Composite[key].AttachEntity = nil
		end
		DeleteSound(key)
		DeleteEffect(key)
		DeletePromptAndGroup(key)
		Composite[key] = nil		
	end
	for key, scenario in pairs(Config.FullLootedScenarioPoint) do
		SetScenarioPointActive(scenario, true)
		Config.FullLootedScenarioPoint[key] = nil
	end
	ClearPedTasksImmediately(ped, true, true)
	PromptDelete(PickupPrompt)
	CompositePointCol = 1
end

RegisterNetEvent("rsg-composite:client:GetServerComposite")
AddEventHandler("rsg-composite:client:GetServerComposite", function(key, compositeTable)
	StartCreateComposite(compositeTable.HerbID, compositeTable.CompositeHash, compositeTable.PointCoords, compositeTable.PointHeading, compositeTable.PackedSlots)
end)



AddEventHandler('RSGCore:Client:OnPlayerLoaded', function()	
	Wait(1000)
	playerSpawn = true
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload')
AddEventHandler('RSGCore:Client:OnPlayerUnload', function()
    playerSpawn = false
	ResetComposites()
end)


function KeyFromCoords(vec)
    return string.format("%.3f:%.3f", vec.x, vec.y)
end

--[[
function GetHerbCompositeNumEntities(compositeId, searchNum)
	local struct = DataView.ArrayBuffer(256)
	struct:SetInt32(0, searchNum) --указываем какое количество ENTITIES искать (5 хватает)
	local Entitys = {}
	local Entities2 = {}
	local num = Citizen.InvokeNative(0x96C6ED22FB742C3E, compositeId, struct:Buffer(), Citizen.ResultAsInteger())
	if num > 0 then
        -- Перебираем каждый блок данных с шагом 8
        for i = 1, num + 1 do
            local value = struct:GetInt32(i * 8)  -- Индексы: 8, 16, 24, 32, 40
            if value > 0 then
				table.insert(Entitys, value)
				local attEnt = GetEntityAttachedTo(value)
				if attEnt then
					table.insert(Entities2, attEnt)
				end
            end
        end
    end
	if Config.Debug then
		print("Entities2 = " .. json.encode(Entities2))
	end
	return Entitys
end

function GetHerbCompositeNumEntities2(herbCoords, scale)
	local volumeArea = Citizen.InvokeNative(0xB3FB80A32BAE3065, herbCoords.x, herbCoords.y, herbCoords.z, 0.0, 0.0, 0.0, scale, scale, scale) -- _CREATE_VOLUME_SPHERE
	--local volumeArea = Citizen.InvokeNative(0xB3FB80A32BAE3065, herbCoords.x, herbCoords.y, herbCoords.z, 0.0, 0.0, 0.0, scale, scale, scale)
	local itemSet = CreateItemset(1)
	local itemCount = Citizen.InvokeNative(0x886171A12F400B89, volumeArea, itemSet, 3) -- Get volume items into itemset
	local foundEntities = {}
	--print("itemCount" .. itemCount)
	if itemCount then	
		for index = 0, itemCount do
			local entity = GetIndexedItemInItemset(index, itemSet)
			--print("entity = " .. entity)
			--if Citizen.InvokeNative(0x0A27A546A375FDEF, entity) then--IS_ENTITY_AN_OBJECT
				table.insert(foundEntities, entity) -- Добавляем найденный Entity в таблицу
			--end
		end	
	end
	Citizen.InvokeNative(0x20A4BF0E09BEE146, itemSet) -- Empty Item Set
	DestroyItemset(itemSet)
	if Citizen.InvokeNative(0x92A78D0BEDB332A3, volumeArea) then --BOOL DOES_VOLUME_EXIST ( Volume volume )  //0x92A78D0BEDB332A3
		Citizen.InvokeNative(0x43F867EF5C463A53, volumeArea) --void _DELETE_VOLUME ( Volume volume )  //0x43F867EF5C463A53
	end
	return foundEntities
end

function GetHerbCompositeNumEntities3(scale)
	local playerPosition = GetEntityCoords(PlayerPedId())
	local volumeArea = Citizen.InvokeNative(0xB3FB80A32BAE3065, playerPosition.x, playerPosition.y, playerPosition.z, 0.0, 0.0, 0.0, scale, scale, scale) -- _CREATE_VOLUME_SPHERE
	--local volumeArea = Citizen.InvokeNative(0xB3FB80A32BAE3065, herbCoords.x, herbCoords.y, herbCoords.z, 0.0, 0.0, 0.0, scale, scale, scale)
	local itemSet = CreateItemset(1)
	local itemCount = Citizen.InvokeNative(0x886171A12F400B89, volumeArea, itemSet, 3) -- Get volume items into itemset
	local foundEntities = {}
	--print("itemCount" .. itemCount)
	if itemCount then	
		for index = 0, itemCount do
			local entity = GetIndexedItemInItemset(index, itemSet)
			--print("entity = " .. entity)
			--if Citizen.InvokeNative(0x0A27A546A375FDEF, entity) then--IS_ENTITY_AN_OBJECT
				table.insert(foundEntities, entity) -- Добавляем найденный Entity в таблицу
			--end
		end	
	end
	Citizen.InvokeNative(0x20A4BF0E09BEE146, itemSet) -- Empty Item Set
	DestroyItemset(itemSet)
	if Citizen.InvokeNative(0x92A78D0BEDB332A3, volumeArea) then --BOOL DOES_VOLUME_EXIST ( Volume volume )  //0x92A78D0BEDB332A3
		Citizen.InvokeNative(0x43F867EF5C463A53, volumeArea) --void _DELETE_VOLUME ( Volume volume )  //0x43F867EF5C463A53
	end
	return foundEntities
end
--]]

--------------------------------------------------------------------------------
-------------------------------------NOTIFY-------------------------------------
--------------------------------------------------------------------------------
RegisterNetEvent('rsg-composite:client:UIFeedPostSampleToastRight')
AddEventHandler('rsg-composite:client:UIFeedPostSampleToastRight', function(text, dict, icon, text_color, duration, quality, pick)
    local _dict = dict
    local _icon = icon
    if not LoadTexture(_dict) then
        _dict = "generic_textures"
        LoadTexture(_dict)
        _icon = "tick"
    end
    UIFeedPostSampleToastRight(tostring(text), tostring(_dict), tostring(_icon), tostring(text_color), tonumber(duration), tonumber(quality), tonumber(pick))
end)

function UIFeedPostSampleToastRight(_text, _dict, icon, text_color, duration, quality, pick)
    local text = CreateVarString(10, "LITERAL_STRING", _text)
    local dict = CreateVarString(10, "LITERAL_STRING", _dict)
	local sdict = CreateVarString(10, "LITERAL_STRING", "Transaction_Feed_Sounds")
	local sound = CreateVarString(10, "LITERAL_STRING", "Transaction_Positive")
	if pick == 0 then
		sdict = CreateVarString(10, "LITERAL_STRING", "Transaction_Feed_Sounds")
		sound = CreateVarString(10, "LITERAL_STRING", "Transaction_Negative")
	end

    local struct1 = DataView.ArrayBuffer(8*7)
    struct1:SetInt32(8*0,duration)
    struct1:SetInt64(8*1,bigInt(sdict))
    struct1:SetInt64(8*2,bigInt(sound))

    local struct2 = DataView.ArrayBuffer(8*10)
    struct2:SetInt64(8*1,bigInt(text))
    struct2:SetInt64(8*2,bigInt(dict))
    struct2:SetInt64(8*3,bigInt(joaat(icon)))
	--struct2:SetInt64(8*4,bigInt(0))
    struct2:SetInt64(8*5,bigInt(joaat(text_color or "COLOR_WHITE")))
    struct2:SetInt32(8*6,quality or 0)

    Citizen.InvokeNative(0xB249EBCB30DD88E0,struct1:Buffer(),struct2:Buffer(),1)
end

function LoadTexture(dict)
    if Citizen.InvokeNative(0x7332461FC59EB7EC, dict) then
        RequestStreamedTextureDict(dict, true)
        while not HasStreamedTextureDictLoaded(dict) do
            Wait(1)
        end
        return true
    else
        return false
    end
end

function bigInt(text)
    local string1 =  DataView.ArrayBuffer(16)
    string1:SetInt64(0,text)
    return string1:GetInt64(0)
end
--------------------------------------------------------------------------------
-------------------------------------NOTIFY-------------------------------------
--------------------------------------------------------------------------------