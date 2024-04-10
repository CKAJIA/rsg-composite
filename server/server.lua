local RSGCore = exports['rsg-core']:GetCoreObject()

local ServerComposite = {}
local CompositeLoaded = false

local toItem = {
    [45] = "provision_wldflwr_agarita",
    [2] = "consumable_herb_alaskan_ginseng",
    [3] = "consumable_herb_american_ginseng",
    [4] = "consumable_herb_bay_bolete",
    [47] = "provision_wldflwr_bitterweed",
    [5] = "consumable_herb_black_berry",
    [6] = "consumable_herb_black_currant",
    [48] = "provision_wldflwr_blood_flower",
    [7] = "consumable_herb_burdock_root",
    [49] = "provision_wldflwr_cardinal_flower",
    [8] = "consumable_herb_chanterelles",
    [50] = "provision_wldflwr_chocolate_daisy",
    [11] = "consumable_herb_common_bulrush",
    [51] = "provision_wldflwr_creek_plum",
    [12] = "consumable_herb_creeping_thyme",
    [13] = "consumable_herb_desert_sage",
    [57] = "provision_duck_egg",
    [15] = "consumable_herb_english_mace",
    [16] = "consumable_herb_evergreen_huckleberry",
    [18] = "consumable_herb_golden_currant",
    [58] = "provision_goose_egg",
	[44] = "consumable_herb_harrietum",
    [19] = "consumable_herb_hummingbird_sage",
    [20] = "consumable_herb_indian_tobacco",
    [59] = "provision_loon_egg",
    [23] = "consumable_herb_milkweed",
    [26] = "consumable_herb_oleander_sage",
    [1] = "provision_ro_flower_acunas_star",
    [9] = "provision_ro_flower_cigar",
    [10] = "provision_ro_flower_clamshell",
    [14] = "provision_ro_flower_dragons",
    [17] = "provision_ro_flower_ghost",
    [21] = "provision_ro_flower_lady_of_night",
    [22] = "provision_ro_flower_lady_slipper",
    [24] = "provision_ro_flower_moccasin",
    [25] = "provision_ro_flower_night_scented",
    [30] = "provision_ro_flower_queens",
    [32] = "provision_ro_flower_rat_tail",
    [35] = "provision_ro_flower_sparrows",
    [36] = "provision_ro_flower_spider",
    [37] = "consumable_herb_vanilla_flower",
    [27] = "consumable_herb_oregano",
    [28] = "consumable_herb_parasol_mushroom",
    [29] = "consumable_herb_prairie_poppy", -- 
    [31] = "consumable_herb_rams_head", -- opio
    [33] = "consumable_herb_red_raspberry",
    [34] = "consumable_herb_red_sage",
    [46] = "provision_wldflwr_texas_blue_bonnet",
    [38] = "consumable_herb_violet_snowdrop",
    [60] = "provision_vulture_egg",
    [39] = "consumable_herb_wild_carrots",
    [40] = "consumable_herb_wild_feverfew",
    [41] = "consumable_herb_wild_mint",
    [52] = "provision_wldflwr_wild_rhubarb",
    [42] = "consumable_herb_wintergreen_berry",
    [53] = "provision_wldflwr_wisteria",
    [43] = "consumable_herb_yarrow",
	
	[54] = "provision_disco_gator_egg",
	[55] = "provision_disco_gator_egg",
	[56] = "provision_disco_gator_egg",
	
	[61] = "consumable_herb_saltbush"	
}

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
	if pick then
		if Config.compositeOptionsSpawn[herbID].isUnique then
			return "COLOR_RPG_SPECIAL_1"
		else
			return "COLOR_PURE_WHITE"
		end
	else
		if Config.compositeOptionsSpawn[herbID].isUnique then
			return "COLOR_YELLOWDARK"
		else
			return "COLOR_GREYMID"
		end
	end
end


RegisterNetEvent("RSG:COMPOSITE:Gathered")
AddEventHandler("RSG:COMPOSITE:Gathered", function(HerbID, amount)
        local _source = source
		local Player = RSGCore.Functions.GetPlayer(_source)
		local item = toItem[HerbID]
        if item ~= nil then			
			Player.Functions.AddItem(item, amount) --amount количество
			--TriggerClientEvent("inventory:client:ItemBox", _source, RSGCore.Shared.Items[item], "add")
			--TriggerClientEvent('ox_lib:notify', _source, {title = RSGCore.Shared.Items[item].label, description = 'добавлен(а) в инвентарь!', type = 'success', duration = 3000 })
			
			local noticeString = ""
			if amount > 1 then
				noticeString = amount .. "x "
			end
			--TriggerClientEvent('rNotify:ShowAdvancedRightNotification', source, RSGCore.Shared.Items[item].label, "pm_collectors_bag_mp" , "provision_wldflwr_wild_rhubarb" , "COLOR_PURE_WHITE", 4000)
			TriggerClientEvent('RSG:COMPOSITE:UIFeedPostSampleToastRight', source, noticeString .. RSGCore.Shared.Items[item].label, GetDictTexture(HerbID) , item, GetColorTexture(HerbID, true), 2000, 0, 1)
			--RSGCore.ShowSuccess(GetCurrentResourceName(), RSGCore.Shared.Items[item].label .. " добавлен(а) в инвентарь!")
		else
			TriggerClientEvent('ox_lib:notify', _source, {title = 'No items for', description = HerbID, type = 'error', duration = 5000 })
        end
    end
)

RegisterNetEvent("RSG:COMPOSITE:AdditionRewards")
AddEventHandler("RSG:COMPOSITE:AdditionRewards", function(item, amount)
        local _source = source
		local Player = RSGCore.Functions.GetPlayer(_source)
        if item and amount then
			Player.Functions.AddItem(item, amount) --amount количество
			TriggerClientEvent("inventory:client:ItemBox", _source, RSGCore.Shared.Items[item], "add")
			--TriggerClientEvent('ox_lib:notify', _source, {title = RSGCore.Shared.Items[item].label, description = 'добавлен(а) в инвентарь!', type = 'success', duration = 3000 })
		else
			TriggerClientEvent('ox_lib:notify', _source, {title = 'ERROR', description = 'No items or amount in addReward', type = 'error', duration = 5000 })
		end
    end
)

RegisterNetEvent("RSG:COMPOSITE:Eating")
AddEventHandler("RSG:COMPOSITE:Eating", function(HerbID)
        local _source = source
		local item = toItem[HerbID]
        if item ~= nil then
			TriggerClientEvent('RSG:COMPOSITE:UIFeedPostSampleToastRight', source, RSGCore.Shared.Items[item].label, GetDictTexture(HerbID) , item, GetColorTexture(HerbID, false), 2000, 0, 0)
			--TriggerClientEvent('ox_lib:notify', _source, {title = RSGCore.Shared.Items[item].label, description = 'съели!', type = 'inform', duration = 3000 })
		else
			TriggerClientEvent('ox_lib:notify', _source, {title = 'No items for', description = HerbID, type = 'error', duration = 5000 })
        end
    end
)

RegisterNetEvent("RSG:COMPOSITE:AddToServerPoint")
AddEventHandler("RSG:COMPOSITE:AddToServerPoint", function(key, CompositePoint)
		local playerId = source -- Получаем ID игрока, отправившего запрос
		if ServerComposite[key] == nil then
			ServerComposite[key] = CompositePoint
			--print("HerbCoords[1] = " .. CompositePoint.HerbID)
		end
		--local compositeTable = ServerComposite[key]
		TriggerClientEvent("RSG:COMPOSITE:GetServerComposite", playerId, key, ServerComposite[key]) -- Отправляем таблицу клиенту
    end
)
--[[
RegisterServerEvent("RSG:COMPOSITE:RequestCompositeFromClient")
AddEventHandler("RSG:COMPOSITE:RequestCompositeFromClient", function(key)
    local playerId = source -- Получаем ID игрока, отправившего запрос
	if ServerComposite[key] then
		local compositeTable = ServerComposite[key] -- Получаем нужную таблицу
		--print("HerbID = " .. compositeTable.HerbID)
		TriggerClientEvent("RSG:COMPOSITE:GetServerComposite", playerId, key, compositeTable) -- Отправляем таблицу клиенту
	end
end)
]]--

RegisterServerEvent("RSG:COMPOSITE:SendMessage")
AddEventHandler("RSG:COMPOSITE:SendMessage", function(ctitle, cmessage)
	local _source = source
    TriggerClientEvent('ox_lib:notify', _source, {title = ctitle, description = cmessage, type = 'inform', duration = 3000 })
end)







RegisterServerEvent('RSG:COMPOSITE:saveGatheredPoint')
AddEventHandler('RSG:COMPOSITE:saveGatheredPoint', function(pointcoord, scenario)
    local _source = source
    local Player = RSGCore.Functions.GetPlayer(_source)
    local citizenid = Player.PlayerData.citizenid	
	local datas = json.encode(pointcoord)

    MySQL.Async.execute('INSERT INTO player_composites (citizenid, pointcoords, scenario) VALUES (@citizenid, @pointcoords, @scenario)',
    {
        ['@citizenid'] = citizenid,
		['@pointcoords'] = datas,
        ['@scenario'] = scenario
    })
end)

-- get plant
RegisterServerEvent('RSG:COMPOSITE:loadPlayerComposite')
AddEventHandler('RSG:COMPOSITE:loadPlayerComposite', function()
	local playerId = source -- Получаем ID игрока, отправившего запрос
	local Player = RSGCore.Functions.GetPlayer(playerId)
	local citizenid = Player.PlayerData.citizenid
	local result = MySQL.query.await('SELECT * FROM player_composites WHERE citizenid = @citizenid', {['@citizenid'] = citizenid})

	local FullLootedScenarioPoint = {}
	if result[1] then		
		for i = 1, #result do
			local bdpointcoords = json.decode(result[i].pointcoords)
			local pointcoords = vector2(bdpointcoords.x, bdpointcoords.y)
			local scenario = result[i].scenario
			if pointcoords and scenario then			
				FullLootedScenarioPoint[pointcoords] = scenario
			else
				print("Warning: Invalid pointcoords or scenario in database row")
			end
		end
	end
	TriggerClientEvent('RSG:COMPOSITE:playerCompositeLoaded', playerId, FullLootedScenarioPoint)
	print("Composite Data for " .. citizenid .. " uploaded successfully")
end)


--[[

RegisterNetEvent("rsg-multicharacter:client:chooseChar")
AddEventHandler(
    "RSGCore:Client:OnPlayerLoaded",
    function(source, user_id, isFirstSpawn)
        if isFirstSpawn then
            TriggerClientEvent("RSG:COMPOSITE:SetPopSuppressed", source, popSuppressed)
        end
    end
)
--]]

CreateUseableItem = function()
    for k, v in pairs(Config.compositeOptionsEat) do
        RSGCore.Functions.CreateUseableItem(v.item, function(source, item)
            local Player = RSGCore.Functions.GetPlayer(source)
            if Player.Functions.RemoveItem(v.item, 1, item.slot) then
                TriggerClientEvent("RSG:COMPOSITE:Eating", source, k, v.item) -- передача ключа k - HerbID
            end
        end)
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

