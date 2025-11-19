local RSGCore = exports['rsg-core']:GetCoreObject()

-----------------------------------------------------------------------
-- version checker
-----------------------------------------------------------------------
local function versionCheckPrint(_type, log)
    local color = '^7' -- default

    if _type == 'success' then
        color = '^2'
    elseif _type == 'error' then
        color = '^1'
    elseif _type == 'warn' then
        color = '^3' -- "оранжевый" (жёлтый)
    end

    print(('^5['..GetCurrentResourceName()..']%s %s^7'):format(color, log))
end

local function CheckVersion()
    PerformHttpRequest('https://raw.githubusercontent.com/RexShack/rsg-versioncheckers/main/'..GetCurrentResourceName()..'/version.txt', function(err, text, headers)
        local currentVersion = GetResourceMetadata(GetCurrentResourceName(), 'version')

        if not text then
            versionCheckPrint('warn', 'This is custom script from BadStealth(CKAJIA).')
            return
        end

        if text == currentVersion then
            versionCheckPrint('success', ('You are running the latest version. Current Version: %s'):format(currentVersion))
        else
            versionCheckPrint('error', ('You are currently running an outdated version, please update to version %s'):format(text))
        end
    end)
end

--------------------------------------------------------------------------------------------------
-- start version check
--------------------------------------------------------------------------------------------------
CheckVersion()
