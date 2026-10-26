-- Древесные гнёзда выбираются по типам scenario point WB_EGG_NEST_*.
-- Модели и виды взяты из оригинальных net_bird_egg_* скриптов.
Config.TreeEggs = {
    scanRadius = 100.0,
    scanIntervalMs = 2000,
    despawnDistance = 175.0,
    maxScenarioPoints = 600,

    -- Оригинал проверяет текущий ammo type, а не название оружия.
    --smallGameAmmoType = "ammo_arrow_small_game",
	smallGameAmmoTypes = { "ammo_arrow_small_game", "AMMO_22" },
    -- Одно яйцо создаётся внутри гнезда. Смещение локальное относительно модели гнезда;
    -- при необходимости подстройте его для своих моделей/сборки игры.
    eggOffset = vector3(0.0, 0.0, 0.12),
    eggRotation = vector3(0.0, 0.0, 0.0),

    outcomes = {
        smallGameHit = "drop_egg_with_physics",
        otherProjectileHit = "break_egg",
    },

    -- Scenario hash -> species key. Все значения JOAAT сверены с локальным
    -- ScenarioNames и исходниками/списком scenario point.
    scenarioTypes = {
        [1416906705] = "eagle",       -- WB_EGG_NEST_EAGLE
        [-2065167667] = "condor",     -- WB_EGG_NEST_CONDOR
        [227465803] = "egret",        -- WB_EGG_NEST_EGRET
        [631990874] = "hawk",         -- WB_EGG_NEST_HAWK
        [-422823195] = "heron",       -- WB_EGG_NEST_HERON
        [-871818204] = "spoonbill",   -- WB_EGG_NEST_SPOONBILL
    },

    species = {
        eagle = {
            collectible = "COLLECTIBLE_EGG_EAGLE",
            herbID = 100,
            nestModel = "mp005_s_bdeg_eaglenest01x",
            eggModel = "mp005_s_bdeg_eagle_egg01x",
            eggCount = 4,
        },
        condor = {
            collectible = "COLLECTIBLE_EGG_CONDOR",
            herbID = 101,
            nestModel = "mp005_s_bdeg_condornest01x",
            eggModel = "mp005_s_bdeg_condor_egg01x",
            eggCount = 7,
        },
        egret = {
            collectible = "COLLECTIBLE_EGG_EGRET",
            herbID = 102,
            nestModel = "mp005_s_bdeg_egretnest01x",
            eggModel = "mp005_s_bdeg_egret_egg01x",
            eggCount = 5,
        },
        hawk = {
            collectible = "COLLECTIBLE_EGG_HAWK",
            herbID = 103,
            nestModel = 990159072,
            eggModel = "mp005_s_bdeg_hawk_egg01x",
            eggCount = 6,
        },
        heron = {
            collectible = "COLLECTIBLE_EGG_HERON",
            herbID = 104,
            nestModel = "mp005_s_bdeg_heronnest01x",
            eggModel = "mp005_s_bdeg_heron_egg01x",
            eggCount = 8,
        },
        spoonbill = {
            collectible = "COLLECTIBLE_EGG_SPOONBILL",
            herbID = 105,
            nestModel = "mp005_s_bdeg_spoonbillnest01x",
            eggModel = "mp005_s_bdeg_spoonbill_egg01x",
            eggCount = 9,
        },
    },
}
