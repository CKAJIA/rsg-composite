-- Independent spawner for tree egg-nest scenario points (WB_EGG_NEST_*).
-- The plant/composite scanner intentionally remains separate.

local activeTreeNests = {}
local pendingTreeEggPoints = {}
local maxScenarioPoints = math.max(1, Config.TreeEggs.maxScenarioPoints or 600)
-- Reserve slot 0 because the requested one-based iteration reads offsets 8, 16, ...
local scenarioBuffer = DataView.ArrayBuffer((maxScenarioPoints + 1) * 8)
local smallGameAmmoTypes = {}

for _, ammoType in ipairs(Config.TreeEggs.smallGameAmmoTypes or { 'ammo_arrow_small_game' }) do
    smallGameAmmoTypes[joaat(ammoType)] = true
end

RegisterNetEvent('rsg-composite:client:TreeEggGatherResult', function(success, pointKey, scenarioId, reason)
	if pointKey then
		pendingTreeEggPoints[pointKey] = nil
	end
    if not success then
        PrintDebug(('[tree-eggs] server rejected egg pickup (%s): %s'):format(tostring(pointKey), tostring(reason)))
        return
    end
	if not pointKey then return end

    Config.FullLootedScenarioPoint[pointKey] = scenarioId
    if scenarioId and DoesScenarioPointExist(scenarioId) and IsScenarioPointActive(scenarioId) then
        SetScenarioPointActive(scenarioId, false)
    end
end)

local function logTreeEgg(message)
    PrintDebug(('[tree-eggs] %s'):format(message))
end

local function loadModel(model)
    local modelHash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then
        return nil
    end

    RequestModel(modelHash)
    local timeoutAt = GetGameTimer() + 10000
    while not HasModelLoaded(modelHash) and GetGameTimer() < timeoutAt do
        Wait(0)
    end

    if not HasModelLoaded(modelHash) then
        SetModelAsNoLongerNeeded(modelHash)
        return nil
    end

    return modelHash
end

local function registerTreeEggForEagleEye(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return false
    end
	
	Citizen.InvokeNative(0x7563CBCA99253D1A, entity, `BLIP_MP_ROLE_COLLECTOR_ILO`)

    local tint = Config.EagleEyeTint or { r = 255.0, g = 255.0, b = 0.0 }
    return RegisterEntityForEagleEye(entity, tint)
end

local function unregisterTreeEggForEagleEye(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return
    end

    UnregisterEntityForEagleEye(entity)
end

function RemoveTreeNest(scenarioId)
    local nestData = activeTreeNests[scenarioId]
    if not nestData then
        return
    end

    for _, eggData in ipairs(nestData.eggs) do
        if eggData.entity and DoesEntityExist(eggData.entity) then
            if eggData.eagleEyeRegistered then
                unregisterTreeEggForEagleEye(eggData.entity)
            end
            DeleteObject(eggData.entity)
        end
    end

    if nestData.nest and DoesEntityExist(nestData.nest) then
        DeleteObject(nestData.nest)
    end

    activeTreeNests[scenarioId] = nil
end

local function createTreeNest(scenarioId, speciesKey, scenarioCoords)
    local species = Config.TreeEggs.species[speciesKey]
    if not species then
        return false
    end

    local nestModel = loadModel(species.nestModel)
    if not nestModel then
        logTreeEgg(('nest model failed to load (%s)'):format(speciesKey))
        return false
    end

    local eggModel = loadModel(species.eggModel)
    if not eggModel then
        SetModelAsNoLongerNeeded(nestModel)
        logTreeEgg(('egg model failed to load (%s)'):format(speciesKey))
        return false
    end

    -- The original net_bird_egg_* scripts create the nest at the scenario point.
    -- They do not apply scenario heading to the nest prop.
    local nest = CreateObjectNoOffset(
        nestModel, scenarioCoords.x, scenarioCoords.y, scenarioCoords.z,
        false, true, false, true
    )
    SetModelAsNoLongerNeeded(nestModel)

    if not nest or nest == 0 or not DoesEntityExist(nest) then
        SetModelAsNoLongerNeeded(eggModel)
        logTreeEgg(('failed to create nest (%s)'):format(speciesKey))
        return false
    end

    SetEntityAsMissionEntity(nest, true, true)

    local offset = Config.TreeEggs.eggOffset or vector3(0.0, 0.0, 0.12)
    local rotation = Config.TreeEggs.eggRotation or vector3(0.0, 0.0, 0.0)
    local eggPosition = GetOffsetFromEntityInWorldCoords(nest, offset.x, offset.y, offset.z)
    local egg = CreateObjectNoOffset(eggModel, eggPosition.x, eggPosition.y, eggPosition.z, false, false, false, true)
    SetModelAsNoLongerNeeded(eggModel)

    local eggs = {}
    if egg and egg ~= 0 and DoesEntityExist(egg) then
        SetEntityAsMissionEntity(egg, true, true)
        SetEntityCanBeDamaged(egg, true)
        AttachEntityToEntity(egg, nest, 0, offset.x, offset.y, offset.z, rotation.x, rotation.y, rotation.z, false, false, false, false, 2, true, false, false)
        local eggEagleEyeRegistered = registerTreeEggForEagleEye(egg)
        eggs[1] = {
            entity = egg,
            hitHandled = false,
            fallen = false,
            eagleEyeRegistered = eggEagleEyeRegistered,
        }
    end

    if #eggs == 0 then
        DeleteObject(nest)
        logTreeEgg(('failed to create egg (%s)'):format(speciesKey))
        return false
    end

    activeTreeNests[scenarioId] = {
        nest = nest,
        speciesKey = speciesKey,
        coords = scenarioCoords,
        eggs = eggs,
    }
    PrintDebug(('[tree-eggs] spawned %s nest at %.2f %.2f %.2f'):format(speciesKey, scenarioCoords.x, scenarioCoords.y, scenarioCoords.z))
    return true
end

local function currentAmmoType(ped)
    -- These are the same RedM natives used by the original net_bird_egg_* scripts.
    local weaponObject = Citizen.InvokeNative(0x6CA484C9A7377E4F, ped, true, Citizen.ResultAsInteger())
    if not weaponObject or weaponObject == 0 then
        return 0
    end
    return Citizen.InvokeNative(0x7E7B19A4355FEE13, ped, weaponObject)
end

local function handleNestHit(nestData, eggData, ped)
    if eggData.hitHandled then
        return
    end

    eggData.hitHandled = true
    local hitAmmo = currentAmmoType(ped)

    if not hitAmmo or hitAmmo == 0 then
        -- Ignore melee/other non-ammunition damage.
        eggData.hitHandled = false
        return
    end

    if smallGameAmmoTypes[hitAmmo] then
        if eggData.entity and DoesEntityExist(eggData.entity) then
            DetachEntity(eggData.entity, true, true)
            ActivatePhysics(eggData.entity)
            Citizen.InvokeNative(0x78B4567E18B54480, eggData.entity)
            eggData.fallen = true
        end
        PrintDebug(('[tree-eggs] small-game hit: egg fell (%s)'):format(nestData.speciesKey))
        return
    end

    if eggData.entity and DoesEntityExist(eggData.entity) then
        if eggData.eagleEyeRegistered then
            unregisterTreeEggForEagleEye(eggData.entity)
            eggData.eagleEyeRegistered = false
        end
        DeleteObject(eggData.entity)
    end
    eggData.entity = nil
    PrintDebug(('[tree-eggs] non-small-game hit: egg broken (%s)'):format(nestData.speciesKey))
end

local function checkHits()
    local ped = PlayerPedId()
    if not ped or ped == 0 then
        return
    end

    for _, nestData in pairs(activeTreeNests) do
        local nestHit = nestData.nest and DoesEntityExist(nestData.nest)
            and HasEntityBeenDamagedByEntity(nestData.nest, ped, true, true)

        for _, eggData in ipairs(nestData.eggs) do
            local eggHit = eggData.entity and DoesEntityExist(eggData.entity)
                and HasEntityBeenDamagedByEntity(eggData.entity, ped, true, true)
            if not eggData.hitHandled and (nestHit or eggHit) then
                handleNestHit(nestData, eggData, ped)
            end
        end
    end
end

local function getTreeEggSpeciesByModel(model)
    if not model or model == 0 then
        return nil
    end

    for speciesKey, species in pairs(Config.TreeEggs.species) do
        local eggModel = type(species.eggModel) == 'number' and species.eggModel or joaat(species.eggModel)
        if eggModel == model then
            return speciesKey
        end
    end
    return nil
end

-- Called from EVENT_LOOT_COMPLETE. The event target entity is the egg prop
-- that was actually picked up; its model maps to the inventory item.
function HandleTreeEggLootComplete(initiator, targetEntity, targetModel, lootSuccess)
	if initiator ~= PlayerPedId() or not lootSuccess or not targetEntity or targetEntity == 0 then
        return false
    end
	
    local speciesKey = getTreeEggSpeciesByModel(targetModel)
    if not speciesKey then
        return false
    end

    if not DoesEntityExist(targetEntity) then
        return false
    end

    for scenarioId, nestData in pairs(activeTreeNests) do
        for _, eggData in ipairs(nestData.eggs) do
            if eggData.entity == targetEntity and nestData.speciesKey == speciesKey then
                local pointKey = KeyFromCoords(nestData.coords)
                if pendingTreeEggPoints[pointKey] or Config.FullLootedScenarioPoint[pointKey] then
                    return true
                end

                pendingTreeEggPoints[pointKey] = true
                RemoveTreeNest(scenarioId)
                TriggerServerEvent('rsg-composite:server:GatherTreeEgg', pointKey, scenarioId, targetModel)
                return true
            end
        end
    end

    return false
end

local function scanTreeNests()
    local ped = PlayerPedId()
    if not ped or ped == 0 then
        return
    end

    local playerCoords = GetEntityCoords(ped)
    local foundCount = GetScenarioPointsInArea(
        playerCoords.x, playerCoords.y, playerCoords.z,
        Config.TreeEggs.scanRadius or 100.0,
        scenarioBuffer:Buffer(), maxScenarioPoints
    ) or 0
    local count = math.min(foundCount, maxScenarioPoints)

    for i = 1, count, 1 do
        local scenarioId = scenarioBuffer:GetInt32(i * 8)
        if scenarioId and scenarioId ~= 0 and not activeTreeNests[scenarioId]
            and DoesScenarioPointExist(scenarioId) and IsScenarioPointActive(scenarioId) then
            local speciesKey = Config.TreeEggs.scenarioTypes[GetScenarioPointType(scenarioId)]
            if speciesKey then
                local coords = GetScenarioPointCoords(scenarioId, true)
                local pointKey = KeyFromCoords(coords)
                if Config.FullLootedScenarioPoint[pointKey] then
                    if IsScenarioPointActive(scenarioId) then
                        SetScenarioPointActive(scenarioId, false)
                    end
                elseif not pendingTreeEggPoints[pointKey] then
					if #(coords - playerCoords) <= (Config.TreeEggs.scanRadius or 100.0) then
						createTreeNest(scenarioId, speciesKey, coords)
					end
                end
            end
        end
    end

    local despawnDistance = Config.TreeEggs.despawnDistance or 175.0
    for scenarioId, nestData in pairs(activeTreeNests) do
        if #(nestData.coords - playerCoords) > despawnDistance then
            RemoveTreeNest(scenarioId)
        end
    end
end

CreateThread(function()
    while true do
		local enabled = playerSpawn and Config.EnableTreeEggs
        
		if not enabled then
			Wait(10000)
		else
			scanTreeNests()
			Wait(Config.TreeEggs.scanIntervalMs or 2000)
		end
    end
end)

CreateThread(function()
    while true do
		local enabled = playerSpawn and Config.EnableTreeEggs
		
        if not enabled then
            Wait(10000)
        else
            checkHits()
            Wait(0)
        end
    end
end)

-- Очистка гнёзд. Вызывается из client.lua: при RSGCore:Client:OnPlayerUnload
-- и при onResourceStop (там же обрабатываются и остальные lifecycle-события ресурса).
function TreeEggsReset()
    if Config.EnableTreeEggs then
		pendingTreeEggPoints = {}
		for scenarioId in pairs(activeTreeNests) do
			RemoveTreeNest(scenarioId)
		end
	end
end

