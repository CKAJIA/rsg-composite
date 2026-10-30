local RSGCore = exports['rsg-core']:GetCoreObject()
 
-- playerSpawn - глобальная переменная, объявлена и управляется из client.lua.
local Composite = {}
local RegisteredEagleEyeEntities = {}
local DELETE_DISTANCE = 2000.0
local NEARBY_DISTANCE = 150.0
local EMERGENCY_DESPAWN_DISTANCE = 625.0
local MAX_SPAWN_COMPOSITE = 179
local MAX_RECORD_IN_TABLE = 500 --на самом деле 500 точек держится в таблице.
local isBusy = false
local isPickUp = false
 
-- Registration lets the game show Eagle Eye clues when appropriate; this
-- resource does not need to poll the player's Eagle Eye state or create PTFX.
function RegisterEntityForEagleEye(entity, tint)
	if not entity or entity == 0 or not DoesEntityExist(entity) then
		return false
	end
	
	if not Citizen.InvokeNative(0x0E6846476906C9DD, PlayerId(), entity) then --_IS_EAGLE_EYE_REGISTERED_FOR_ENTITY
		Citizen.InvokeNative(0x543DFE14BE720027, PlayerId(), entity, false) --_REGISTER_EAGLE_EYE_FOR_ENTITY
		Citizen.InvokeNative(0x6ECFC621A168424C, entity, entity, 0, 0) --_EAGLE_EYE_ADD_PARTICLE_EFFECT_TO_ENTITY
		--Citizen.InvokeNative(0x907B16B3834C69E2, entity, 75.0) --_EAGLE_EYE_SET_CUSTOM_DISTANCE
	
		if tint then
			EagleEyeSetCustomEntityTint(entity, tint.r, tint.g, tint.b)
		end
	end
	
	return true
end
 
function UnregisterEntityForEagleEye(entity)
	if not entity or entity == 0 or not DoesEntityExist(entity) then
		return
	end
 
	Citizen.InvokeNative(0x9DAE1380CC5C6451, PlayerId(), entity) --_UNREGISTER_EAGLE_EYE_FOR_ENTITY
	Citizen.InvokeNative(0xDC5E09D012D759C4, entity, entity, 0) --_EAGLE_EYE_REMOVE_PARTICLE_EFFECT_FROM_ENTITY
end
 
local function RegisterCompositeEagleEye(pointKey, entity, tint)
	if not entity or entity == 0 or not DoesEntityExist(entity) then
		return
	end
 
	local registered = RegisteredEagleEyeEntities[pointKey]
	if not registered then
		registered = {}
		RegisteredEagleEyeEntities[pointKey] = registered
	end
	if registered[entity] then
		if tint then EagleEyeSetCustomEntityTint(entity, tint.r, tint.g, tint.b) end
		return
	end
	for oldEntity in pairs(registered) do
		UnregisterEntityForEagleEye(oldEntity)
		registered[oldEntity] = nil
	end
 
	if RegisterEntityForEagleEye(entity, tint) then
		registered[entity] = true
	end
end
 
local function UnregisterCompositeEagleEye(pointKey)
	local registered = RegisteredEagleEyeEntities[pointKey]
	if not registered then return end
	for entity in pairs(registered) do
		UnregisterEntityForEagleEye(entity)
	end
	RegisteredEagleEyeEntities[pointKey] = nil
end
 
-- ID ресурса сопоставлены по названиям растений с оригинальным herb.ysc.c.
-- Orchid tree composites используют groundSetting=2 и отдельное смещение от scenario.
local TREE_ORCHID_OFFSETS = {
	[1] = vector3(0.0, 0.737008, 1.81999), -- Acuna's Star
	[9] = vector3(0.0, 0.737008, 1.81999), -- Cigar
	[10] = vector3(0.0, 0.737008, 1.81999), -- Clamshell
	[17] = vector3(0.0, 0.737008, 1.81999), -- Ghost
	[21] = vector3(0.0, 0.737008, 1.81999), -- Lady of the Night
	[25] = vector3(0.0, 0.737008, 1.81999), -- Night Scented
	[32] = vector3(0.0, 0.737008, 1.81999), -- Rat Tail
	[36] = vector3(0.0, 0.737008, 1.81999), -- Spider
	[37] = vector3(0.0, 0.5, 1.81999), -- Vanilla Flower
}
 
local compositePointCol = 0
local spawnCompositeNum = 0 --на случай если слишком много заспавнено и не очистилось
 
--нужно вычислить какой ресурс не дает спавнить все композиты.
--для вычитания ресурсов - надо отключить эту функцию и смотреть дойдет ли до 180
--и включить дебаг
function checkRecordAndClear(playerPosition)
	local playerPos = playerPosition.xy
	
	-- Режим 1: Emergency - если критично много точек
	if compositePointCol > MAX_RECORD_IN_TABLE then		
		for key, value in pairs(Composite) do
			local dist = #(playerPos - key)
			if dist > DELETE_DISTANCE then --должна быть больше чем радиус спавна и радиус скрытия заспавненых которые в таблице
				--print("Delete point = " .. key)
				deleteComposite(key, value.CompositeId, value.VegModifierHandle, value.Entitys)
				Composite[key] = nil
				compositePointCol = compositePointCol - 1
				if compositePointCol < 0 then compositePointCol = 0	end
			end
		end
	end
	
	-- Режим 2: Normal - деспаун дальних
	if spawnCompositeNum > 0 then
		for key, value in pairs(Composite) do
			local dist = #(playerPos - key)--150.0
			if dist > NEARBY_DISTANCE and value.PointSpawn then --должна быть больше чем радиус спавна и и меньше чем радиус для удаления из таблицы
				deleteComposite(key, value.CompositeId, value.VegModifierHandle, value.Entitys)
				--проверяем если еще есть composite на точке не собранные- то просто обнуляем
				--а если все собрали то удаляем запись
				if not HerbsRemains(key) then --Это наверное не надо потомучто мы при сборе итак проверяем. Если только как доп проверку.
					Composite[key] = nil--убираем запись.
					compositePointCol = compositePointCol - 1
					if compositePointCol < 0 then compositePointCol = 0	end
					PrintDebug("No more composite in point. Delete record in Composite")
				else				
					Composite[key].CompositeId = {}
					Composite[key].VegModifierHandle = {}
					Composite[key].PointSpawn = false
					PrintDebug("Despawn point = " .. key)
				end
				
			end
		end
		PrintDebug("Spawn composite num = " .. tostring(spawnCompositeNum))
	end
 
	--Экстренный деспавн если слишком много заспавненых composite
	--максимум можно показать сразу 180 composite
	if spawnCompositeNum >= MAX_SPAWN_COMPOSITE then
		for key, value in pairs(Composite) do
			local dist = #(playerPos - key)
			if dist >= EMERGENCY_DESPAWN_DISTANCE then --должна быть больше чем радиус спавна и и меньше чем радиус для удаления из таблицы
				PrintDebug("Emergency Despawn point = " .. tostring(key))
				deleteComposite(key, value.CompositeId, value.VegModifierHandle, value.Entitys)
				Composite[key].CompositeId = {}
				Composite[key].VegModifierHandle = {}
				Composite[key].PointSpawn = false
			end
		end
	end
	
	PrintDebug("Spawn composite num = " .. tostring(spawnCompositeNum))
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
	--local playerPosition = GetEntityCoords(PlayerPedId())
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
		return
	end	
	
	--тут очистка не нужна иначе слишком часто вызывается
	--checkRecordAndClear(playerPosition)
	
	-- Днём ночные растения не создаём.
	-- Уже созданные точки остаются до обычного деспавна.
	local HOURS = GetClockHours()
	if HOURS >= 5 and HOURS < 22 and Config.Composites[HerbID].spawn.isNightHerb then
		return
	end
	
	-- Если записи нет в Composite, создаем её
	if not Composite[pointCoords.xy] then
		Composite[pointCoords.xy] = {HerbID = HerbID, CompositeHash = compositeHash,
            PointSpawn = false, CompositeId = {}, PackedSlots = packedSlots, HerbCoords = {},
            VegModifierHandle = {}, AttachEntity = nil, Entitys = {}, GroupPromt = nil, PickupPrompt = nil
        }
		compositePointCol = compositePointCol + 1
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
	
	if HerbID ~= 0 and haveRecord == false then
		--print("First Spawn")
		-- Первоначальный спаун растений
		herbCoords = CreateHerbsCoords(pointCoords, packedSlots, HerbID)
		Composite[pointCoords.xy].HerbCoords = herbCoords
		spawnCompositeEntities(compositeHash, herbCoords, sHeading, HerbID, packedSlots, pointCoords)
	elseif HerbID ~= 0 and haveRecord == true and Composite[pointCoords.xy].PointSpawn == false then--проверка на заспавненую точку
		--print("Second Spawn")
		-- Повторный спаун
		spawnCompositeEntities(compositeHash, herbCoords, sHeading, HerbID, packedSlots, pointCoords)
	elseif HerbID == 0 or HerbID == nil then
		print("No HerbID for " .. compositeHash)
	end	
end
 
-- Функция для спауна композитных объектов
function spawnCompositeEntities(compositeHash, herbCoords, sHeading, HerbID, packedSlots, pointCoords)
    local record = Composite[pointCoords.xy]
    if not record or record.Spawning then return end
    record.Spawning = true

    -- Загрузка ассета делает Wait: повторный вызов не должен создавать второй
    -- объект в том же слоте и перезаписывать единственный сохранённый handle.
	-- xpcall - перехватывает ошибки спавна, чтобы после них сбросить флаг Spawning
	-- и не заблокировать повторный спавн точки. debug.traceback покажет место ошибки.
    local ok, err = xpcall(function() --для безопасного вызова чтобы в случае ошибки выполнение не прервалось с ошибкой
        for index = 1, #packedSlots do
            local existingId = record.CompositeId[index]
            if packedSlots[index] ~= nil and (not existingId or existingId <= 0) then
                if spawnCompositeNum >= MAX_SPAWN_COMPOSITE then
                    PrintDebug(("Composite cap reached (%d/%d); skipped remaining slots for HerbID %s"):format(spawnCompositeNum, MAX_SPAWN_COMPOSITE, HerbID))
                    break
                end
                if not RequestAndWaitForComposite(compositeHash) then
                    PrintDebug(("Composite asset did not load: %s"):format(tostring(compositeHash)))
                    break
                end
                if Composite[pointCoords.xy] ~= record then return end
                CreateComposite(index, compositeHash, herbCoords, sHeading, HerbID, pointCoords)
            end
        end
    end, debug.traceback)
    record.Spawning = false
    if not ok then
        print(("[rsg-composite] Spawn setup failed | HerbID=%s | point=%s | %s"):format(
            tostring(HerbID), tostring(pointCoords.xy), tostring(err)))
    end
end
 
--запуск спавна точки из client
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
	elseif Composite[pointCoords.xy].PointSpawn == false then --если точка есть в локальной теблице- переспавниваем
		StartCreateComposite(Composite[pointCoords.xy].HerbID, Composite[pointCoords.xy].CompositeHash, pointCoords, pointHeading, Composite[pointCoords.xy].PackedSlots)
	end
end
 
function CreatePrompts()
	local str = CreateVarString(10, 'LITERAL_STRING', Config.PromtName)
	local PickupPrompt = PromptRegisterBegin()
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
 
	maxSlots = math.min(maxSlots, 4)
	minSlots = math.max(1, math.min(minSlots, maxSlots))
	slotCount = math.random(minSlots, maxSlots)
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
 
function CreateHerbsCoords(ScenarioPointCoords, packedSlots, HerbID)
	local herbCoords = {}
 
    for index = 1, 4 do
        local Offset, Rotation, variant = GetRotationOffset(index, packedSlots)
		
		if packedSlots[index] ~= nil then
				local angle = math.rad(Rotation)
			local x = ScenarioPointCoords.x + (Offset * math.cos(angle))
			local y = ScenarioPointCoords.y + (Offset * math.sin(angle))
			local z = ScenarioPointCoords.z
			herbCoords[index] = vector3(x, y, z)
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
 
function CreateComposite(index, compositeHash, herbCoords, Heading, HerbID, pointCoords)
	local record = Composite[pointCoords.xy]
	if not record or index > 4 or isVectorEmpty(herbCoords[index]) then return end
	if spawnCompositeNum >= MAX_SPAWN_COMPOSITE then return end

	local onGround = 0
	local treeOrchidOffset = TREE_ORCHID_OFFSETS[HerbID]
	if treeOrchidOffset then
		onGround = 2
		local offsetHeading = correctHeading(Heading)
		herbCoords[index] = herbCoords[index] + correctCoords(treeOrchidOffset, offsetHeading)
	end
	-- Tree orchids must keep the scenario heading: rotating them can push the
	-- model into the trunk. The original loop is zero-based; Lua slot 1 maps to 0.
	local compositeHeading = correctHeading(Heading)
	if not treeOrchidOffset then
		compositeHeading = correctHeading(Heading + ((index - 1) * math.random(0, 90)))
	end

	local compositeId = exports["rsg-composite"]:NativeCreateComposite(compositeHash, herbCoords[index].x, herbCoords[index].y, herbCoords[index].z, compositeHeading, onGround, -1)
	--если глючный composite - то удаляем его сразу(обычно начинает если уже больше 180 заспавнено.)
	if not compositeId or compositeId <= 0 then
		print(("ERROR: composite create failed | id=%s | herbID=%s | hash=%s | active=%s/%s | herbCoords=vec3(%.2f, %.2f, %.2f)"):format(
			tostring(compositeId), tostring(HerbID), tostring(compositeHash),
			tostring(spawnCompositeNum), tostring(MAX_SPAWN_COMPOSITE),
			herbCoords[index].x, herbCoords[index].y, herbCoords[index].z))
		return
	end
	if Composite[pointCoords.xy] ~= record then
		NativeDeleteComposite(compositeId)
		return
	end

	-- Всё состояние слота записывается здесь, до настройки промптов/подсветки.
	-- Если настройка завершится ошибкой, деспаун найдёт созданный объект.
	record.CompositeId[index] = compositeId
	record.VegModifierHandle[index] = 0
	record.PointSpawn = true
	spawnCompositeNum = spawnCompositeNum + 1
	PrintDebug(("[Composite] TRACKED HerbID=%s slot=%s id=%s point=%s"):format(
		tostring(HerbID), tostring(index), tostring(compositeId), tostring(pointCoords.xy)))
		
	--получаем все Entitys у композита чтобы потом его можно было найти в ивенте
	--print(compositeId, json.encode(GetHerbCompositeNumEntities(compositeId, 25)))
	
	--print(compositeId, json.encode(GetHerbCompositeNumEntities2(herbCoords[index], 10.0)))

	if HerbID == 61 then --для лука
		record.VegModifierHandle[index] = AddVegModifierSphere(herbCoords[index], 0.35, 2, 314, 0)
	elseif isMushroom(HerbID) then --для грибов
		record.VegModifierHandle[index] = AddVegModifierSphere(herbCoords[index], 0.37, 4, 27, 0)
	elseif HerbID == 38 then --Фиолетовый подснежник
		record.VegModifierHandle[index] = AddVegModifierSphere(herbCoords[index], 0.15, 4, -1, 0)
	elseif index == 1 and isEggs(HerbID) then --для яиц
		record.VegModifierHandle[index] = AddVegModifierSphere(herbCoords[index], 0.75, 1, 511, 0)
	end
	if index == 1 then
		RareHerbs(HerbID, herbCoords[index], pointCoords)
		SPHerbs(HerbID, herbCoords[index], pointCoords)
		local spawnConfig = Config.Composites[HerbID].spawn
		if isEggs(HerbID) or (spawnConfig and spawnConfig.isUnique) then
			local tint = spawnConfig and spawnConfig.eagleEyeTint or Config.EagleEyeTint or {r = 255.0, g = 255.0, b = 0.0}
			RegisterCompositeEagleEye(pointCoords.xy, record.AttachEntity, tint)
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
			local compositeHandle = compositeId[i]
			NativeDeleteComposite(compositeHandle)
			if compositeHandle > 0 then
				spawnCompositeNum = math.max(0, spawnCompositeNum - 1)
			end
			compositeId[i] = 0
			
			PrintDebug(("Delete composite | spawnCompositeNum=%s | point=%s"):format(
					tostring(spawnCompositeNum),
					tostring(coordsXY)))
		end
	end
	
	for i = 1, 4 do
		if vegModifierHandle[i] and vegModifierHandle[i] ~= 0 then
			RemoveVegModifierSphere(vegModifierHandle[i], 1)
			vegModifierHandle[i] = 0
		end
	end
	--удаляем композит от орхидей
	--потому что они состоят из 2 entity
	if entitys then
		for _, value in ipairs(entitys) do
			if value and DoesEntityExist(value) then
				--SetEntityAsMissionEntity(value, true, true)
				SetEntityAsNoLongerNeeded(value)
				DeleteEntity(value)
			end
		end
	end
	
	DeletePromptAndGroup(coordsXY)
	if Composite[coordsXY] then
		Composite[coordsXY].Entitys = {} 
		Composite[coordsXY].AttachEntity = nil
	end
		
	
	--compositePointCol = compositePointCol - 1
	--if compositePointCol < 0 then compositePointCol = 0	end
end
 
function DeleteSound(coordsXY)
	local record = Composite[coordsXY]
	if not record or not record.SoundId then return end

	stopSound(record.SoundId)
	record.SoundId = nil
end
 
function DeleteEffect(coordsXY)
	UnregisterCompositeEagleEye(coordsXY)
end
 
function playSound(pointCoords)--звук рядом с коллекционными предметами спавнить когда расстояние меньше 10.0
	local key = pointCoords.xy
	local record = Composite[key]
	if not record or not record.PointSpawn or record.SoundId or record.SoundLoading then return end
	record.SoundLoading = true
	
	local loaded = PrepareSoundset("RDRO_Collectible_Sounds_Travelling_Saleswoman", 0)
	local i = 0
	while not loaded and i < 100 do
		i = i + 1
		Wait(0)
		loaded = PrepareSoundset("RDRO_Collectible_Sounds_Travelling_Saleswoman", 0)
	end
	record.SoundLoading = false
	
	-- Wait может завершиться после удаления точки, сбора или выгрузки игрока.
	if not loaded or Composite[key] ~= record or not playerSpawn or not record.PointSpawn
		or Config.FullLootedScenarioPoint[KeyFromCoords(key)] then return end
	if #(GetEntityCoords(PlayerPedId()).xy - key) > 20.0 then return end

	local soundID = GetSoundId(Citizen.ResultAsInteger())
	if soundID and soundID > 0 then
		PlaySoundFromPositionWithId(soundID, "collectible_lure", pointCoords, "RDRO_Collectible_Sounds_Travelling_Saleswoman", 0, 0, true)
		record.SoundId = soundID
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
		-- The composite's highlighted object is in slot 2 when present; register
		-- one entity per point so a single plant cannot get duplicate clues.
		local targetEntity = foundEntities[2] or foundEntities[1]
		if targetEntity and DoesEntityExist(targetEntity) then
			Composite[pointCoords.xy].AttachEntity = targetEntity
			if HerbID == 44 then
				Citizen.InvokeNative(0x7563CBCA99253D1A, targetEntity, `BLIP_MP_ROLE_NATURALIST`) --SetBlipIconToLockonEntityPrompt(entity, blipIcon)
			else
				Citizen.InvokeNative(0x7563CBCA99253D1A, targetEntity, `BLIP_MP_ROLE_COLLECTOR_ILO`)
			end
		end
	end
end
 
CreateThread(function()
    while true do
		if playerSpawn then
			local playerPosition = GetEntityCoords(PlayerPedId())
			local scenarios = getLootScenarioHash(playerPosition, 25.0, 100)
			local sleep = 1000
			if scenarios and #scenarios > 0 then
				for _, scenarioData in ipairs(scenarios) do
					local HerbID = scenarioData.herbsScenarioPoint.HerbID
					local pointCoords = GetScenarioPointCoords(scenarioData.scenario, true)
					local key = KeyFromCoords(pointCoords.xy)
					local coordsXY = pointCoords.xy
					local distance = #(playerPosition.xy - coordsXY)
					local record = Composite[coordsXY]						 
					if record and not Config.FullLootedScenarioPoint[key] then
						if isSPHerbs(HerbID) then
							if distance <= 2.0 then
								--Если включена автоэкипировка ножа и у нас нет экипированого ножа- то нож экипируется
								--пока нет ножа то у некоторых орхидей нет промпт
								equipKnife(HerbID)

								local prompt = Composite[coordsXY].PickupPrompt
								
								PicUpOrchid(pointCoords, prompt, HerbID)
								if prompt then
									sleep = 100
								end
							end
						end
						--elseif isRareHerbs(HerbID) or isEggs(HerbID) then
						local herbCfg = Config.Composites[HerbID]
						if herbCfg and herbCfg.spawn and herbCfg.spawn.isUnique then
							if distance <= 20.0 and not record.SoundId then
								playSound(pointCoords)
							elseif distance > 20.0 and record.SoundId then
								DeleteSound(coordsXY)
							end					
						end
					--если точка залутана и есть запись со звуком - удаляем звук
					elseif record and Config.FullLootedScenarioPoint[key] then
						DeleteSound(coordsXY)
					end
				end
			end
			--отключение звука при тп.
			for pointCoords, record in pairs(Composite) do
				if record.SoundId and #(playerPosition.xy - pointCoords) > 20.0 then
					DeleteSound(pointCoords)
				end
			end
			Wait(sleep)
		else
			Wait(1000)
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
	local record = Composite[pointCoords]
	if record and record.PickupPrompt then
		if PromptIsValid(record.PickupPrompt) then
			PromptRemoveGroup(record.PickupPrompt, record.GroupPromt)
			PromptDelete(record.PickupPrompt)
		end
		record.GroupPromt = nil
		record.PickupPrompt = nil
	end
end

function PicUpOrchid(pointCoords, pickupPrompt, HerbID)
	if isPickUp or not pickupPrompt or not PromptIsValid(pickupPrompt) then return end
	if PromptHasHoldModeCompleted(pickupPrompt) then		
		local PlayerPed = PlayerPedId()
		local comp = Composite[pointCoords.xy]
		if not comp then return end
		local entity = comp.AttachEntity
		if not entity or not DoesEntityExist(entity) then return end
		isPickUp = true --именно после проверки entity
		--print("Нажали")
		local picking = true
		
		local ok, err = xpcall(function()
			local pickTime = getPickupTime(HerbID)
			--удаляем prompt
			DeletePromptAndGroup(pointCoords.xy)
			
			CreateThread(function()
				while picking do
					local ped = PlayerId()
					-- Отключаем орлиный глаз (может быть и не нужно, если уже отключено выше)
					Citizen.InvokeNative(0x64FF4BF9AF59E139, ped, true) -- _SECONDARY_SPECIAL_ABILITY_SET_DISABLED
					Citizen.InvokeNative(0xC0B21F235C02139C, ped) -- _SPECIAL_ABILITY_SET_EAGLE_EYE_DISABLED

					DisableControlAction(0, `INPUT_SECONDARY_SPECIAL_ABILITY_SECONDARY`, true)
					DisableControlAction(0, `INPUT_SPECIAL_ABILITY`, true)
					-- После возобновления сначала проверяется picking: завершённый сбор
					-- больше не отключит управление после общего сброса ниже.
					Wait(0)
				end
			end)

			local model = GetEntityModel(entity)
			local playerPosition = GetEntityCoords(PlayerPed)
			TaskLootEntity(PlayerPed, entity)
			comp.AttachEntity = nil

			Wait(pickTime * 1000)
			ClearPedTasks(PlayerPed)
			ClearPedSecondaryTask(PlayerPed)

			-- Если игровое событие уже обработало сбор, повторный поиск не нужен.
			if not isVectorEmpty(comp.HerbCoords[1]) then
				FindPicupCompositeAndCoords(playerPosition, model, true)
			end
		end, debug.traceback)

		-- Выполняется и при успехе, и после ошибки внутри xpcall.
		-- Флаги сбрасываем до native-вызовов, чтобы не оставить блокировку сбора.
		picking = false
		isPickUp = false
		EnableControlAction(0, `INPUT_SECONDARY_SPECIAL_ABILITY_SECONDARY`, true)
		EnableControlAction(0, `INPUT_SPECIAL_ABILITY`, true)
		if not ok then
			print(('[rsg-composite] Ошибка сбора орхидеи HerbID=%s: %s'):format(tostring(HerbID), err))
		end
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
						break
					end
				end
			elseif isSPHerbsOneEntities(HerbID) and foundEntities[1] then
				attachEntity = foundEntities[1]
			end
			
			-- Фолбэк если не найден прикрепленный объект
			if not attachEntity and foundEntities[1] then
				attachEntity = foundEntities[1]
			end

			if DoesEntityExist(attachEntity) then
				Composite[pointCoords.xy].AttachEntity = attachEntity
				Composite[pointCoords.xy].Entitys = foundEntities
				
				-- Защита от дублирования: удаляем старый промпт, если он уже был
				if Composite[pointCoords.xy].PickupPrompt then
					DeletePromptAndGroup(pointCoords.xy)
				end
				
				--добавляем наш промпт к SP растению
				local groupPromt = UiPromptGetGroupIdForTargetEntity(attachEntity, Citizen.ResultAsInteger())
				local pickupPrompt = CreatePrompts()
				PromptsSetGroup(pickupPrompt, groupPromt)
				Composite[pointCoords.xy].GroupPromt = groupPromt
				Composite[pointCoords.xy].PickupPrompt = pickupPrompt
			else
				PrintDebug("ERROR: attachEntity not exist.")
			end
		end
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
 
function IsControlAlwaysPressed(inputGroup, control)
    return IsControlPressed(inputGroup, control) or IsDisabledControlPressed(inputGroup, control)
end
 
-- Пытается найти ближайший scenario/слот после лута и применить результат:
-- выдача награды/поедание + очистка слота + отключение точки если пусто.
function FindPicupCompositeAndCoords(pickupCoords, lootedModel, isPickup, lootSuccess)
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
        PrintDebug("FindPicupCompositeAndCoords: nearestScenario not found")
        return
    end
 
    if not slotIndex then
        PrintDebug("ERROR: No slotIndex for nearestScenario point")
        return
    end	
 
    -- 3) Работаем с записью композита
    local key = pointCoords.xy
    local comp = Composite[key]
    if not comp then
        PrintDebug("ERROR: Composite record missing for point")
        return
    end

    -- Цветок ванили собирается штатным промптом игры, который может сообщить false.
    -- Исключение разрешено только для подбора найденной нашей Цветок ванили.
    if lootSuccess == false then
        if not (isPickup and HerbID == 37) then return end
    end
	
	local nearestCompositeId = Composite[key].CompositeId[slotIndex]
 
    -- 4) Если уникальные — выключаем эффекты/звуки на точке
    if Config.Composites[HerbID].spawn.isUnique then
        comp.AttachEntity = nil
        DeleteEffect(key)
    end
    DeleteSound(key)
 
    -- 5) Серверная логика: pickup vs eat
    -- amount не передаётся - сервер сам решает сколько выдать по HerbID (GetCompositeData(HerbID).pickupAmount).
    if isPickup then
		--мы собрали
        TriggerServerEvent("rsg-composite:server:Gathered", HerbID)
		PrintDebug("Мы собрали: HerbID = " .. tostring(HerbID) .. " compositeIndex = " .. tostring(slotIndex) .. " nearestCompositeId = " .. tostring(nearestCompositeId))
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
        TriggerServerEvent("rsg-composite:server:SaveGatheredPoint", KeyFromCoords(key))
		PrintDebug("No more composite in point. Add record to Config.FullLootedScenarioPoint")
    end
end
 
function AreLootHerbIDsCompatible(modelHerbID, scenarioHerbID)
    if modelHerbID == scenarioHerbID then
        return true
    end 
	-- Обычный и одиночный лопух используют одну модель (она определяется как ID 7).
    if (modelHerbID == 7 or modelHerbID == 63) and (scenarioHerbID == 7 or scenarioHerbID == 63) then
        return true
    end
    -- The same world model/scenario can represent randomized alligator clutches
    -- with IDs 54–56, so compatibility must work in either argument order.
    local modelIsAlligatorEgg = modelHerbID >= 54 and modelHerbID <= 56
    local scenarioIsAlligatorEgg = scenarioHerbID >= 54 and scenarioHerbID <= 56
    return modelIsAlligatorEgg and scenarioIsAlligatorEgg
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
	-- Сравниваем позицию игрока со всеми живыми слотами всех совместимых точек.
	-- Выбор ближайшего scenario-centre первым мог ошибочно привязать сбор к
	-- соседней точке, если рядом стояли два одинаковых растения.
	for _, scenarioData in ipairs(scenarios) do
		local scenarioHerbID = scenarioData.herbsScenarioPoint.HerbID
		if AreLootHerbIDsCompatible(lootHerb, scenarioHerbID) then
			local pointCoords = GetScenarioPointCoords(scenarioData.scenario, true)
			local key = pointCoords.xy
			local comp = Composite[key]
			if comp and AreLootHerbIDsCompatible(comp.HerbID, scenarioHerbID) and comp.HerbCoords then
				for index, compositeCoords in ipairs(comp.HerbCoords) do
					local compositeId = comp.CompositeId and comp.CompositeId[index]
					if not isVectorEmpty(compositeCoords) and compositeId and compositeId ~= 0 then
						local dist = #(pickupCoords - compositeCoords)
						if dist < minDistance then
							minDistance = dist
							scenar = scenarioData.scenario
							pCoords = pointCoords
							herbId = comp.HerbID
							compositeIndex = index
						end
					end
				end
			end
		end
	end
	return scenar, pCoords, herbId, compositeIndex
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
    if isBusy then return end
	
	isBusy = true
	local playerPed = PlayerPedId()
	
	local ok, err = pcall(function()		
        SetCurrentPedWeapon(playerPed, joaat("weapon_unarmed"))
        Wait(100)
        if not IsPedOnMount(playerPed) and not IsPedInAnyVehicle(playerPed) then
			local dict = loadAnimDict('mech_inventory@eating@multi_bite@sphere_d8-4_fruit')
			-- Предмет уже списан сервером: при ошибке загрузки пропускаем только анимацию.
            if dict then
				TaskPlayAnim(playerPed, dict, 'quick_right_hand_throw', 5.0, 5.0, -1, 1, false, false, false)
			end
        end
        Wait(750)        
        Eating(herbID)
		TriggerServerEvent("rsg-composite:server:Eating", herbID)
		TriggerEvent("rsg-inventory:client:ItemBox", RSGCore.Shared.Items[itemName], "remove")
		if not Config.Composites[herbID].eat.isPoison then
			PlaySoundFrontend("Core_Full", "Consumption_Sounds", true, 0)
		end
	end)
	-- Общий сброс после успеха или ошибки. Снимаем блокировку до native очистки.
    isBusy = false
    if not ok then
        print(('[rsg-composite] Ошибка использования растения HerbID=%s: %s'):format(tostring(herbID), tostring(err)))
    end
    ClearPedTasks(playerPed)
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
	SetPlayerStamina(stamina)
 
	if stress ~= 0 then
		TriggerEvent('hud:client:UpdateStress', LocalPlayer.state.stress + stress)
	end
	if hunger ~= 0 then
		TriggerEvent('hud:client:UpdateHunger', LocalPlayer.state.hunger + hunger)
	end
	if thirst ~= 0 then
		TriggerEvent('hud:client:UpdateThirst', LocalPlayer.state.thirst + thirst)
	end
	if clean ~= 0 then
		TriggerEvent('hud:client:UpdateCleanliness', LocalPlayer.state.cleanliness + clean)
	end
end

local GET_CORE, SET_CORE, CHANGE_HEALTH, CHANGE_STAMINA = 0x36731AC041289BB1, 0xC6258F41D86676E0, 0x835F131E7DC8F97A, 0xC3D4B754C0E86B9E

function SetPlayerHealth(health)
    local player = PlayerPedId()
    if not health or health == 0 or not DoesEntityExist(player) or IsEntityDead(player) then return end

    local rest = health

    if rest > 0 then
        local core = Citizen.InvokeNative(GET_CORE, player, 0, Citizen.ResultAsInteger()) -- _GET_ATTRIBUTE_CORE_VALUE

        if core < 100 then
            local addCore = math.min(rest, 100 - core)
            local newCore = math.min(100, math.ceil(core + addCore))

            Citizen.InvokeNative(SET_CORE, player, 0, newCore) -- _SET_ATTRIBUTE_CORE_VALUE

            rest = rest - addCore
        end
    end

    if rest ~= 0 then
        -- Положительное значение: остаток лечения.
        -- Отрицательное значение: урон.
        Citizen.InvokeNative(CHANGE_HEALTH, player, rest + 0.0, 0, 0) -- _CHANGE_ENTITY_HEALTH
    end
end

function SetPlayerStamina(stamina)
    local ped = PlayerPedId()
    if not stamina or stamina == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) then return end

    local core = Citizen.InvokeNative(GET_CORE, ped, 1, Citizen.ResultAsInteger()) --_GET_ATTRIBUTE_CORE_VALUE

    if stamina > 0 then
        -- Сначала добиваем core до 100, остаток уходит в круг
        local toCore = math.max(0, math.min(stamina, 100 - core))
        if toCore > 0 then
			-- Core принимает целое число: округляем вверх, ограничиваем 100.
			Citizen.InvokeNative(SET_CORE, ped, 1, math.min(100, math.ceil(core + toCore))) --_SET_ATTRIBUTE_CORE_VALUE
		end
        if stamina > toCore then
			-- Остаток восстановления направляем в круг.
            -- + 0.0 преобразует аргумент в float для native.
			Citizen.InvokeNative(CHANGE_STAMINA, ped, stamina - toCore + 0.0) --_CHANGE_PED_STAMINA
		end
    else
        -- Сначала списываем из круга, остаток из core
        local cost     = -stamina
		-- Из круга снимаем не больше его текущего запаса.
        local fromRing = math.min(cost, math.max(0.0, GetPlayerStamina(PlayerId())))
        -- Всё, чего не хватило в круге, списываем из core.
        -- Например: расход 20, круг 7 → из core нужно снять 13.
		local fromCore = cost - fromRing
        if fromRing > 0 then
			-- Native передаём только расход из круга, в формате float.
			Citizen.InvokeNative(CHANGE_STAMINA, ped, -fromRing + 0.0) --_CHANGE_PED_STAMINA
		end
        if fromCore > 0 then
			-- После изменения круга явно устанавливаем рассчитанный core.
            -- Округляем вверх и не допускаем значения ниже 0.
			Citizen.InvokeNative(SET_CORE, ped, 1, math.max(0, math.ceil(core - fromCore))) --_SET_ATTRIBUTE_CORE_VALUE
		end
    end
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
		local playerPed = PlayerPedId()
		local knifeHash = joaat('weapon_melee_knife')
		if Config.AutoEquipKnife and not HasPedGotWeapon(playerPed, knifeHash, 0, true) then
			Citizen.InvokeNative(0x5E3BDDBCB83F3D84, playerPed, knifeHash, 0, false, true)
		end
	end
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
		 or HerbID == 63 or HerbID == 54 or HerbID == 55 or HerbID == 56 or HerbID == 57 or HerbID == 58 or HerbID == 59 or HerbID == 60 then
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
        return 54 -- gator eggs (54/55/56 share the same model; clutch size is resolved in ResolveEggScenario)
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
 
function RequestAndWaitForComposite(compositeHash)
    Citizen.InvokeNative(0x73F0D0327BFA0812, compositeHash)  -- request COMPOSITE
	
    local i = 1
    while not Citizen.InvokeNative(0x5E5D96BE25E9DF68,compositeHash) and i < 500 do  -- has COMPOSITE loaded
        i = i + 1
        Wait(0)
    end
    return Citizen.InvokeNative(0x5E5D96BE25E9DF68, compositeHash)
end
 
function AreCompositeLootableEntityDefAssetsLoaded(compositeHash)
	return Citizen.InvokeNative(0x5E5D96BE25E9DF68, compositeHash)
end
 
function RequestHerbCompositeAsset(compositeHash)
	return Citizen.InvokeNative(0x73F0D0327BFA0812, compositeHash, Citizen.ResultAsInteger())
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
 
-- Очистка композитов. Вызывается из client.lua: при RSGCore:Client:OnPlayerUnload
-- и при onResourceStop (там же обрабатываются и остальные lifecycle-события ресурса).
function ResetComposites()
	for key, value in pairs(Composite) do
		deleteComposite(key, value.CompositeId, value.VegModifierHandle, value.Entitys)
		
		Composite[key] = nil
	end
	for key, scenario in pairs(Config.FullLootedScenarioPoint) do
		local scenarioId = tonumber(scenario)
		if scenarioId and scenarioId ~= 0 and DoesScenarioPointExist(scenarioId) then
			SetScenarioPointActive(scenarioId, true)
		end
 
		Config.FullLootedScenarioPoint[key] = nil
	end
	-- Новая таблица также делает неактуальными старые ответы загрузки и циклы поиска.
	Config.FullLootedScenarioPoint = {}
	ClearPedTasksImmediately(PlayerPedId(), true, true)
	--PromptDelete(PickupPrompt)
	--PickupPrompt = nil
	
	compositePointCol = 0
	spawnCompositeNum = 0
	
	RegisteredEagleEyeEntities = {}
	Composite = {}
end
 
RegisterNetEvent("rsg-composite:client:GetServerComposite")
AddEventHandler("rsg-composite:client:GetServerComposite", function(key, compositeTable)
	StartCreateComposite(compositeTable.HerbID, compositeTable.CompositeHash, compositeTable.PointCoords, compositeTable.PointHeading, compositeTable.PackedSlots)
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
	PrintDebug("Entities2 = " .. json.encode(Entities2))
 
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
    if LoadTexture(_dict) then
		exports["rsg-composite"]:showAdvancedRightNotification(text, _dict, _icon, text_color or nil, duration or 2000, quality or 0, pick or 1)
	end
end)
 
function LoadTexture(dict)
	if DoesStreamedTextureDictExist(dict) then
		if not HasStreamedTextureDictLoaded(dict) then
			RequestStreamedTextureDict(dict, true)
			local timeout = GetGameTimer() + 1000
			while not HasStreamedTextureDictLoaded(dict) do
				if GetGameTimer() > timeout then
					return false
				end
				Wait(1)
			end	
		end
	end
	
	return true
end
--------------------------------------------------------------------------------
-------------------------------------NOTIFY-------------------------------------
--------------------------------------------------------------------------------
 