local activeHoles = {}
-- playerSpawn уже выставляется в true в client.lua только после того, как
-- Config.FullLootedScenarioPoint загружен с сервера, поэтому отдельный флаг
-- "данные загружены" здесь не нужен.


function GetHoleState(holeIndex)
    local state = activeHoles[holeIndex]

    if not state then
		local hole = Config.Crayfish.Holes[holeIndex]
        if not hole then return nil end

        local data = Config.Composites[200]
        local pointKey = KeyFromCoords(hole.coords)
		
        state = {
			key = pointKey,			
            limit = math.random(
                data.spawn.minCol or 1,
                data.spawn.maxCol or 3
            ),
            collected = 0,
            pending = false,
            exhausted = false,
			
			scenario = nil,
            crayfish = nil,
            pin = nil,
        }

        activeHoles[holeIndex] = state
    end
	
	-- Только проверка клиентского кэша, без обращения к серверу.
    if not state.exhausted
        and Config.FullLootedScenarioPoint
        and Config.FullLootedScenarioPoint[state.key] ~= nil then

        state.exhausted = true
        state.collected = state.limit
    end

    return state
end

local function GetNearbyHole(playerCoords)
    local nearest = nil
    local nearestDistance = Config.Crayfish.searchRadius or 100.0

    for index, hole in ipairs(Config.Crayfish.Holes) do
        local distance = #(playerCoords - hole.coords)

        if distance <= nearestDistance then
            nearestDistance = distance
            nearest = {
                index = index,
                hole = hole,
                distance = distance,
            }
        end
    end

    return nearest
end

local function CreateCrayfishAtHole(holeIndex)
	local state = GetHoleState(holeIndex)

    if state.exhausted or state.pending then return end
	
	local existingCrayfish = state.crayfish
	if existingCrayfish and DoesEntityExist(existingCrayfish) then
		return
	end
	state.crayfish = nil
	
    local hole = Config.Crayfish.Holes[holeIndex]
    if not hole then return end

	local retval, foundGround, normal = GetGroundZAndNormalFor_3dCoord(hole.coords.x, hole.coords.y, hole.coords.z)

    local groundZ = retval and foundGround or hole.coords.z
	
	local crayFishModel = Config.Crayfish.crayfishModel
	
	RequestModel(crayFishModel)
    local timeoutAt = GetGameTimer() + 5000
    while not HasModelLoaded(crayFishModel) and GetGameTimer() < timeoutAt do
        Wait(0)
    end
	
	if not HasModelLoaded(crayFishModel) then
        return
    end
	
	if state.exhausted
		or state.pending
		or state.crayfish then
		SetModelAsNoLongerNeeded(crayFishModel)
		return
	end

    local crayfish = CreateObject(crayFishModel, hole.coords.x, hole.coords.y, groundZ + Config.Crayfish.crayfishZOffset, false, false, false)
	
	PrintDebug("[crayfish] Model crayfish = " .. tostring(crayfish))
	
	SetModelAsNoLongerNeeded(crayFishModel)

    if not crayfish or crayfish == 0 then return end

    SetEntityAsMissionEntity(crayfish, true, true)
    --PlaceObjectOnGroundProperly(crayfish)
	
	RegisterEntityForEagleEye(crayfish, Config.EagleEyeTint or {r = 255.0, g = 255.0, b = 0.0,})

    state.crayfish = crayfish
	PrintDebug("[crayfish] crayfish = " .. tostring(crayfish))
end

local function CreateCrayfishScenario(holeIndex)
	local state = GetHoleState(holeIndex)
	if state.exhausted then return false end
	 
    local scenario = state.scenario

    if scenario and Citizen.InvokeNative(0x841475AC96E794D1, scenario) then --DOES_SCENARIO_POINT_EXIST
        return true
    end
	
	state.scenario = nil

    local hole = Config.Crayfish.Holes[holeIndex]
    if not hole then return false end
	
	--CREATE_SCENARIO_POINT_HASH
    local scenario = Citizen.InvokeNative(0x94B745CE41DB58A1, Config.Crayfish.scenarioHash, hole.coords.x, hole.coords.y + Config.Crayfish.scenarioYOffset, hole.coords.z, 0.0, 0, 0, false, Citizen.ResultAsInteger())

	PrintDebug(('[crayfish] hole=%d result=%s'):format(holeIndex, tostring(scenario)))
	
	if not scenario or scenario == 0 then
        return false
    end

    state.scenario = scenario
    return true
end

function DeleteCrayfishAtHole(holeIndex)
    local state = activeHoles[holeIndex]
	
	if not state then return end
	
	local crayfish = state.crayfish

    if crayfish then
        if DoesEntityExist(crayfish) then
            UnregisterEntityForEagleEye(crayfish)
            DeleteEntity(crayfish)
        end

        state.crayfish = nil
    end
end

function DeleteCrayfishScenario(holeIndex)
    local state = activeHoles[holeIndex]
    if not state then return end

    local scenario = state.scenario

    if scenario and Citizen.InvokeNative(0x841475AC96E794D1, scenario) then
        Citizen.InvokeNative(0x81948DFE4F5A0283, scenario)
		PrintDebug("[crayfish] scenario del = " .. tostring(scenario))
    end
	
	state.scenario = nil
end

function FindHoleByCrayfishEntity(entity)
    if not entity or entity == 0 then
        return nil
    end

    for holeIndex, state in pairs(activeHoles) do
        if state.crayfish == entity then
            return holeIndex
        end
    end

    return nil
end


local function EnsureCrayfishPin(holeIndex)
    local hole = Config.Crayfish.Holes[holeIndex]
    if not hole then return false end

	local state = GetHoleState(holeIndex)
    local pin = state.pin

    if not pin or pin == 0 then
        pin = Citizen.InvokeNative(
            0x6F3068258A499E52, -- PIN_CLOSEST_MAP_ENTITY
            hole.decal,
            hole.coords.x,
            hole.coords.y,
            hole.coords.z,
            11.0,
            Citizen.ResultAsInteger()
        )

        if pin and pin ~= 0 then
            state.pin = pin
        end

        -- Как в оригинальном if ... else if:
        -- после запроса ждём следующего прохода.
        return false
    end

    return Citizen.InvokeNative(
        0x1FF441D7954F8709, -- IS_MAP_ENTITY_PINNED
        pin
    )
end

-- Полная очистка (раки, сценарии, пины). Вызывается из client.lua при onResourceStop.
function CrayfishCleanupAll()
	if Config.EnableCrayFish then
		for holeIndex, state in pairs(activeHoles) do
			DeleteCrayfishAtHole(holeIndex)
			DeleteCrayfishScenario(holeIndex)
	
			local pin = state.pin
	
			if pin and pin ~= 0 then
				if Citizen.InvokeNative(0x1FF441D7954F8709, pin) then
					Citizen.InvokeNative(
						0xD2B9C78537ED5759,
						pin
					)
				end
			end
	
			state.pin = nil
		end
	end
end



CreateThread(function()
    while true do
		local enabled = playerSpawn and Config.EnableCrayFish
	
        if enabled then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local radius = Config.Crayfish.searchRadius or 100.0

            for holeIndex, hole in ipairs(Config.Crayfish.Holes) do
                local distance = #(playerCoords - hole.coords)
				local state = GetHoleState(holeIndex)
				
				
                if state.exhausted then
					DeleteCrayfishAtHole(holeIndex)
					DeleteCrayfishScenario(holeIndex)
				
				elseif state.pending then
					-- Ждём завершения взаимодействия.
					-- Не создаём нового рака и не удаляем текущий scenario.
				
				elseif distance <= radius then
					local scenarioReady = CreateCrayfishScenario(holeIndex)
					
					if scenarioReady then
						CreateCrayfishAtHole(holeIndex)
						EnsureCrayfishPin(holeIndex)
					end
				else
					DeleteCrayfishAtHole(holeIndex)
					DeleteCrayfishScenario(holeIndex)
				end
            end
        else
            for holeIndex in ipairs(Config.Crayfish.Holes) do
                DeleteCrayfishAtHole(holeIndex)
                DeleteCrayfishScenario(holeIndex)
            end
        end

        Wait(2000)
    end
end)

-- Сброс состояния нор (без удаления пинов). Вызывается из client.lua
-- при RSGCore:Client:OnPlayerUnload.
function CrayfishReset()
    for holeIndex in pairs(activeHoles) do
        DeleteCrayfishAtHole(holeIndex)
        DeleteCrayfishScenario(holeIndex)
    end

    for _, state in pairs(activeHoles) do
        state.collected = 0
        state.pending = false
        state.exhausted = false
    end
end
