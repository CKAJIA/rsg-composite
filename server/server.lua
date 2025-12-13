local RSGCore = exports['rsg-core']:GetCoreObject()

local ServerComposite = {}
local CompositeLoaded = false

local function EnsureCompositesTable()
    local sql = [[
        CREATE TABLE IF NOT EXISTS player_composites (
            id INT NOT NULL AUTO_INCREMENT,
            citizenid VARCHAR(50) NOT NULL,
            pointkey VARCHAR(32) NOT NULL,
            scenario BIGINT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY uniq_citizen_point (citizenid, pointkey),
            KEY idx_citizenid (citizenid)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]
    MySQL.Async.execute(sql, {})
end

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    EnsureCompositesTable()
end)

-- Вставьте вместо него этот хелпер:
local function GetCompositeData(herbID)
    return Config.Composites[herbID]
end

function GetDictTexture(herbID)
    if herbID >= 1 and herbID <= 43 or herbID == 61 or herbID >= 54 and herbID <= 56 then
        return "inventory_items"
    elseif herbID >= 44 and herbID <= 53 or herbID >= 57 and herbID <= 60 then
        return "inventory_items_mp"
    else
        return ""
    end
end

function GetColorTexture(herbID, pick)
	local data = GetCompositeData(herbID)
	if not data then return "COLOR_GREYMID" end
	-- Берем isUnique из новой структуры spawn
    local isUnique = data.spawn and data.spawn.isUnique
	
	if pick then
		if isUnique then
			return "COLOR_RPG_SPECIAL_1"
		else
			return "COLOR_PURE_WHITE"
		end
	else
		if isUnique then
			return "COLOR_YELLOWDARK"
		else
			return "COLOR_GREYMID"
		end
	end
end


RegisterNetEvent("rsg-composite:server:Gathered")
AddEventHandler("rsg-composite:server:Gathered", function(HerbID, amount)
        local _source = source
		local Player = RSGCore.Functions.GetPlayer(_source)
		local data = GetCompositeData(HerbID)
		
        if data and data.item and data.item ~= "" then
			local item = data.item
			Player.Functions.AddItem(item, amount) --amount количество
			--TriggerClientEvent("rsg-inventory:client:ItemBox", _source, RSGCore.Shared.Items[item], "add")
			--TriggerClientEvent('ox_lib:notify', _source, {title = RSGCore.Shared.Items[item].label, description = 'добавлен(а) в инвентарь!', type = 'success', duration = 3000 })
			local noticeString = ""
			if amount > 1 then noticeString = amount .. "x " end
			--TriggerClientEvent('rNotify:ShowAdvancedRightNotification', source, RSGCore.Shared.Items[item].label, "pm_collectors_bag_mp" , "provision_wldflwr_wild_rhubarb" , "COLOR_PURE_WHITE", 4000)
			TriggerClientEvent('rsg-composite:client:UIFeedPostSampleToastRight', source, noticeString .. RSGCore.Shared.Items[item].label, GetDictTexture(HerbID) , item, GetColorTexture(HerbID, true), 2000, 0, 1)
			if data.rewards and #data.rewards > 0 then
				for _, reward in pairs(data.rewards) do
					local chance = math.random(1, 100)
					if chance <= reward.chance then
						local rAmount = math.random(reward.amountMin, reward.amountMax)
						if Player.Functions.AddItem(reward.item, rAmount) then
							TriggerClientEvent("rsg-inventory:client:ItemBox", _source, RSGCore.Shared.Items[reward.item], "add")
						end
					end
				end
			end
		else
			TriggerClientEvent('ox_lib:notify', _source, {title = 'No items for', description = HerbID, type = 'error', duration = 5000 })
        end
    end
)
--[[
RegisterNetEvent("rsg-composite:server:AdditionRewards")
AddEventHandler("rsg-composite:server:AdditionRewards", function(item, amount)
        local _source = source
		local Player = RSGCore.Functions.GetPlayer(_source)
        if item and amount then
			Player.Functions.AddItem(item, amount) --amount количество
			TriggerClientEvent("rsg-inventory:client:ItemBox", _source, RSGCore.Shared.Items[item], "add")
			--TriggerClientEvent('ox_lib:notify', _source, {title = RSGCore.Shared.Items[item].label, description = 'добавлен(а) в инвентарь!', type = 'success', duration = 3000 })
		else
			TriggerClientEvent('ox_lib:notify', _source, {title = 'ERROR', description = 'No items or amount in addReward', type = 'error', duration = 5000 })
		end
    end
)
--]]
RegisterNetEvent("rsg-composite:server:Eating")
AddEventHandler("rsg-composite:server:Eating", function(HerbID)
        local _source = source
		local data = GetCompositeData(HerbID)
        
		if data and data.item and data.item ~= "" then
			TriggerClientEvent('rsg-composite:client:UIFeedPostSampleToastRight', source, RSGCore.Shared.Items[data.item].label, GetDictTexture(HerbID) , data.item, GetColorTexture(HerbID, false), 2000, 0, 0)
		else
			TriggerClientEvent('ox_lib:notify', _source, {title = 'No items for', description = HerbID, type = 'error', duration = 5000 })
        end
    end
)

RegisterNetEvent("rsg-composite:server:AddToServerPoint")
AddEventHandler("rsg-composite:server:AddToServerPoint", function(key, CompositePoint)
		local playerId = source -- Получаем ID игрока, отправившего запрос
		if ServerComposite[key] == nil then
			ServerComposite[key] = CompositePoint
			--print("HerbCoords[1] = " .. CompositePoint.HerbID)
		end
		--local compositeTable = ServerComposite[key]
		TriggerClientEvent("rsg-composite:client:GetServerComposite", playerId, key, ServerComposite[key]) -- Отправляем таблицу клиенту
    end
)
--[[
RegisterServerEvent("rsg-composite:server:RequestCompositeFromClient")
AddEventHandler("rsg-composite:server:RequestCompositeFromClient", function(key)
    local playerId = source -- Получаем ID игрока, отправившего запрос
	if ServerComposite[key] then
		local compositeTable = ServerComposite[key] -- Получаем нужную таблицу
		--print("HerbID = " .. compositeTable.HerbID)
		TriggerClientEvent("rsg-composite:client:GetServerComposite", playerId, key, compositeTable) -- Отправляем таблицу клиенту
	end
end)
]]--

RegisterServerEvent("rsg-composite:server:SendMessage")
AddEventHandler("rsg-composite:server:SendMessage", function(ctitle, cmessage)
	local _source = source
    TriggerClientEvent('ox_lib:notify', _source, {title = ctitle, description = cmessage, type = 'inform', duration = 3000 })
end)







RegisterServerEvent('rsg-composite:server:saveGatheredPoint')
AddEventHandler('rsg-composite:server:saveGatheredPoint', function(pointkey, scenario)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local citizenid = Player.PlayerData.citizenid	

	MySQL.Async.execute('INSERT INTO player_composites (citizenid, pointkey, scenario) VALUES (@citizenid, @pointkey, @scenario) ON DUPLICATE KEY UPDATE scenario = VALUES(scenario)', {
		['@citizenid'] = citizenid,
		['@pointkey'] = pointkey,
		['@scenario'] = scenario
	})
end)

-- get plant
RSGCore.Functions.CreateCallback('rsg-composite:server:getPlayerComposites', function(source, cb)
	local playerId = source
	local Player = RSGCore.Functions.GetPlayer(playerId)
	local citizenid = Player.PlayerData.citizenid
	--local result = MySQL.query.await('SELECT * FROM player_composites WHERE citizenid = @citizenid', {['@citizenid'] = citizenid})
	local result = MySQL.query.await('SELECT pointkey, scenario FROM player_composites WHERE citizenid = @citizenid', { 
		['@citizenid'] = citizenid 
	})

	local FullLootedScenarioPoint = {}
	if result[1] then
		for i = 1, #result do
			local key = result[i].pointkey
			local scenario = result[i].scenario

			if key and scenario then
				FullLootedScenarioPoint[key] = scenario
			end
		end
	end
	if Config.Debug then
		print("Composite Data for " .. citizenid .. " uploaded successfully")
	end
    cb(FullLootedScenarioPoint)
end)


--[[

RegisterNetEvent("rsg-multicharacter:client:chooseChar")
AddEventHandler(
    "RSGCore:Client:OnPlayerLoaded",
    function(source, user_id, isFirstSpawn)
        if isFirstSpawn then
            TriggerClientEvent("rsg-composite:SetPopSuppressed", source, popSuppressed)
        end
    end
)
--]]

CreateUseableItem = function()
    for k, v in pairs(Config.Composites) do
		-- Проверка: есть данные потребления, нет запрета на использование (use=false), есть имя предмета
		if v.eat and v.eat.use ~= false and v.item and v.item ~= "" then --не создаем для моркови. Она создается в конюшне.
			RSGCore.Functions.CreateUseableItem(v.item, function(source, item)
				local Player = RSGCore.Functions.GetPlayer(source)
				if Player.Functions.RemoveItem(v.item, 1, item.slot) then
					TriggerClientEvent("rsg-composite:client:Eating", source, k, v.item) -- передача ключа k - HerbID
				end
			end)
		end
    end
end


CreateUseableItem()




-- Функция для очистки таблицы
local function clearTableComposite()
    MySQL.Async.execute('TRUNCATE TABLE player_composites')
end

-- Планирование очистки таблицы в 6:00 утра каждый день
local function scheduleClearing()
    -- Получаем текущее время
    local currentTime = os.date("*t")
    
    -- Задаем время очистки (6:00 утра)
    local targetTime = os.time({year = currentTime.year, month = currentTime.month, day = currentTime.day, hour = 6, min = 0, sec = 0})

    -- Если текущее время больше или равно 6:00 утра, добавляем 24 часа к времени очистки
    if os.time() >= targetTime then
        targetTime = targetTime + 24 * 3600
    end

    -- Вычисляем разницу времени между текущим временем и временем очистки
    local timeToClear = targetTime - os.time()

    -- Устанавливаем таймер для запуска очистки таблицы через указанное время
    SetTimeout(timeToClear * 1000, function()
        clearTableComposite()
        
        -- Запускаем планирование очистки таблицы снова для следующего дня
        scheduleClearing()
    end)
end

-- Запускаем планирование
scheduleClearing()

AddEventHandler('onResourceStop', function(resource)
    if GetCurrentResourceName() ~= resource then return end
    clearTableComposite()
end)

