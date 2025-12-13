local RSGCore = exports['rsg-core']:GetCoreObject()

local playerSpawn = false
local Composite = {}
--local FullLootedScenarioPoint = {}
local deleteDistance = 2900.0
local CompositePointCol = 1
local PlaySoundCoords = {}
local PlayEffectCoords = {}
local MaxRecordInTable = 500 --на самом деле 500 точек держится в таблице.
local isBusy = false

local spawnCompositeNum = 1 --на случай если слишком много заспавнено и не очистилось

function checkRecordAndClear(playerPosition)
	if CompositePointCol > MaxRecordInTable then		
		for key, value in pairs(Composite) do
			local dist = #(playerPosition.xy - key)
			if dist >= deleteDistance then --должна быть больше чем радиус спавна и радиус скрытия заспавненых которые в таблице
				--print("Delete point = " .. key)
				deleteComposite(key, value.CompositeId, value.VegModifierHandle, value.Entitys)
				Composite[key] = nil
				CompositePointCol = CompositePointCol - 1
				if CompositePointCol < 1 then
					CompositePointCol = 1
				end
			end
		end
	else
		for key, value in pairs(Composite) do
			local dist = #(playerPosition.xy - key)--150.0
			if dist >= 150.0 and value.PointSpawn then --должна быть больше чем радиус спавна и и меньше чем радиус для удаления из таблицы
				deleteComposite(key, value.CompositeId, value.VegModifierHandle, value.Entitys)
				--проверяем если еще есть composite на точке не собранные- то просто обнуляем
				--а если все собрали то удаляем запись
				if not HerbsRemains(key) then
					Composite[key] = nil--убираем запись.
					print("No more composite in point. Delete record in Composite")
				else				
					Composite[key].CompositeId = {}
					Composite[key].VegModifierHandle = {}
					Composite[key].PointSpawn = false
					--print("Despawn point = " .. key)
				end
			end
		end
	end
	--Экстренный деспавн если слишком много заспавненых composite
	--максимум можно показать сразу 180 composite
	if spawnCompositeNum > 160 then
		for key, value in pairs(Composite) do
			local dist = #(playerPosition.xy - key)
			if dist >= 625.0 then --должна быть больше чем радиус спавна и и меньше чем радиус для удаления из таблицы
				print("Emergency Despawn point = " .. key)
				deleteComposite(key, value.CompositeId, value.VegModifierHandle, value.Entitys)
				Composite[key].CompositeId = {}
				Composite[key].VegModifierHandle = {}
				Composite[key].PointSpawn = false
			end
		end
	end
end

function StartEmergencyClear()
	for key, value in pairs(Composite) do
		if Composite[key].PointSpawn then --должна быть больше чем радиус спавна и и меньше чем радиус для удаления из таблицы
			--print("Emergency Despawn point = " .. key)
			deleteComposite(key, value.CompositeId, value.VegModifierHandle, value.Entitys)
			Composite[key].CompositeId = {}
			Composite[key].VegModifierHandle = {}
			Composite[key].PointSpawn = false
		end
	end
end

function DeactivatePoints(scenario)
	SetScenarioPointActive(scenario, false)
end

function StartCreateComposite(sHerbID, sCompositeHash, sPointCoords, sHeading, sF_4)
	local playerPosition = GetEntityCoords(PlayerPedId())
	local pointCoords = sPointCoords
	local herbCoords = {}
	local SpawnCol = 0
	local haveRecord = false
	local HerbID = sHerbID
	local compositeHash = sCompositeHash	
	local f_4 = sF_4	
	
	--если уже точка собрана ничего не делаем.
	if Config.FullLootedScenarioPoint[pointCoords.xy] then
		local scenario = Config.FullLootedScenarioPoint[pointCoords.xy]
		if IsScenarioPointActive(scenario) then
			SetScenarioPointActive(scenario, false)
		end
		return
	end	
	-- Если записи нет в Composite, создаем её
	if not Composite[pointCoords.xy] then
		Composite[pointCoords.xy] = {HerbID = HerbID, CompositeHash = compositeHash,
            PointSpawn = false, CompositeId = {}, F_4 = f_4, HerbCoords = {},
            VegModifierHandle = {}, AttachEntity = nil, Entitys = {}, GroupPromt = nil, PickupPrompt = nil
        }
		haveRecord = false
	else
		HerbID = Composite[pointCoords.xy].HerbID
		compositeHash = Composite[pointCoords.xy].CompositeHash
		f_4 = Composite[pointCoords.xy].F_4
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
		herbCoords = CreateHerbsCoords(pointCoords, f_4)
		Composite[pointCoords.xy].HerbCoords = herbCoords
		spawnCompositeEntities(compositeHash, herbCoords, sHeading, HerbID, f_4, pointCoords)
	elseif HerbID ~= 0 and haveRecord == true and Composite[pointCoords.xy].PointSpawn == false then--проверка на заспавненую точку
		--print("Second Spawn")
		-- Повторный спаун
		spawnCompositeEntities(compositeHash, herbCoords, sHeading, HerbID, f_4, pointCoords)
	elseif HerbID == 0 or HerbID == nil then
		print("No HerbID for " .. compositeHash)
	elseif HerbHash == 0 then
		return
	end	
end

-- Функция для спауна композитных объектов
function spawnCompositeEntities(compositeHash, herbCoords, sHeading, HerbID, f_4, pointCoords)
    for index = 1, 4 do
        if f_4[index] ~= nil then
            RequestAndWaitForComposite(compositeHash)
            if AreCompositeLootableEntityDefAssetsLoaded(compositeHash) then
                local compositeId, vegModifierHandle = CreateComposite(index, compositeHash, herbCoords, sHeading, HerbID, f_4, pointCoords)
                if compositeId and compositeId > 0 then
                    Composite[pointCoords.xy].CompositeId[index] = compositeId
                    Composite[pointCoords.xy].VegModifierHandle[index] = vegModifierHandle
                    Composite[pointCoords.xy].PointSpawn = true
                end
            end
        end
    end
    CompositePointCol = CompositePointCol + 1
end



function CreateServerComposite(herbID, hash, pointCoords, pointHeading)
	local serverComposite = {}
	if not Composite[pointCoords.xy] then
		local f_4 = {}		
	
		local HerbID = herbID
		local compositeHash = joaat(hash)
	
		local spawnData = Config.Composites[HerbID] and Config.Composites[HerbID].spawn
		if not spawnData then print("Error spawn data ID: " .. HerbID) return end
		
		local SpawnCol = GetSpawnCol(HerbID)	--Возращает кол-во сколько на точке(т.е. одинарные растения или нет)
		local Unk1 = GetUnk1(HerbID)			--кроме 52(Тысячелистник) = 4 все остальное 0
		--local MinCol = GetMinCol(HerbID)		--мин кол-во
		--local MaxCol = GetMaxCol(HerbID)		--мах кол-во
		--local SpawnCol = Config.compositeOptionsSpawn[HerbID].spawnCol
		local MinCol = spawnData.minCol
		local MaxCol = spawnData.maxCol
						
		if SpawnCol ~= 3 then--Это для заполнения всех растений кроме одиночных
			f_4 = func_8(SpawnCol, MinCol, MaxCol, Unk1)
		else--Это для одиночных
			f_4 = func_9(SpawnCol, Unk1)
		end	
		serverComposite[pointCoords.xy] = { HerbID = HerbID, CompositeHash = compositeHash, PointCoords = pointCoords, PointHeading = pointHeading, F_4 = f_4 }
		TriggerServerEvent("rsg-composite:server:AddToServerPoint", pointCoords.xy, serverComposite[pointCoords.xy])
	elseif Composite[pointCoords.xy].PointSpawn == false then
		StartCreateComposite(Composite[pointCoords.xy].HerbID, Composite[pointCoords.xy].CompositeHash, pointCoords, pointHeading, Composite[pointCoords.xy].F_4)
	end
end





function CreatePrompts()
	local str = CreateVarString(10, 'LITERAL_STRING', 'Взять')
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

function func_8(SpawnCol, MinCol, MaxCol, Unk1)
    local uParam1, uParam2 = func_50(SpawnCol)
    local iVar11 = 0
    local iVar13 = 0
    local iVar14 = 0
	local f_4 = {}

    if MaxCol > 4 then
        MaxCol = 4
    end
    if MinCol <= 0 then
        MinCol = 1
    end

	iVar11 = math.random(MinCol, MaxCol + 1)
    for index = 1, iVar11 do
        if uParam1[index] == 0 or uParam1[index] == nil then
            iVar13 = 0			
        else
            iVar13 = uParam2[math.random(1, 3)]
        end
		--проверка на nil почему-то иногда получаем nil и ошибку
		if uParam1[index] == nil  then
			DumpTable(uParam1)
			uParam1[index] = 0			
			print("ERROR: uParam1[" .. index .. "] == nil")
        end
        if Unk1 > 0 then
            iVar14 = math.random(0, Unk1)
        end

		local iVar15 = ((uParam1[index] | (iVar13 << 9)) | (iVar14 << 13)) | 1073741824

		f_4[index] = iVar15 --заполнили f_4
    end
	return f_4
end

function func_9(SpawnCol, Unk1)
	local uParam1, uParam2 = func_50(SpawnCol)
	local iVar11 = 0
	local f_4 = {}

	if Unk1 > 0 then	--тут только тысячелистник 4 - но это для создания одночных функция
		iVar11 = math.random(0, Unk1)
	end

	local iVar12 = ((uParam1[1] | (0 << 9)) | (iVar11 << 13)) | 1073741824

	f_4[1] = iVar12 --заполнили f_4
	return f_4
end

function func_50(SpawnCol)
    local uParam1 = {}
    local uParam2 = {}

    if SpawnCol == 0 then
        uParam2[1] = 1
        uParam2[2] = 2
        uParam2[3] = 3
    elseif SpawnCol == 1 then
        uParam2[1] = 2
        uParam2[2] = 3
        uParam2[3] = 4
    elseif SpawnCol == 2 then
        uParam2[1] = 3
        uParam2[2] = 4
        uParam2[3] = 5
    elseif SpawnCol == 3 then
        uParam2[1] = 2
        uParam2[2] = 3
        uParam2[3] = 4
    else
        uParam2[1] = 2
        uParam2[2] = 3
        uParam2[3] = 4
    end

    uParam1[1] = 0
    uParam1[2] = 67
    uParam1[3] = 139
    uParam1[4] = 223
    uParam1[5] = 293
    uParam1[6] = 359

    local iVar0 = 6
    while iVar0 > 1 do
        local iVar1 = math.random(1, iVar0)--Тут возможно надо + 2
        local uVar2 = uParam1[iVar1]
        uParam1[iVar1] = uParam1[iVar0]
        uParam1[iVar0] = uVar2
        iVar0 = iVar0 - 1
    end
	
    return uParam1, uParam2
end

function CreateHerbsCoords(ScenarioPointCoords, f_4)
	local herbCoords = {}

    for index = 1, 4 do
        local Offset, Rotation, uVar3 = GetRotationOffset(index, f_4)
		
		if f_4[index] ~= nil then
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

function GetRotationOffset(index, f_4)
	local Rotation = 0
	local Offset = 0
	local uVar3 = 0

	if f_4[index] ~= nil then
		local Rotation = f_4[index] & 511
		local Offset = (f_4[index] & 3584) >> 9
		local uVar3 = (f_4[index] & 57344) >> 13
		--print("f_4[index]=" .. f_4[index], "Offset=" .. Offset, "Rotation=" .. Rotation, "uVar3=" .. uVar3)
		return Offset, Rotation, uVar3
	end
end

--function CreateComposite(uParam0, scenarioPointHeading)
function CreateComposite(index, compositeHash, herbCoords, Heading, HerbID, f_4, pointCoords)
    local compositeId = 0
	local vegModifierHandle = 0
	if index <= 4 then		
        if not VectorEmpty(herbCoords[index]) then
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
			if f_4[index] ~= nil then
				if f_4[index] & 4096 ~= 0 then
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
	
	--if compositeId > 0 then
	--	spawnCompositeNum = spawnCompositeNum + 1
	--	return compositeId, vegModifierHandle
	--elseif compositeId == -1 then
	--	--запускаем экстренную очистку
	--	StartEmergencyClear()
	--end
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
		if vegModifierHandle[i] and vegModifierHandle[i] > 0 then
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
	for key, value in pairs(PlaySoundCoords) do		
		if key.xy == coordsXY then
			stopSound(PlaySoundCoords[key])
			PlaySoundCoords[key] = nil
		end
	end
end

function DeleteEffect(coordsXY)
	for key, value in pairs(PlayEffectCoords) do		
		if key == coordsXY and PlayEffectCoords[key] then
			if DoesParticleFxLoopedExist(PlayEffectCoords[key]) then    -- DoesParticleFxLoopedExist
                RemoveParticleFx(PlayEffectCoords[key], false) -- RemoveParticleFx
				PlayEffectCoords[key] = nil
            end
		end
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
	if soundID > 0 then
		PlaySoundFromPositionWithId(soundID, "collectible_lure", pointCoords, "RDRO_Collectible_Sounds_Travelling_Saleswoman", 0, 0, true)
		PlaySoundCoords[pointCoords] = soundID
	else
		PlaySoundCoords[herbCoords] = nil
	end
	--	Citizen.InvokeNative(0xCCE219C922737BFA, "collectible_lure", herbCoords, "RDRO_Collectible_Sounds_Travelling_Saleswoman", true, 0, true, 0)
	--end
end

function stopSound(soundID) --удаляет звук если расстояние больше 10 метров или если сорвали растение
	if soundID and soundID > 0 then
		StopSoundWithName("collectible_lure", "RDRO_Collectible_Sounds_Travelling_Saleswoman")--Any STOP_SOUND_WITH_NAME ( char* audioName, char* audioRef )  //0x0F2A2175734926D8
		ReleaseSoundId(soundID)
	end
	ReleaseSoundset("RDRO_Collectible_Sounds_Travelling_Saleswoman")--void _RELEASE_SOUNDSET ( const char* soundsetName )  //0x531A78D6BF27014B
end

function RareHerbs(HerbID, HerbCoords, pointCoords)
	--if isRareHerbs(HerbID) then
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
		--if HerbID == 44 then
		--	MAP._0x7563CBCA99253D1A(entity, joaat("BLIP_MP_ROLE_NATURALIST"))
		--else
		--	MAP._0x7563CBCA99253D1A(entity, joaat("BLIP_MP_ROLE_COLLECTOR_ILO"))
		--end
	end
end

CreateThread(function()
    while true do
		Wait(150)
		if playerSpawn then
			local playerPosition = GetEntityCoords(PlayerPedId())
			local scenarios = getLootScenarioHash(playerPosition, 25.0, 2048, 100)
			if scenarios and #scenarios > 0 then
				for _, scenarioData in ipairs(scenarios) do
					local HerbID = scenarioData.herbsScenarioPoint.HerbID
					local pointCoords = GetScenarioPointCoords(scenarioData.scenario, true)
					local distance = #(playerPosition.xy - pointCoords.xy)
					if Composite[pointCoords.xy] and not Config.FullLootedScenarioPoint[pointCoords.xy] then
						if isSPHerbs(HerbID) then
							if distance <= 2.0 then
								local pickTime = Config.AutoEquipKnife and equipKnife(HerbID) or getPickupTime(HerbID)
								local prompt = Composite[pointCoords.xy].PickupPrompt
								
								PicUpOrchid(pointCoords, prompt, pickTime)
							end
						end
						--elseif isRareHerbs(HerbID) or isEggs(HerbID) then
						if Config.Composites[HerbID].spawn.isUnique and not Config.FullLootedScenarioPoint[pointCoords.xy] then
							if distance <= 20.0 and not PlaySoundCoords[pointCoords] then						
								playSound(pointCoords)
							elseif distance > 20.0 and PlaySoundCoords[pointCoords] then
								stopSound(PlaySoundCoords[pointCoords])
								PlaySoundCoords[pointCoords] = nil
							end					
						end
					--если точка залутана и есть запись со звуком - удаляем звук
					elseif Config.FullLootedScenarioPoint[pointCoords.xy] and PlaySoundCoords[pointCoords] then
						stopSound(PlaySoundCoords[pointCoords])
						PlaySoundCoords[pointCoords] = nil
					end
				end
			end
			--отключение звука при тп.
			for key, value in pairs(PlaySoundCoords) do
				local distance = #(playerPosition.xy - key.xy)
				if distance > 20.0 and PlaySoundCoords[key] then
					stopSound(PlaySoundCoords[key])
					PlaySoundCoords[key] = nil
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

function PicUpOrchid(pointCoords, pickupPrompt, pickTime)
	local picking = false	
	if PromptHasHoldModeCompleted(pickupPrompt) then
		local PlayerPed = PlayerPedId()
		local entity = Composite[pointCoords.xy].AttachEntity
		local groupPromt = Composite[pointCoords.xy].GroupPromt
		--удаляем prompt
		DeletePromptAndGroup(pointCoords.xy)
		
		local threadId = Citizen.CreateThread(function()
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
		--print("Нажали")
		picking = true
		local model = GetEntityModel(entity)
		local playerPosition = GetEntityCoords(PlayerPed)
		TaskLootEntity(PlayerPed, entity) --этой командой лутает цветки и т.д.
		--SetModelAsNoLongerNeeded(model)
        --SetEntityAsNoLongerNeeded(entity)
		Composite[pointCoords.xy].AttachEntity = nil		
		
		Wait(pickTime * 1000) -- чтобы не было повторных нажатий
		ClearPedTasks(PlayerPed)
		ClearPedSecondaryTask(PlayerPed)

		FindPicupCompositeAndCoords(playerPosition, model, true)		
		EnableControlAction(0, `INPUT_SECONDARY_SPECIAL_ABILITY_SECONDARY`, true)
		EnableControlAction(0, `INPUT_SPECIAL_ABILITY`, true)
		--Citizen.InvokeNative(0x87ED52AE40EA1A52, threadId)--TERMINATE_THREAD
	end
	picking = false	
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
							PlayEffectCoords[pointCoords.xy] = current_ptfx_handle_id
							is_particle_effect_active = true
                        end
                    end
                else
                    -- Eagle Eyes : OFF
                    if current_ptfx_handle_id then
                        if Citizen.InvokeNative(0x9DD5AFF561E88F2A, current_ptfx_handle_id) then    -- DoesParticleFxLoopedExist
                            Citizen.InvokeNative(0x459598F579C98929, current_ptfx_handle_id, false) -- RemoveParticleFx
							PlayEffectCoords[pointCoords.xy] = nil
                        end
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



function VectorEmpty(herbVector)
	if herbVector ~= nil then
		return herbVector.x == 0.0 and herbVector.y == 0.0 and herbVector.z == 0.0
	else
		return true
	end

end

function correctCoords(coords, heading)
    local c1 = math.sin(heading)
    local c2 = math.cos(heading)
    local x = (coords.x * c2) - (coords.y * c1)
    local y = (coords.x * c1) + (coords.y * c2)
    local z = coords.z
	local correct = vector3(x, y, z)
    return correct
end

function correctHeading(scenarioPointHeading)
    return (scenarioPointHeading * 0.01745329)
end

--так можно устроить проверку на сорваных растений на точке
function func_79(iParam1)
    return (f_4[iParam1 + 1] & 4096) ~= 0
end

function IsControlAlwaysPressed(inputGroup, control)
    return IsControlPressed(inputGroup, control) or IsDisabledControlPressed(inputGroup, control)
end

function FindPicupCompositeAndCoords(PickUpPlayerCoords, Model, Pickup)
	local lPickUp = Pickup
	local lModel = Model
	local lPickupCoords = PickUpPlayerCoords
	local tries = 0
	local nearestScenario, pointCoords, HerbID, compositeIndex
	if IsPedOnMount(PlayerPedId()) then
		lPickupCoords = GetEntityCoords(PlayerPedId())
	end	
	--local nearestScenario, pointCoords, HerbID, compositeIndex = GetNearestScenario(lPickupCoords, Model)
	--Иногда на лошади не сразу прилетает - поэтому повторим попытку через 500мс.
	while nearestScenario == nil and tries < 2 do
		nearestScenario, pointCoords, HerbID, compositeIndex = GetNearestScenario(lPickupCoords, Model)
		if nearestScenario == nil then
			Wait(500)
			tries = tries + 1
		end
	end
	if nearestScenario then
		if compositeIndex ~= nil then
			local nearestCompositeId = Composite[pointCoords.xy].CompositeId[compositeIndex]
			
			if Config.Composites[HerbID].spawn.isUnique then
				--SetEntityAsMissionEntity(Composite[pointCoords.xy].AttachEntity, true, true)
				--DeleteEntity(Composite[pointCoords.xy].AttachEntity)
				Composite[pointCoords.xy].AttachEntity = nil
				DeleteEffect(pointCoords.xy)				
			end
			--останавливаем звук и удаляем его запись
			if PlaySoundCoords[pointCoords] then
				stopSound(PlaySoundCoords[pointCoords])
				PlaySoundCoords[pointCoords] = nil				
			end			
			
			local CompositeAmount = GetHerbPicupAmountID(HerbID)			
			
			if lPickUp then
				--мы собрали
				if Config.Debug then
					print("Мы собрали: HerbID = " .. HerbID .. " compositeIndex = " .. compositeIndex .. " nearestCompositeId = " .. nearestCompositeId .. " num = " .. CompositeAmount)
				end
				TriggerServerEvent("rsg-composite:server:Gathered", HerbID, CompositeAmount)
				--дополнительная награда
				--GiveAdditionalRewards(HerbID)
				--PlaySoundFrontend("Core_Fill_Up", "Consumption_Sounds", true, 0)
			else
				--мы съели
				if Config.Debug then
					print("Мы съели: HerbID = " .. HerbID .. " num = " .. CompositeAmount .. " nearestCompositeId = " .. nearestCompositeId)
				end
				Eating(HerbID)
				TriggerServerEvent("rsg-composite:server:Eating", HerbID)
				if not Config.Composites[HerbID].eat.isPoison then
					PlaySoundFrontend("Core_Full", "Consumption_Sounds", true, 0)
				end
			end
			--local herbType = GetHerbType(HerbID)
			local herbType = Config.Composites[HerbID].herbNameHash
			if herbType ~= 0 then
				TelemetryHerbPicked(herbType)
				CompendiumHerbPicked(herbType, lPickupCoords)
				--print("add in telemetry and compendium " .. tostring(herbType))
			end
			Composite[pointCoords.xy].HerbCoords[compositeIndex] = vector3(0.0, 0.0, 0.0)
			--Citizen.InvokeNative(0x5758B1EE0C3FD4AC, nearestCompositeId, false) --удаляем композит. Только для дебага
			--Composite[pointCoords].HerbCoords[compositeIndex] = {x = 0.0, y = 0.0, z = 0.0}
			--удалять не надо. Они сами деспавнятся когда игрок далеко отойдет
			--иначе кусты пропадаю прямо перед игроком.
			--if isRareHerbs(HerbID) or isEggs(HerbID) then
			if not HerbsRemains(pointCoords.xy) then
				SetScenarioPointActive(nearestScenario, false)					
				--это по хорошему надо бы в DB закинуть. И при старте деактивировать все точки уже собранные.
				Config.FullLootedScenarioPoint[pointCoords.xy] = nearestScenario
				if Config.Debug then
					print("No more composite in point. Add record to Config.FullLootedScenarioPoint")
				end
				TriggerServerEvent('rsg-composite:saveGatheredPoint', pointCoords.xy, nearestScenario)				
			end
		else
			print("ERROR: No compositeIndex")
		end
	end
end

function GiveAdditionalRewards(herbID)
	if Config.Composites[herbID].rewards then
		for _, reward in pairs(Config.Composites[herbID].rewards) do
			local chance = reward.chance			
			local randomChance = math.random(1, 100)
			if randomChance <= chance then
				local item = reward.item
				local amountMin = reward.amountMin
				local amountMax = reward.amountMax
				local amount = (amountMin == amountMax) and amountMin or math.random(amountMin, amountMax)
				TriggerServerEvent("rsg-composite:server:AdditionRewards", item, amount)
			end		
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
	local scenarios = getLootScenarioHash(PickUpPlayerCoords, radius, 4096, 200)
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
			if not VectorEmpty(herbCoords[index]) then
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
		if not VectorEmpty(Composite[nearestScenarioPointIndex].HerbCoords[index]) then
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
--[[
function createAnimScene()
	playAnim('script_story@sal1@ig@sal1_ig12_wake_up', "puking_fb_arthur", 6000)
	Wait(6000)
	playAnim('script_story@sal1@ig@sal1_ig12_wake_up', "exit_arthur", 2000)
end

function playAnim(dict, name, time)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(100)
    end
    TaskPlayAnim(PlayerPedId(), dict, name, 1.0, 1.0, time, 1, 0, true, 0, false, 0, false)
end
--]]
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

function GetHerbID(hash)

    if hash == joaat("COMPOSITE_LOOTABLE_ALASKAN_GINSENG_ROOT_DEF") then
        return 2
    elseif hash == joaat("COMPOSITE_LOOTABLE_AMERICAN_GINSENG_ROOT_DEF") then
        return 3
    elseif hash == joaat("COMPOSITE_LOOTABLE_BAY_BOLETE_DEF") then
        return 4
    elseif hash == joaat("COMPOSITE_LOOTABLE_BLACK_BERRY_DEF") then
        return 5
    elseif hash == joaat("COMPOSITE_LOOTABLE_BLACK_CURRANT_DEF") then
        return 6
    elseif hash == joaat("COMPOSITE_LOOTABLE_BURDOCK_ROOT_DEF") then
        return 7
    elseif hash == joaat("COMPOSITE_LOOTABLE_CHANTERELLES_DEF") then
        return 8
    elseif hash == joaat("COMPOSITE_LOOTABLE_COMMON_BULRUSH_DEF") then
        return 11
    elseif hash == joaat("COMPOSITE_LOOTABLE_CREEPING_THYME_DEF") then
        return 12
    elseif hash == joaat("COMPOSITE_LOOTABLE_DESERT_SAGE_DEF") then
        return 13
    elseif hash == joaat("COMPOSITE_LOOTABLE_ENGLISH_MACE_DEF") then
        return 15
    elseif hash == joaat("COMPOSITE_LOOTABLE_EVERGREEN_HUCKLEBERRY_DEF") then
        return 16
    elseif hash == joaat("COMPOSITE_LOOTABLE_GOLDEN_CURRANT_DEF") then
        return 18
    elseif hash == joaat("COMPOSITE_LOOTABLE_HUMMINGBIRD_SAGE_DEF") then
        return 19
    elseif hash == joaat("COMPOSITE_LOOTABLE_INDIAN_TOBACCO_DEF") then
        return 20
    elseif hash == joaat("COMPOSITE_LOOTABLE_MILKWEED_DEF") then
        return 23
    elseif hash == joaat("COMPOSITE_LOOTABLE_OLEANDER_SAGE_DEF") then
        return 26
    elseif hash == joaat("COMPOSITE_LOOTABLE_OREGANO_DEF") then
        return 27
    elseif hash == joaat("COMPOSITE_LOOTABLE_PARASOL_MUSHROOM_DEF") then
        return 28
    elseif hash == joaat("COMPOSITE_LOOTABLE_PRAIRIE_POPPY_DEF") then
        return 29
    elseif hash == joaat("COMPOSITE_LOOTABLE_RAMS_HEAD_DEF") then
        return 31
    elseif hash == joaat("COMPOSITE_LOOTABLE_RED_RASPBERRY_DEF") then
        return 33
    elseif hash == joaat("COMPOSITE_LOOTABLE_RED_SAGE_DEF") then
        return 34
    elseif hash == joaat("COMPOSITE_LOOTABLE_ORCHID_VANILLA_DEF") then
        return 37
    elseif hash == joaat("COMPOSITE_LOOTABLE_VIOLET_SNOWDROP_DEF") then
        return 38
    elseif hash == joaat("COMPOSITE_LOOTABLE_WILD_CARROT_DEF") then
        return 39
    elseif hash == joaat("COMPOSITE_LOOTABLE_WILD_FEVERFEW_DEF") then
        return 40
    elseif hash == joaat("COMPOSITE_LOOTABLE_WILD_MINT_DEF") then
        return 41
    elseif hash == joaat("COMPOSITE_LOOTABLE_WINTERGREEN_BERRY_DEF") then
        return 42
    elseif hash == joaat("COMPOSITE_LOOTABLE_YARROW_DEF") then
        return 43
    elseif hash == joaat("COMPOSITE_LOOTABLE_ORCHID_ACUNA_STAR_DEF") then
        return 1
    elseif hash == joaat("COMPOSITE_LOOTABLE_ORCHID_CIGAR_DEF") then
        return 9
    elseif hash == joaat("COMPOSITE_LOOTABLE_ORCHID_CLAM_SHELL_DEF") then
        return 10
    elseif hash == joaat("COMPOSITE_LOOTABLE_ORCHID_DRAGONS_DEF") then
        return 14
    elseif hash == joaat("COMPOSITE_LOOTABLE_ORCHID_GHOST_DEF") then
        return 17
    elseif hash == joaat("COMPOSITE_LOOTABLE_ORCHID_LADY_NIGHT_DEF") then
        return 21
    elseif hash == joaat("COMPOSITE_LOOTABLE_ORCHID_LADY_SLIPPER_DEF") then
        return 22
    elseif hash == joaat("COMPOSITE_LOOTABLE_ORCHID_MOCCASIN_DEF") then
        return 24
    elseif hash == joaat("COMPOSITE_LOOTABLE_ORCHID_NIGHT_SCENTED_DEF") then
        return 25
    elseif hash == joaat("COMPOSITE_LOOTABLE_ORCHID_QUEENS_DEF") then
        return 30
    elseif hash == joaat("COMPOSITE_LOOTABLE_ORCHID_RAT_TAIL_DEF") then
        return 32
    elseif hash == joaat("COMPOSITE_LOOTABLE_ORCHID_SPARROWS_DEF") then
        return 35
    elseif hash == joaat("COMPOSITE_LOOTABLE_ORCHID_SPIDER_DEF") then
        return 36
		
	elseif hash == joaat("COMPOSITE_LOOTABLE_HARRIETUM_OFFICINALIS_DEF") then
        return 44
	elseif hash == joaat("COMPOSITE_LOOTABLE_AGARITA_DEF") then
        return 45
	elseif hash == joaat("COMPOSITE_LOOTABLE_TEXAS_BONNET_DEF") then
        return 46
	elseif hash == joaat("COMPOSITE_LOOTABLE_BITTERWEED_DEF") then
        return 47
	elseif hash == joaat("COMPOSITE_LOOTABLE_BLOODFLOWER_DEF") then
        return 48
	elseif hash == joaat("COMPOSITE_LOOTABLE_CARDINAL_FLOWER_DEF") then
        return 49
	elseif hash == joaat("COMPOSITE_LOOTABLE_CHOC_DAISY_DEF") then
        return 50
	elseif hash == joaat("COMPOSITE_LOOTABLE_CREEKPLUM_DEF") then
        return 51
	elseif hash == joaat("COMPOSITE_LOOTABLE_WILD_RHUBARB_DEF") then
        return 52
	elseif hash == joaat("COMPOSITE_LOOTABLE_WISTERIA_DEF") then
        return 53
	
	--Яйца
	elseif hash == joaat("COMPOSITE_LOOTABLE_GATOR_EGG_3_DEF") then
        return 54
	elseif hash == joaat("COMPOSITE_LOOTABLE_GATOR_EGG_4_DEF") then
        return 55
	elseif hash == joaat("COMPOSITE_LOOTABLE_GATOR_EGG_5_DEF") then
        return 56
	elseif hash == joaat("COMPOSITE_LOOTABLE_DUCK_EGG_5_DEF") then
        return 57
	elseif hash == joaat("COMPOSITE_LOOTABLE_GOOSE_EGG_4_DEF") then
        return 58
	elseif hash == joaat("COMPOSITE_LOOTABLE_LOON_EGG_3_DEF") then
        return 59
	elseif hash == joaat("COMPOSITE_LOOTABLE_VULTURE_EGG_DEF") then
        return 60
		
	--Лук виноградничный
	elseif hash == joaat("COMPOSITE_LOOTABLE_CROWS_GARLIC_DEF") then
        return 61
	--Лебеда
	elseif hash == joaat("COMPOSITE_LOOTABLE_SALTBUSH_DEF") then
        return 62
		
    else
        return 0
    end
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

function GetUnk1(HerbID)
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

















--[[

function GetHerbPicupAmount(CompositeHash)
	if CompositeHash == "COMPOSITE_LOOTABLE_ALASKAN_GINSENG_ROOT_INTERACTABLE_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_AMERICAN_GINSENG_ROOT_INTERACTABLE_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_BAY_BOLETE_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_BLACK_BERRY_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_BLACK_CURRANT_INTERACTABLE_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_BURDOCK_ROOT_INTERACTABLE_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_CHANTERELLES_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_COMMON_BULRUSH_INTERACTABLE_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_CREEPING_THYME_INTERACTABLE_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_DESERT_SAGE_INTERACTABLE_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_ENGLISH_MACE_INTERACTABLE_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_EVERGREEN_HUCKLEBERRY_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_GOLDEN_CURRANT_INTERACTABLE_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_HUMMINGBIRD_SAGE_INTERACTABLE_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_INDIAN_TOBACCO_INTERACTABLE_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_MILKWEED_INTERACTABLE_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_OLEANDER_SAGE_INTERACTABLE_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_OREGANO_INTERACTABLE_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_PARASOL_MUSHROOM_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_PRAIRIE_POPPY_INTERACTABLE_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_RAMS_HEAD_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_RED_RASPBERRY_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_RED_SAGE_INTERACTABLE_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_ORCHID_VANILLA_INTERACTABLE_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_VIOLET_SNOWDROP_INTERACTABLE_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_WILD_CARROT_INTERACTABLE_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_WILD_FEVERFEW_INTERACTABLE_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_WILD_MINT_INTERACTABLE_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_WINTERGREEN_BERRY_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_YARROW_INTERACTABLE_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_ORCHID_ACUNA_STAR_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_ORCHID_CIGAR_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_ORCHID_CLAM_SHELL_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_ORCHID_DRAGONS_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_ORCHID_GHOST_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_ORCHID_LADY_NIGHT_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_ORCHID_LADY_SLIPPER_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_ORCHID_MOCCASIN_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_ORCHID_NIGHT_SCENTED_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_ORCHID_QUEENS_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_ORCHID_RAT_TAIL_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_ORCHID_SPARROWS_DEF" then
        return 1
    elseif CompositeHash == "COMPOSITE_LOOTABLE_ORCHID_SPIDER_DEF" then
        return 1
	
	elseif CompositeHash == "COMPOSITE_LOOTABLE_HARRIETUM_OFFICINALIS_INTERACTABLE_DEF" then
        return 1
	elseif CompositeHash == "COMPOSITE_LOOTABLE_AGARITA_DEF" then
        return 1
	elseif CompositeHash == "COMPOSITE_LOOTABLE_TEXAS_BONNET_INTERACTABLE_DEF" then
        return 1
	elseif CompositeHash == "COMPOSITE_LOOTABLE_BITTERWEED_INTERACTABLE_DEF" then
        return 1
	elseif CompositeHash == "COMPOSITE_LOOTABLE_BLOODFLOWER_INTERACTABLE_DEF" then
        return 1
	elseif CompositeHash == "COMPOSITE_LOOTABLE_CARDINAL_FLOWER_INTERACTABLE_DEF" then
        return 1
	elseif CompositeHash == "COMPOSITE_LOOTABLE_CHOC_DAISY_INTERACTABLE_DEF" then
        return 1
	elseif CompositeHash == "COMPOSITE_LOOTABLE_CREEKPLUM_DEF" then
        return 1
	elseif CompositeHash == "COMPOSITE_LOOTABLE_WILD_RHUBARB_INTERACTABLE_DEF" then
        return 1
	elseif CompositeHash == "COMPOSITE_LOOTABLE_WISTERIA_DEF" then
        return 1
		
	elseif CompositeHash == "COMPOSITE_LOOTABLE_GATOR_EGG_3_DEF" then
        return 3
	elseif CompositeHash == "COMPOSITE_LOOTABLE_GATOR_EGG_4_DEF" then
        return 4
	elseif CompositeHash == "COMPOSITE_LOOTABLE_GATOR_EGG_5_DEF" then
        return 5
	elseif CompositeHash == "COMPOSITE_LOOTABLE_DUCK_EGG_5_DEF" then
        return 5
	elseif CompositeHash == "COMPOSITE_LOOTABLE_GOOSE_EGG_4_DEF" then
        return 4
	elseif CompositeHash == "COMPOSITE_LOOTABLE_LOON_EGG_3_DEF" then
        return 3
	elseif CompositeHash == "COMPOSITE_LOOTABLE_VULTURE_EGG_DEF" then
        return 1

		
	else
        return 1
    end
end
--]]
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
--[[
function GetHerbType(HerbID)
	if HerbID == 2 then
		return `HERB_ALASKAN_GINSENG`
	elseif HerbID == 3 then
        return `HERB_AMERICAN_GINSENG`
	elseif HerbID == 4 then
        return `HERB_BAY_BOLETE`
	elseif HerbID == 5 then
        return `HERB_BLACK_BERRY`
	elseif HerbID == 6 then
        return `HERB_BLACK_CURRANT`
	elseif HerbID == 7 then
        return `HERB_BURDOCK_ROOT`
	elseif HerbID == 8 then
        return `HERB_CHANTERELLES`
	elseif HerbID == 11 then
        return `HERB_COMMON_BULRUSH`
	elseif HerbID == 12 then
        return `HERB_CREEPING_THYME`
	elseif HerbID == 13 then
        return `HERB_DESERT_SAGE`
	elseif HerbID == 15 then
        return `HERB_ENGLISH_MACE`
	elseif HerbID == 16 then
        return `HERB_EVERGREEN_HUCKLEBERRY`
	elseif HerbID == 18 then
        return `HERB_GOLDEN_CURRANT`
	elseif HerbID == 19 then
        return `HERB_HUMMINGBIRD_SAGE`
	elseif HerbID == 20 then
        return `HERB_INDIAN_TOBACCO`
	elseif HerbID == 23 then
        return `HERB_MILKWEED`
	elseif HerbID == 26 then
        return `HERB_OLEANDER_SAGE`
	elseif HerbID == 27 then
        return `HERB_OREGANO`
	elseif HerbID == 28 then
        return `HERB_PARASOL_MUSHROOM`
	elseif HerbID == 29 then
        return `HERB_PRAIRIE_POPPY`
	elseif HerbID == 31 then
        return `HERB_RAMS_HEAD`
	elseif HerbID == 33 then
        return `HERB_RED_RASPBERRY`
	elseif HerbID == 34 then
        return `HERB_RED_SAGE`
	elseif HerbID == 37 then
        return `HERB_VANILLA_FLOWER`
	elseif HerbID == 38 then
        return `HERB_VIOLET_SNOWDROP`
	elseif HerbID == 39 then
        return `HERB_WILD_CARROTS`
	elseif HerbID == 40 then
        return `HERB_WILD_FEVERFEW`
	elseif HerbID == 41 then
        return `HERB_WILD_MINT`
	elseif HerbID == 42 then
        return `HERB_WINTERGREEN_BERRY`
	elseif HerbID == 43 then
        return `HERB_YARROW`
	elseif HerbID == 1 then
        return `HERB_ACUNAS_STAR_ORCHID`
	elseif HerbID == 9 then
        return `HERB_CIGAR_ORCHID`
	elseif HerbID == 10 then
        return `HERB_CLAMSHELL_ORCHID`
	elseif HerbID == 14 then
        return `HERB_DRAGONS_MOUTH_ORCHID`
	elseif HerbID == 17 then
        return `HERB_GHOST_ORCHID`
	elseif HerbID == 21 then
        return `HERB_LADY_OF_NIGHT_ORCHID`
	elseif HerbID == 22 then
        return `HERB_LADY_SLIPPER_ORCHID`
	elseif HerbID == 24 then
        return `HERB_MOCCASIN_FLOWER_ORCHID`
	elseif HerbID == 25 then
        return `HERB_NIGHT_SCENTED_ORCHID`
	elseif HerbID == 30 then
        return `HERB_QUEENS_ORCHID`
	elseif HerbID == 32 then
        return `HERB_RAT_TAIL_ORCHID`
	elseif HerbID == 35 then
        return `HERB_SPARROWS_EGG_ORCHID`
	elseif HerbID == 36 then
        return `HERB_SPIDER_ORCHID`
	elseif HerbID == 44 then
        return `HERB_HARRIETUM_OFFICINALIS`
	elseif HerbID == 45 then
        return `HERB_WILD_FLWR_AGARITA`
	elseif HerbID == 46 then
        return `HERB_WILD_FLWR_BLUE_BONNET`
	elseif HerbID == 47 then
        return `HERB_WILD_FLWR_BITTERWEED`
	elseif HerbID == 48 then
        return `HERB_WILD_FLWR_BLOOD_FLOWER`
	elseif HerbID == 49 then
        return `HERB_WILD_FLWR_CARDINAL_FLOWER`
	elseif HerbID == 50 then
        return `HERB_WILD_FLWR_CHOCOLATE_DAISY`
	elseif HerbID == 51 then
        return `HERB_WILD_FLWR_CREEK_PLUM`
	elseif HerbID == 52 then
        return `HERB_WILD_FLWR_RHUBARB`
	elseif HerbID == 53 then
        return `HERB_WILD_FLWR_WISTERIA`
--]]
	
	--[[
	--Яйца
	elseif hash == joaat("COMPOSITE_LOOTABLE_GATOR_EGG_3_DEF") then
        return 54
	elseif hash == joaat("COMPOSITE_LOOTABLE_GATOR_EGG_4_DEF") then
        return 55
	elseif hash == joaat("COMPOSITE_LOOTABLE_GATOR_EGG_5_DEF") then
        return 56
	elseif hash == joaat("COMPOSITE_LOOTABLE_DUCK_EGG_5_DEF") then
        return 57
	elseif hash == joaat("COMPOSITE_LOOTABLE_GOOSE_EGG_4_DEF") then
        return 58
	elseif hash == joaat("COMPOSITE_LOOTABLE_LOON_EGG_3_DEF") then
        return 59
	elseif hash == joaat("COMPOSITE_LOOTABLE_VULTURE_EGG_DEF") then
        return 60
		
	--Лук виноградничный
	elseif hash == joaat("COMPOSITE_LOOTABLE_CROWS_GARLIC_DEF") then
        return 61
	--Лебеда
	elseif hash == joaat("COMPOSITE_LOOTABLE_SALTBUSH_DEF") then
        return 62
	--]]	
--[[
    else
        return 0
    end
end
--]]

--[[
function createAnimScene(entity)
	local ped = PlayerPedId()
	
	Citizen.InvokeNative(0x48FAE038401A2888, ped, entity) --этой командой лутает цветки и т.д.
		
		
	--playAnim('mech_pickup@plant@orchid_tree', "base", 6200)
	--local boneIndex = GetPedBoneIndex(ped, 7966)
	--Wait(1500)
	--AttachEntityToEntity(entity, ped, boneIndex, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 2, 1, 0, 0)
	--Wait(3200)
	----DeleteObject(entity)--потом как все отрегулирую- надо это включить. Чтобы не спавнилось больше
	--SetEntityVisible(entity, false)
end

function playAnim(dict, name, time)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(100)
    end
    TaskPlayAnim(PlayerPedId(), dict, name, 1.0, 1.0, time, 1, 0, true, 0, false, 0, false)
	
	--animDict = "mech_pickup@plant@orchid_tree",
    --animPart = "base",
    --animDur = 4500
	
	--animscene  = script@playercamp@pick_orchid_plant@base_plant
	--scenario@mech@player_pick_orchid_van_1m82@base
	--scenario@mech@player_pick_orchid_van_1m82@enter
	
	--mech_pickup@plant@orchid_plant
	--mech_pickup@plant@orchid_tree
end
--]]

--[[
function GetHerbHash(HerbID)
    if HerbID == 2 then
        return joaat("CONSUMABLE_HERB_GINSENG")
    elseif HerbID == 3 then
        return joaat("CONSUMABLE_HERB_GINSENG")
    elseif HerbID == 4 then
        return joaat("CONSUMABLE_HERB_BAY_BOLETE")
    elseif HerbID == 5 then
        return joaat("CONSUMABLE_HERB_BLACK_BERRY")
    elseif HerbID == 6 then
        return joaat("CONSUMABLE_HERB_CURRANT")
    elseif HerbID == 7 then
        return joaat("CONSUMABLE_HERB_BURDOCK_ROOT")
    elseif HerbID == 8 then
        return joaat("CONSUMABLE_HERB_CHANTERELLES")
    elseif HerbID == 11 then
        return joaat("CONSUMABLE_HERB_COMMON_BULRUSH")
    elseif HerbID == 12 then
        return joaat("CONSUMABLE_HERB_CREEPING_THYME")
    elseif HerbID == 13 then
        return joaat("CONSUMABLE_HERB_SAGE")
    elseif HerbID == 15 then
        return joaat("CONSUMABLE_HERB_ENGLISH_MACE")
    elseif HerbID == 16 then
        return joaat("CONSUMABLE_HERB_EVERGREEN_HUCKLEBERRY")
    elseif HerbID == 18 then
        return joaat("CONSUMABLE_HERB_CURRANT")
    elseif HerbID == 19 then
        return joaat("CONSUMABLE_HERB_SAGE")
    elseif HerbID == 20 then
        return joaat("CONSUMABLE_HERB_INDIAN_TOBACCO")
    elseif HerbID == 23 then
        return joaat("CONSUMABLE_HERB_MILKWEED")
    elseif HerbID == 26 then
        return joaat("CONSUMABLE_HERB_OLEANDER_SAGE")
    elseif HerbID == 27 then
        return joaat("CONSUMABLE_HERB_OREGANO")
    elseif HerbID == 28 then
        return joaat("CONSUMABLE_HERB_PARASOL_MUSHROOM")
    elseif HerbID == 29 then
        return joaat("CONSUMABLE_HERB_PRAIRIE_POPPY")
    elseif HerbID == 31 then
        return joaat("CONSUMABLE_HERB_RAMS_HEAD")
    elseif HerbID == 33 then
        return joaat("CONSUMABLE_HERB_RED_RASPBERRY")
    elseif HerbID == 34 then
        return joaat("CONSUMABLE_HERB_SAGE")
    elseif HerbID == 37 then
        return joaat("CONSUMABLE_HERB_VANILLA_FLOWER")
    elseif HerbID == 38 then
        return joaat("CONSUMABLE_HERB_VIOLET_SNOWDROP")
    elseif HerbID == 39 then
        return joaat("CONSUMABLE_HERB_WILD_CARROTS")
    elseif HerbID == 40 then
        return joaat("CONSUMABLE_HERB_WILD_FEVERFEW")
    elseif HerbID == 41 then
        return joaat("CONSUMABLE_HERB_WILD_MINT")
    elseif HerbID == 42 then
        return joaat("CONSUMABLE_HERB_WINTERGREEN_BERRY")
    elseif HerbID == 43 then
        return joaat("CONSUMABLE_HERB_YARROW")
    elseif HerbID == 1 then
        return joaat("PROVISION_RO_FLOWER_ACUNAS_STAR")
    elseif HerbID == 9 then
        return joaat("PROVISION_RO_FLOWER_CIGAR")
    elseif HerbID == 10 then
        return joaat("PROVISION_RO_FLOWER_CLAMSHELL")
    elseif HerbID == 14 then
        return joaat("PROVISION_RO_FLOWER_DRAGONS")
    elseif HerbID == 17 then
        return joaat("PROVISION_RO_FLOWER_GHOST")
    elseif HerbID == 21 then
        return joaat("PROVISION_RO_FLOWER_LADY_OF_NIGHT")
    elseif HerbID == 22 then
        return joaat("PROVISION_RO_FLOWER_LADY_SLIPPER")
    elseif HerbID == 24 then
        return joaat("PROVISION_RO_FLOWER_MOCCASIN")
    elseif HerbID == 25 then
        return joaat("PROVISION_RO_FLOWER_NIGHT_SCENTED")
    elseif HerbID == 30 then
        return joaat("PROVISION_RO_FLOWER_QUEENS")
    elseif HerbID == 32 then
        return joaat("PROVISION_RO_FLOWER_RAT_TAIL")
    elseif HerbID == 35 then
        return joaat("PROVISION_RO_FLOWER_SPARROWS")
    elseif HerbID == 36 then
        return joaat("PROVISION_RO_FLOWER_SPIDER")
		
	elseif HerbID == 44 then
        return joaat("CONSUMABLE_HERB_HARRIETUM")
	elseif HerbID == 45 then
        return joaat("PROVISION_WLDFLWR_AGARITA")
	elseif HerbID == 46 then
        return joaat("PROVISION_WLDFLWR_TEXAS_BLUE_BONNET")
	elseif HerbID == 47 then
        return joaat("PROVISION_WLDFLWR_BITTERWEED")
	elseif HerbID == 48 then
        return joaat("PROVISION_WLDFLWR_BLOOD_FLOWER")
	elseif HerbID == 49 then
        return joaat("PROVISION_WLDFLWR_CARDINAL_FLOWER")
	elseif HerbID == 50 then
        return joaat("PROVISION_WLDFLWR_CHOCOLATE_DAISY")
	elseif HerbID == 51 then
        return joaat("PROVISION_WLDFLWR_CREEK_PLUM")
	elseif HerbID == 52 then
        return joaat("PROVISION_WLDFLWR_WILD_RHUBARB")
	elseif HerbID == 53 then
        return joaat("PROVISION_WLDFLWR_WISTERIA")
		
	elseif HerbID == 54 then
        return joaat("PROVISION_GATOR_EGG")
	elseif HerbID == 55 then
        return joaat("PROVISION_GATOR_EGG")
	elseif HerbID == 56 then
        return joaat("PROVISION_GATOR_EGG")
	elseif HerbID == 57 then
        return joaat("PROVISION_DUCK_EGG")
	elseif HerbID == 58 then
        return joaat("PROVISION_GOOSE_EGG")
	elseif HerbID == 59 then
        return joaat("PROVISION_LOON_EGG")
	elseif HerbID == 60 then
        return joaat("PROVISION_VULTURE_EGG")
		
    else
        return 0
    end
end
--]]
--[[
function GetCompositeHash(HerbID)
	if HerbID == 2 then
        return joaat("COMPOSITE_LOOTABLE_ALASKAN_GINSENG_ROOT_DEF")
    elseif HerbID == 3 then
        return joaat("COMPOSITE_LOOTABLE_AMERICAN_GINSENG_ROOT_DEF")
    elseif HerbID == 4 then
        return joaat("COMPOSITE_LOOTABLE_BAY_BOLETE_DEF")
    elseif HerbID == 5 then
        return joaat("COMPOSITE_LOOTABLE_BLACK_BERRY_DEF")
    elseif HerbID == 6 then
        return joaat("COMPOSITE_LOOTABLE_BLACK_CURRANT_DEF")
    elseif HerbID == 7 then
        return joaat("COMPOSITE_LOOTABLE_BURDOCK_ROOT_DEF")
    elseif HerbID == 8 then
        return joaat("COMPOSITE_LOOTABLE_CHANTERELLES_DEF")
    elseif HerbID == 11 then
        return joaat("COMPOSITE_LOOTABLE_COMMON_BULRUSH_DEF")
    elseif HerbID == 12 then
        return joaat("COMPOSITE_LOOTABLE_CREEPING_THYME_DEF")
    elseif HerbID == 13 then
        return joaat("COMPOSITE_LOOTABLE_DESERT_SAGE_DEF")
    elseif HerbID == 15 then
        return joaat("COMPOSITE_LOOTABLE_ENGLISH_MACE_DEF")
    elseif HerbID == 16 then
        return joaat("COMPOSITE_LOOTABLE_EVERGREEN_HUCKLEBERRY_DEF")
    elseif HerbID == 18 then
        return joaat("COMPOSITE_LOOTABLE_GOLDEN_CURRANT_DEF")
    elseif HerbID == 19 then
        return joaat("COMPOSITE_LOOTABLE_HUMMINGBIRD_SAGE_DEF")
    elseif HerbID == 20 then
        return joaat("COMPOSITE_LOOTABLE_INDIAN_TOBACCO_DEF")
    elseif HerbID == 23 then
        return joaat("COMPOSITE_LOOTABLE_MILKWEED_DEF")
    elseif HerbID == 26 then
        return joaat("COMPOSITE_LOOTABLE_OLEANDER_SAGE_DEF")
    elseif HerbID == 27 then
        return joaat("COMPOSITE_LOOTABLE_OREGANO_DEF")
    elseif HerbID == 28 then
        return joaat("COMPOSITE_LOOTABLE_PARASOL_MUSHROOM_DEF")
    elseif HerbID == 29 then
        return joaat("COMPOSITE_LOOTABLE_PRAIRIE_POPPY_DEF")
    elseif HerbID == 31 then
        return joaat("COMPOSITE_LOOTABLE_RAMS_HEAD_DEF")
    elseif HerbID == 33 then
        return joaat("COMPOSITE_LOOTABLE_RED_RASPBERRY_DEF")
    elseif HerbID == 34 then
        return joaat("COMPOSITE_LOOTABLE_RED_SAGE_DEF")
    elseif HerbID == 37 then
        return joaat("COMPOSITE_LOOTABLE_ORCHID_VANILLA_DEF")
    elseif HerbID == 38 then
        return joaat("COMPOSITE_LOOTABLE_VIOLET_SNOWDROP_DEF")
    elseif HerbID == 39 then
        return joaat("COMPOSITE_LOOTABLE_WILD_CARROT_DEF")
    elseif HerbID == 40 then
        return joaat("COMPOSITE_LOOTABLE_WILD_FEVERFEW_DEF")
    elseif HerbID == 41 then
        return joaat("COMPOSITE_LOOTABLE_WILD_MINT_DEF")
    elseif HerbID == 42 then
        return joaat("COMPOSITE_LOOTABLE_WINTERGREEN_BERRY_DEF")
    elseif HerbID == 43 then
        return joaat("COMPOSITE_LOOTABLE_YARROW_DEF")
    elseif HerbID == 1 then
        return joaat("COMPOSITE_LOOTABLE_ORCHID_ACUNA_STAR_DEF")
    elseif HerbID == 9 then
        return joaat("COMPOSITE_LOOTABLE_ORCHID_CIGAR_DEF")
    elseif HerbID == 10 then
        return joaat("COMPOSITE_LOOTABLE_ORCHID_CLAM_SHELL_DEF")
    elseif HerbID == 14 then
        return joaat("COMPOSITE_LOOTABLE_ORCHID_DRAGONS_DEF")
    elseif HerbID == 17 then
        return joaat("COMPOSITE_LOOTABLE_ORCHID_GHOST_DEF")
    elseif HerbID == 21 then
        return joaat("COMPOSITE_LOOTABLE_ORCHID_LADY_NIGHT_DEF")
    elseif HerbID == 22 then
        return joaat("COMPOSITE_LOOTABLE_ORCHID_LADY_SLIPPER_DEF")
    elseif HerbID == 24 then
        return joaat("COMPOSITE_LOOTABLE_ORCHID_MOCCASIN_DEF")
    elseif HerbID == 25 then
        return joaat("COMPOSITE_LOOTABLE_ORCHID_NIGHT_SCENTED_DEF")
    elseif HerbID == 30 then
        return joaat("COMPOSITE_LOOTABLE_ORCHID_QUEENS_DEF")
    elseif HerbID == 32 then
        return joaat("COMPOSITE_LOOTABLE_ORCHID_RAT_TAIL_DEF")
    elseif HerbID == 35 then
        return joaat("COMPOSITE_LOOTABLE_ORCHID_SPARROWS_DEF")
    elseif HerbID == 36 then
        return joaat("COMPOSITE_LOOTABLE_ORCHID_SPIDER_DEF")
		
	elseif HerbID == 44 then
        return joaat("COMPOSITE_LOOTABLE_HARRIETUM_OFFICINALIS_DEF")
	elseif HerbID == 45 then
        return joaat("COMPOSITE_LOOTABLE_AGARITA_DEF")
	elseif HerbID == 46 then
        return joaat("COMPOSITE_LOOTABLE_TEXAS_BONNET_DEF")
	elseif HerbID == 47 then
        return joaat("COMPOSITE_LOOTABLE_BITTERWEED_DEF")
	elseif HerbID == 48 then
        return joaat("COMPOSITE_LOOTABLE_BLOOD_FLOWER_DEF")
	elseif HerbID == 49 then
        return joaat("COMPOSITE_LOOTABLE_CARDINAL_FLOWER_DEF")
	elseif HerbID == 50 then
        return joaat("COMPOSITE_LOOTABLE_CHOC_DAISY_DEF")
	elseif HerbID == 51 then
        return joaat("COMPOSITE_LOOTABLE_CREEKPLUM_DEF")
	elseif HerbID == 52 then
        return joaat("COMPOSITE_LOOTABLE_WILD_RHUBARB_DEF")
	elseif HerbID == 53 then
        return joaat("COMPOSITE_LOOTABLE_WISTERIA_DEF")
		
	elseif HerbID == 54 then
        return joaat("COMPOSITE_LOOTABLE_GATOR_EGG_3_DEF")
	elseif HerbID == 55 then
        return joaat("COMPOSITE_LOOTABLE_GATOR_EGG_4_DEF")
	elseif HerbID == 56 then
        return joaat("COMPOSITE_LOOTABLE_GATOR_EGG_5_DEF")
	elseif HerbID == 57 then
        return joaat("COMPOSITE_LOOTABLE_DUCK_EGG_5_DEF")
	elseif HerbID == 58 then
        return joaat("COMPOSITE_LOOTABLE_GOOSE_EGG_4_DEF")
	elseif HerbID == 59 then
        return joaat("COMPOSITE_LOOTABLE_LOON_EGG_3_DEF")
	elseif HerbID == 60 then
        return joaat("COMPOSITE_LOOTABLE_VULTURE_EGG_DEF")
	
	
    else
        return 0
    end
end

function GetHerbIDFromLootedHash(lootedComposite)
	if lootedComposite == joaat("COMPOSITE_LOOTABLE_ALASKAN_GINSENG_ROOT_INTERACTABLE_DEF") then
        return 2
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_AMERICAN_GINSENG_ROOT_INTERACTABLE_DEF") then
        return 3
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_BAY_BOLETE_DEF") then
        return 4
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_BLACK_BERRY_DEF") then
        return 5
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_BLACK_CURRANT_INTERACTABLE_DEF") then
        return 6
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_BURDOCK_ROOT_INTERACTABLE_DEF") then
        return 7
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_CHANTERELLES_DEF") then
        return 8
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_COMMON_BULRUSH_INTERACTABLE_DEF") then
        return 11
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_CREEPING_THYME_INTERACTABLE_DEF") then
        return 12
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_DESERT_SAGE_INTERACTABLE_DEF") then
        return 13
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_ENGLISH_MACE_INTERACTABLE_DEF") then
        return 15
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_EVERGREEN_HUCKLEBERRY_DEF") then
        return 16
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_GOLDEN_CURRANT_INTERACTABLE_DEF") then
        return 18
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_HUMMINGBIRD_SAGE_INTERACTABLE_DEF") then
        return 19
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_INDIAN_TOBACCO_INTERACTABLE_DEF") then
        return 20
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_MILKWEED_INTERACTABLE_DEF") then
        return 23
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_OLEANDER_SAGE_INTERACTABLE_DEF") then
        return 26
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_OREGANO_INTERACTABLE_DEF") then
        return 27
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_PARASOL_MUSHROOM_DEF") then
        return 28
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_PRAIRIE_POPPY_INTERACTABLE_DEF") then
        return 29
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_RAMS_HEAD_DEF") then
        return 31
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_RED_RASPBERRY_DEF") then
        return 33
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_RED_SAGE_INTERACTABLE_DEF") then
        return 34
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_ORCHID_VANILLA_INTERACTABLE_DEF") then
        return 37
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_VIOLET_SNOWDROP_INTERACTABLE_DEF") then
        return 38
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_WILD_CARROT_INTERACTABLE_DEF") then
        return 39
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_WILD_FEVERFEW_INTERACTABLE_DEF") then
        return 40
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_WILD_MINT_INTERACTABLE_DEF") then
        return 41
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_WINTERGREEN_BERRY_DEF") then
        return 42
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_YARROW_INTERACTABLE_DEF") then
        return 43
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_ORCHID_ACUNA_STAR_DEF") then
        return 1
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_ORCHID_CIGAR_DEF") then
        return 9
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_ORCHID_CLAM_SHELL_DEF") then
        return 10
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_ORCHID_DRAGONS_DEF") then
        return 14
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_ORCHID_GHOST_DEF") then
        return 17
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_ORCHID_LADY_NIGHT_DEF") then
        return 21
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_ORCHID_LADY_SLIPPER_DEF") then
        return 22
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_ORCHID_MOCCASIN_DEF") then
        return 24
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_ORCHID_NIGHT_SCENTED_DEF") then
        return 25
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_ORCHID_QUEENS_DEF") then
        return 30
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_ORCHID_RAT_TAIL_DEF") then
        return 32
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_ORCHID_SPARROWS_DEF") then
        return 35
    elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_ORCHID_SPIDER_DEF") then
        return 36
	
	elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_HARRIETUM_OFFICINALIS_INTERACTABLE_DEF") then
        return 44
	elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_AGARITA_DEF") then
        return 45
	elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_TEXAS_BONNET_INTERACTABLE_DEF") then
        return 46
	elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_BITTERWEED_INTERACTABLE_DEF") then
        return 47
	elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_BLOODFLOWER_INTERACTABLE_DEF") then
        return 48
	elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_CARDINAL_FLOWER_INTERACTABLE_DEF") then
        return 49
	elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_CHOC_DAISY_INTERACTABLE_DEF") then
        return 50
	elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_CREEKPLUM_DEF") then
        return 51
	elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_WILD_RHUBARB_INTERACTABLE_DEF") then
        return 52
	elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_WISTERIA_DEF") then
        return 53
		
	elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_GATOR_EGG_3_DEF") then
        return 54
	elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_GATOR_EGG_4_DEF") then
        return 55
	elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_GATOR_EGG_5_DEF") then
        return 56
	elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_DUCK_EGG_5_DEF") then
        return 57
	elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_GOOSE_EGG_4_DEF") then
        return 58
	elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_LOON_EGG_3_DEF") then
        return 59
	elseif lootedComposite == joaat("COMPOSITE_LOOTABLE_VULTURE_EGG_DEF") then
        return 60

		
	else
        return 0
    end
end

function GetEntytiFromHerbID(HerbID)
	if HerbID == 2 then
        return -1194833913
    elseif HerbID == 3 then
        return -781771732
    elseif HerbID == 4 then
        return -1202590500
    elseif HerbID == 5 then
        return -550091683
    elseif HerbID == 6 then
        return -190820666
    elseif HerbID == 7 then
        return 63835692
    elseif HerbID == 8 then
        return -1524011012
    elseif HerbID == 11 then
        return -1291682103
    elseif HerbID == 12 then
        return 2129486088
    elseif HerbID == 13 then
        return 1640283709
    elseif HerbID == 15 then
        return -177017064
    elseif HerbID == 16 then
        return -231430744
    elseif HerbID == 18 then
        return -1298766667
    elseif HerbID == 19 then
        return 68963282
    elseif HerbID == 20 then
        return 316930447
    elseif HerbID == 23 then
        return -1944784826
    elseif HerbID == 26 then
        return 454655011
    elseif HerbID == 27 then
        return 2033030310
    elseif HerbID == 28 then
        return 926616681
    elseif HerbID == 29 then
        return -423117050
    elseif HerbID == 31 then
        return 76556053
    elseif HerbID == 33 then
        return -1326233925
    elseif HerbID == 34 then
        return -1333051172
    elseif HerbID == 37 then
        return 1195604412
    elseif HerbID == 38 then
        return -1019761233
    elseif HerbID == 39 then
        return -780853522
    elseif HerbID == 40 then
        return 561391114
    elseif HerbID == 41 then
        return -351933124
    elseif HerbID == 42 then
        return 1057523711
    elseif HerbID == 43 then
        return 918835244
    elseif HerbID == 1 then
        return joaat("COMPOSITE_LOOTABLE_ORCHID_ACUNA_STAR_DEF")
    elseif HerbID == 9 then
        return joaat("COMPOSITE_LOOTABLE_ORCHID_CIGAR_DEF")
    elseif HerbID == 10 then
        return joaat("COMPOSITE_LOOTABLE_ORCHID_CLAM_SHELL_DEF")
    elseif HerbID == 14 then
        return joaat("COMPOSITE_LOOTABLE_ORCHID_DRAGONS_DEF")
    elseif HerbID == 17 then
        return joaat("COMPOSITE_LOOTABLE_ORCHID_GHOST_DEF")
    elseif HerbID == 21 then
        return joaat("COMPOSITE_LOOTABLE_ORCHID_LADY_NIGHT_DEF")
    elseif HerbID == 22 then
        return joaat("COMPOSITE_LOOTABLE_ORCHID_LADY_SLIPPER_DEF")
    elseif HerbID == 24 then
        return joaat("COMPOSITE_LOOTABLE_ORCHID_MOCCASIN_DEF")
    elseif HerbID == 25 then
        return joaat("COMPOSITE_LOOTABLE_ORCHID_NIGHT_SCENTED_DEF")
    elseif HerbID == 30 then
        return joaat("COMPOSITE_LOOTABLE_ORCHID_QUEENS_DEF")
    elseif HerbID == 32 then
        return joaat("COMPOSITE_LOOTABLE_ORCHID_RAT_TAIL_DEF")
    elseif HerbID == 35 then
        return joaat("COMPOSITE_LOOTABLE_ORCHID_SPARROWS_DEF")
    elseif HerbID == 36 then
        return joaat("COMPOSITE_LOOTABLE_ORCHID_SPIDER_DEF")
		
	elseif HerbID == 44 then
        return -317883624
	elseif HerbID == 45 then
        return -834461873
	elseif HerbID == 46 then
        return -2015527411
	elseif HerbID == 47 then
        return -1697318509
	elseif HerbID == 48 then
        return -1490607613
	elseif HerbID == 49 then
        return 1175863601
	elseif HerbID == 50 then
        return 988637426
	elseif HerbID == 51 then
        return -1964504874
	elseif HerbID == 52 then
        return -2029085880
	elseif HerbID == 53 then
        return -204942356
	
    else
        return 0
    end
end
--]]

--exports('StartCreateComposite', StartCreateComposite)

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
	for key, value in pairs(Config.FullLootedScenarioPoint) do
		SetScenarioPointActive(Config.FullLootedScenarioPoint[key], true)
		Config.FullLootedScenarioPoint[key] = nil
	end
	ClearPedTasksImmediately(ped, true, true)
	PromptDelete(PickupPrompt)
end

RegisterNetEvent("rsg-composite:client:GetServerComposite")
AddEventHandler("rsg-composite:client:GetServerComposite", function(key, compositeTable)
	StartCreateComposite(compositeTable.HerbID, compositeTable.CompositeHash, compositeTable.PointCoords, compositeTable.PointHeading, compositeTable.F_4)
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
	print("Entities2 = " .. json.encode(Entities2))
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